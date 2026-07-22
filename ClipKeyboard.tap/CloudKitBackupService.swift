//
//  CloudKitBackupService.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import CloudKit
import Combine

enum CloudKitError: Error {
    case notAuthenticated
    case backupFailed(Error)
    case restoreFailed(Error)
    case noBackupFound
    case encodingFailed
    case decodingFailed

    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                   comment: "iCloud not authenticated error message")
        case .backupFailed(let error):
            return getActionableMessage(for: error, operation: "backup")
        case .restoreFailed(let error):
            return getActionableMessage(for: error, operation: "restore")
        case .noBackupFound:
            return NSLocalizedString("백업 데이터가 없습니다. 먼저 백업을 생성해주세요.",
                                   comment: "No backup found error message")
        case .encodingFailed:
            return NSLocalizedString("데이터를 준비하는 중 문제가 발생했습니다. 앱을 재시작하고 다시 시도해주세요.",
                                   comment: "Data encoding failed error message")
        case .decodingFailed:
            return NSLocalizedString("백업 데이터를 읽을 수 없습니다. 최신 버전의 앱을 사용하고 있는지 확인해주세요.",
                                   comment: "Data decoding failed error message")
        }
    }

    // MARK: - Helper

    private func getActionableMessage(for error: Error, operation: String) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return NSLocalizedString("네트워크 연결을 확인하고 다시 시도해주세요.",
                                       comment: "Network error message")
            case .notAuthenticated:
                return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                       comment: "iCloud not authenticated error message")
            case .quotaExceeded:
                return NSLocalizedString("iCloud 저장 공간이 부족합니다. 설정 > [사용자 이름] > iCloud > 저장 공간 관리에서 확인해주세요.",
                                       comment: "iCloud quota exceeded error message")
            case .permissionFailure:
                return NSLocalizedString("iCloud Drive가 활성화되어 있는지 확인해주세요. 설정 > [사용자 이름] > iCloud > iCloud Drive를 켜주세요.",
                                       comment: "iCloud permission error message")
            case .serverResponseLost, .serviceUnavailable:
                return NSLocalizedString("iCloud 서버에 일시적인 문제가 있습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "iCloud server error message")
            case .zoneBusy, .requestRateLimited:
                return NSLocalizedString("요청이 너무 많습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "Rate limited error message")
            default:
                return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                                       comment: "Generic iCloud error message")
            }
        }
        return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                               comment: "Generic error message")
    }
}

// MARK: - CloudKit Database 추상화 (테스트 주입용)

/// CloudKit private DB 중 백업이 쓰는 연산만 추상화. 실제 CKDatabase가 그대로 채택하고,
/// 테스트는 인메모리 mock을 주입해 네트워크 없이 백업/복원 전 경로의 무결성을 검증한다.
/// (iOS CloudKitBackupService와 동일한 구조 — 양쪽 동기화 유지.)
protocol CloudKitBackupDatabase {
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    @discardableResult func save(_ record: CKRecord) async throws -> CKRecord
    @discardableResult func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID
}

extension CKDatabase: CloudKitBackupDatabase {}

class CloudKitBackupService: ObservableObject {
    static let shared = CloudKitBackupService()

    private let container: CKContainer?
    private let database: CloudKitBackupDatabase
    private let fetchAccountStatus: () async throws -> CKAccountStatus

    @Published var isAuthenticated: Bool = false
    @Published var lastBackupDate: Date?
    @Published var isBackingUp: Bool = false
    @Published var isRestoring: Bool = false
    @Published var autoBackupEnabled: Bool = false

    private var autoBackupTimer: Timer?
    private let autoBackupInterval: TimeInterval = 300 // 5분마다 자동 백업

    private init() {
        let container = CKContainer(identifier: "iCloud.com.Ysoup.TokenMemo")
        self.container = container
        self.database = container.privateCloudDatabase
        self.fetchAccountStatus = { try await container.accountStatus() }

        checkAccountStatus()
        loadLastBackupDate()
        loadAutoBackupSetting()

        // 데이터 변경 알림 리스너 등록
        setupDataChangeListener()
    }

    /// 테스트 전용: mock DB/계정 상태를 주입한다.
    /// 타이머·데이터 변경 리스너 등 부작용 없이 순수 백업/복원 로직만 동작.
    init(database: CloudKitBackupDatabase,
         accountStatus: @escaping () async throws -> CKAccountStatus) {
        self.container = nil
        self.database = database
        self.fetchAccountStatus = accountStatus
    }

    deinit {
        autoBackupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        guard let container else { return }
        container.accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                self?.isAuthenticated = (status == .available)
                print("📱 [CloudKit] Account Status: \(status.rawValue)")
            }
        }
    }

    private func loadLastBackupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: DefaultsKey.lastBackupDate) as? Date {
            self.lastBackupDate = timestamp
        }
    }

    private func saveLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: DefaultsKey.lastBackupDate)
        self.lastBackupDate = date
    }

    private func loadAutoBackupSetting() {
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.autoBackupEnabled)
        if autoBackupEnabled {
            startAutoBackupTimer()
        }
    }

    // MARK: - Auto Backup

    func enableAutoBackup() {
        print("🔄 [CloudKit] 자동 백업 활성화")
        UserDefaults.standard.set(true, forKey: DefaultsKey.autoBackupEnabled)
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = true
        }
        startAutoBackupTimer()
    }

    func disableAutoBackup() {
        print("⏸️ [CloudKit] 자동 백업 비활성화")
        UserDefaults.standard.set(false, forKey: DefaultsKey.autoBackupEnabled)
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = false
        }
        stopAutoBackupTimer()
    }

    private func startAutoBackupTimer() {
        stopAutoBackupTimer() // 기존 타이머 제거

        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: autoBackupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isAuthenticated && !self.isBackingUp else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData()
                    print("✅ [CloudKit] 자동 백업 성공")
                } catch {
                    print("⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        print("⏰ [CloudKit] 자동 백업 타이머 시작 (간격: \(Int(autoBackupInterval))초)")
    }

    private func stopAutoBackupTimer() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
        print("⏹️ [CloudKit] 자동 백업 타이머 중지")
    }

    private func setupDataChangeListener() {
        // MemoStore에서 데이터 변경 알림을 받으면 자동 백업 트리거
        NotificationCenter.default.addObserver(
            forName: Notification.Name.memoDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard self.autoBackupEnabled && self.isAuthenticated && !self.isBackingUp else { return }

            print("📢 [CloudKit] 데이터 변경 감지 - 자동 백업 예약")

            // 변경사항이 연속으로 발생할 수 있으므로 디바운스 (5초 후 실행)
            self.scheduleAutoBackup()
        }
    }

    private var autoBackupWorkItem: DispatchWorkItem?

    private func scheduleAutoBackup() {
        // 기존 예약된 백업 취소
        autoBackupWorkItem?.cancel()

        // 새로운 백업 예약 (5초 후)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData()
                    print("✅ [CloudKit] 변경사항 자동 백업 완료")
                } catch {
                    print("⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        autoBackupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    // MARK: - Helper Methods

    /// Data를 CKAsset으로 변환 (대용량 데이터 저장용)
    private func createAsset(from data: Data, filename: String) throws -> CKAsset {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return CKAsset(fileURL: fileURL)
    }

    /// CKAsset에서 Data 읽기
    private func readAsset(_ asset: CKAsset) throws -> Data {
        guard let fileURL = asset.fileURL else {
            throw CloudKitError.decodingFailed
        }

        return try Data(contentsOf: fileURL)
    }

    // MARK: - Image Backup (App Group Images/ ↔ CKAsset)

    /// App Group 내 이미지 폴더.
    private var imagesBackupDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 메모들이 참조하는 PNG들을 백업 레코드에 CKAsset 배열로 첨부(존재하는 파일만).
    /// 이미지가 없으면 필드를 비워 이전 백업의 잔존 이미지를 정리한다.
    private func attachImages(to record: inout CKRecord, memos: [Memo]) {
        var names = Set<String>()
        for memo in memos {
            names.formUnion(memo.imageFileNames)
            if let single = memo.imageFileName, !single.isEmpty { names.insert(single) }
        }
        guard let dir = imagesBackupDirectory else { return }
        var assets: [CKAsset] = []
        var attachedNames: [String] = []
        for name in names.sorted() {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                assets.append(CKAsset(fileURL: url))
                attachedNames.append(name)
            }
        }
        if assets.isEmpty {
            record["imageAssets"] = nil
            record["imageNames"] = nil
        } else {
            record["imageAssets"] = assets as CKRecordValue
            record["imageNames"] = attachedNames as CKRecordValue
        }
        print("🖼️ [CloudKit] 백업 이미지: \(attachedNames.count)개")
    }

    /// 백업 레코드의 이미지 CKAsset들을 App Group Images/에 복원(덮어쓰기).
    private func restoreImages(from record: CKRecord) {
        guard let assets = record["imageAssets"] as? [CKAsset],
              let names = record["imageNames"] as? [String],
              let dir = imagesBackupDirectory else {
            print("ℹ️ [CloudKit] 복원할 이미지 없음")
            return
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var restored = 0
        for (asset, name) in zip(assets, names) {
            guard let src = asset.fileURL else { continue }
            let dest = dir.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)   // 덮어쓰기
            do { try FileManager.default.copyItem(at: src, to: dest); restored += 1 }
            catch { print("⚠️ [CloudKit] 이미지 복원 실패 \(name): \(error)") }
        }
        print("🖼️ [CloudKit] 이미지 \(restored)개 복원 완료")
    }

    // MARK: - Backup

    /// 호출 시점에 계정 상태를 새로 확인. init의 async 콜백이 아직 돌아오지
    /// 않은 상태에서 첫 버튼 클릭으로 .notAuthenticated 오탐이 나던 race를 제거.
    private func ensureAuthenticated() async throws {
        let status = try await fetchAccountStatus()
        await MainActor.run { self.isAuthenticated = (status == .available) }
        guard status == .available else {
            print("⚠️ [CloudKit] accountStatus = \(status.rawValue) (not available)")
            throw CloudKitError.notAuthenticated
        }
    }

    @discardableResult
    func backupData() async throws -> Int {
        print("☁️ [CloudKit] 백업 시작...")

        try await ensureAuthenticated()

        await MainActor.run { isBackingUp = true }
        defer { Task { @MainActor [weak self] in self?.isBackingUp = false } }

        do {
            let (memos, smartClipboard, combos) = try loadDataForBackup()
            let (memosData, smartClipboardData, combosData) = try encodeDataForBackup(
                memos: memos, smartClipboard: smartClipboard, combos: combos
            )
            var record = try await fetchOrCreateRecord()
            try configureRecord(&record, memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData)
            attachImages(to: &record, memos: memos)   // 첨부 이미지(PNG)도 함께 백업

            _ = try await saveRecordWithRetry(record, maxRetries: 3)

            let backupDate = Date()
            await MainActor.run { saveLastBackupDate(backupDate) }
            print("✅ [CloudKit] 백업 완료: \(backupDate)")
            return memos.count

        } catch let error as CKError {
            print("❌ [CloudKit] 백업 실패: \(error)")
            print("   코드: \(error.code.rawValue)")
            print("   설명: \(error.localizedDescription)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("   Underlying Error: \(underlyingError)")
            }
            throw CloudKitError.backupFailed(error)
        } catch {
            print("❌ [CloudKit] 백업 실패 (일반 에러): \(error)")
            throw CloudKitError.backupFailed(error)
        }
    }

    private func loadDataForBackup() throws -> (memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]) {
        let memos = try MemoStore.shared.load(type: .memo)
        let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
        let combos = try MemoStore.shared.loadCombos()
        print("📦 [CloudKit] 백업할 메모: \(memos.count)개")
        print("📦 [CloudKit] 백업할 스마트 클립보드: \(smartClipboard.count)개")
        print("📦 [CloudKit] 백업할 Combo: \(combos.count)개")
        return (memos, smartClipboard, combos)
    }

    private func encodeDataForBackup(
        memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]
    ) throws -> (memosData: Data, smartClipboardData: Data, combosData: Data) {
        guard let memosData = try? JSONEncoder().encode(memos),
              let smartClipboardData = try? JSONEncoder().encode(smartClipboard),
              let combosData = try? JSONEncoder().encode(combos) else {
            print("❌ [CloudKit] JSON 인코딩 실패")
            throw CloudKitError.encodingFailed
        }
        print("📊 [CloudKit] 메모 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(memosData.count), countStyle: .file))")
        print("📊 [CloudKit] 스마트 클립보드 크기: \(ByteCountFormatter.string(fromByteCount: Int64(smartClipboardData.count), countStyle: .file))")
        print("📊 [CloudKit] Combo 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(combosData.count), countStyle: .file))")
        return (memosData, smartClipboardData, combosData)
    }

    private func fetchOrCreateRecord() async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
        do {
            let record = try await database.record(for: recordID)
            print("🔄 [CloudKit] 기존 백업 레코드 업데이트")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            print("✨ [CloudKit] 새 백업 레코드 생성")
            return CKRecord(recordType: "Backup", recordID: recordID)
        }
    }

    private func configureRecord(_ record: inout CKRecord, memosData: Data, smartClipboardData: Data, combosData: Data) throws {
        record["memosAsset"] = try createAsset(from: memosData, filename: "memos.json")
        record["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "smartClipboard.json")
        record["combosAsset"] = try createAsset(from: combosData, filename: "combos.json")
        record["backupDate"] = Date() as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        record["version"] = appVersion as CKRecordValue
        print("💾 [CloudKit] 레코드 데이터 업데이트 완료")
    }

    /// 재시도 로직이 포함된 레코드 저장
    private func saveRecordWithRetry(_ record: CKRecord, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                print("💾 [CloudKit] 저장 시도 \(attempt)/\(maxRetries)...")
                let savedRecord = try await database.save(record)
                print("✅ [CloudKit] 저장 성공 (시도 \(attempt))")
                return savedRecord
            } catch let error as CKError {
                lastError = error
                print("⚠️ [CloudKit] 저장 실패 (시도 \(attempt)): \(error.code.rawValue)")

                // 재시도 가능한 에러인지 확인
                switch error.code {
                case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
                    if attempt < maxRetries {
                        // 지수 백오프: 1초, 2초, 4초
                        let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                        print("   ⏳ \(attempt)초 후 재시도...")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                default:
                    // 재시도 불가능한 에러는 즉시 throw
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }

        // 모든 재시도 실패
        throw lastError ?? CloudKitError.backupFailed(NSError(domain: "CloudKitBackup", code: -1))
    }

    // MARK: - Restore

    /// 로컬에 데이터가 있는지 확인
    func hasLocalData() -> Bool {
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
            let combos = try MemoStore.shared.loadCombos()

            let totalCount = memos.count + smartClipboard.count + combos.count
            print("📊 [CloudKit] 로컬 데이터 확인: 메모 \(memos.count)개, 클립보드 \(smartClipboard.count)개, Combo \(combos.count)개")

            return totalCount > 0
        } catch {
            print("⚠️ [CloudKit] 로컬 데이터 확인 실패: \(error)")
            return false
        }
    }

    // MARK: - Auto Restore (시작 시 비어있으면 iCloud에서 가져오기)

    /// 로컬 데이터가 비어있고 iCloud에 백업이 있으면 시작 시 조용히 복원한다.
    /// 덮어쓸 로컬 데이터가 없으므로 사용자 확인 없이 안전하게 가져온다.
    /// (아이폰에서 만든 메모를 맥에서 바로 보이게 하는 핵심 동작)
    @discardableResult
    func autoRestoreIfLocalEmpty() async -> Bool {
        // 로컬에 데이터가 있으면 자동 복원하지 않음 — 사용자 데이터 보호.
        if hasLocalData() {
            print("ℹ️ [CloudKit] 로컬 데이터 존재 - 자동 복원 생략")
            return false
        }
        do {
            try await ensureAuthenticated()
        } catch {
            print("ℹ️ [CloudKit] iCloud 미인증 - 자동 복원 생략")
            return false
        }
        guard await hasBackup() else {
            print("ℹ️ [CloudKit] iCloud 백업 없음 - 자동 복원 생략")
            return false
        }
        do {
            // 위에서 로컬이 비어있음을 확인했으므로 덮어쓰기 안전.
            try await restoreData(forceOverwrite: true)
            print("🎉 [CloudKit] 시작 시 iCloud 자동 복원 완료")
            await MainActor.run {
                NotificationCenter.default.post(name: .dataRestored, object: nil)
            }
            return true
        } catch {
            print("⚠️ [CloudKit] 시작 자동 복원 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 복원 (기존 데이터 덮어쓰기 여부를 외부에서 확인 필요)
    /// - Parameter forceOverwrite: true면 확인 없이 덮어쓰기, false면 호출 전에 hasLocalData()로 확인 필요
    func restoreData(forceOverwrite: Bool = false) async throws {
        print("☁️ [CloudKit] 복구 시작...")

        try await ensureAuthenticated()

        if !forceOverwrite && hasLocalData() {
            print("⚠️ [CloudKit] 기존 데이터 존재 - 사용자 확인 필요")
            throw CloudKitError.restoreFailed(
                NSError(domain: "CloudKitBackup", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                        "기존 데이터가 있습니다. 복원하면 현재 데이터가 모두 삭제됩니다. 계속하시겠습니까?",
                        comment: "Restore confirmation message"
                    )
                ])
            )
        }

        await MainActor.run { isRestoring = true }
        defer { Task { @MainActor [weak self] in self?.isRestoring = false } }

        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            let record = try await database.record(for: recordID)
            print("📦 [CloudKit] 백업 레코드 찾음")
            if let version = record["version"] as? String {
                print("📦 [CloudKit] 백업 버전: \(version)")
            }

            let memos = try fetchMemos(from: record)
            let smartClipboard = fetchSmartClipboardHistory(from: record)
            let combos = fetchCombos(from: record)

            // 메모 본문을 저장하기 전에 첨부 이미지를 Images/에 먼저 복원(깨진 참조 방지).
            restoreImages(from: record)
            try saveRestoredData(memos: memos, smartClipboard: smartClipboard, combos: combos)
            print("🎉 [CloudKit] 전체 복구 완료!")

        } catch let error as CKError where error.code == .unknownItem {
            print("❌ [CloudKit] 백업 데이터 없음")
            throw CloudKitError.noBackupFound
        } catch {
            print("❌ [CloudKit] 복구 실패: \(error)")
            throw CloudKitError.restoreFailed(error)
        }
    }

    // MARK: - restoreData Helpers

    private func fetchMemos(from record: CKRecord) throws -> [Memo] {
        var memosData: Data?

        if let asset = record["memosAsset"] as? CKAsset {
            memosData = try? readAsset(asset)
            print("📦 [CloudKit] 메모 데이터 (Asset): \(memosData != nil ? "성공" : "실패")")
        }
        if memosData == nil, let legacyData = record["memos"] as? Data {
            memosData = legacyData
            print("📦 [CloudKit] 메모 데이터 (레거시): 성공")
        }

        guard let data = memosData else {
            print("❌ [CloudKit] 메모 데이터 없음")
            throw CloudKitError.noBackupFound
        }
        guard let memos = try? JSONDecoder().decode([Memo].self, from: data) else {
            print("❌ [CloudKit] 메모 디코딩 실패")
            throw CloudKitError.decodingFailed
        }
        print("📦 [CloudKit] 복구할 메모: \(memos.count)개")
        return memos
    }

    private func fetchSmartClipboardHistory(from record: CKRecord) -> [SmartClipboardHistory] {
        if let asset = record["smartClipboardAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            print("📦 [CloudKit] 복구할 스마트 클립보드 (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["smartClipboardHistory"] as? Data,
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: legacyData) {
            print("📦 [CloudKit] 복구할 스마트 클립보드 (레거시): \(decoded.count)개")
            return decoded
        }
        print("ℹ️ [CloudKit] 스마트 클립보드 데이터 없음")
        return []
    }

    private func fetchCombos(from record: CKRecord) -> [Combo] {
        if let asset = record["combosAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([Combo].self, from: data) {
            print("📦 [CloudKit] 복구할 Combo (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["combos"] as? Data,
           let decoded = try? JSONDecoder().decode([Combo].self, from: legacyData) {
            print("📦 [CloudKit] 복구할 Combo (레거시): \(decoded.count)개")
            return decoded
        }
        print("ℹ️ [CloudKit] Combo 데이터 없음")
        return []
    }

    private func saveRestoredData(
        memos: [Memo],
        smartClipboard: [SmartClipboardHistory],
        combos: [Combo]
    ) throws {
        print("💾 [CloudKit] 로컬 저장 시작...")
        try MemoStore.shared.save(memos: memos, type: .memo)
        print("✅ [CloudKit] 메모 \(memos.count)개 저장 완료")

        if !smartClipboard.isEmpty {
            try MemoStore.shared.saveSmartClipboardHistory(history: smartClipboard)
            print("✅ [CloudKit] 스마트 클립보드 \(smartClipboard.count)개 저장 완료")
        }
        if !combos.isEmpty {
            try MemoStore.shared.saveCombos(combos)
            print("✅ [CloudKit] Combo \(combos.count)개 저장 완료")
        }

        // 옛 백업을 복원하면 레거시 포맷(combos.data / isCombo / attachedTemplateId)이 되살아날 수 있다.
        // 콤보 통합 마이그레이션 플래그를 리셋해 iOS 앱이 다음 실행 시 신 모델로 재변환하게 한다.
        // (iOS CloudKitBackupService.saveRestoredData와 동일.)
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .set(false, forKey: DefaultsKey.comboModelUnifyMigratedV1)
    }

    // MARK: - Check Backup Existence

    func hasBackup() async -> Bool {
        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await database.record(for: recordID)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Delete Backup

    func deleteBackup() async throws {
        print("🗑️ [CloudKit] 백업 삭제 시작...")

        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await database.deleteRecord(withID: recordID)

            await MainActor.run {
                lastBackupDate = nil
                UserDefaults.standard.removeObject(forKey: DefaultsKey.lastBackupDate)
            }

            print("✅ [CloudKit] 백업 삭제 완료")
        } catch {
            print("❌ [CloudKit] 백업 삭제 실패: \(error)")
            throw error
        }
    }
}
