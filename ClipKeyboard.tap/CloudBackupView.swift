//
//  CloudBackupView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit
import CloudKit
import UniformTypeIdentifiers

struct CloudBackupView: View {
    @StateObject private var cloudService = CloudKitBackupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    // 파일 백업(내보내기/가져오기) — CloudKit·로그인과 무관한 최후의 보루
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupFileDocument? = nil
    @State private var exportFilename = "ClipKeyboard-Backup.json"
    // 타임머신 — 백업할 때마다 쌓인 시점별 스냅샷. 최신 백업 하나만 있던 시절엔
    // 잘못된 백업이 한 번 끼면 직전 상태가 그대로 사라졌다.
    @State private var snapshots: [BackupSnapshotInfo] = []
    @State private var isLoadingSnapshots = false
    @State private var restoringSnapshot: String?

    var body: some View {
        backupContentView
    }

    private var backupContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: MacSpacing.xl) {
            // 헤더
            VStack(spacing: MacSpacing.sm) {
                Text(NSLocalizedString("iCloud 백업 및 복구", comment: "iCloud backup and restore title"))
                    .font(MacFont.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("데이터를 iCloud에 안전하게 백업하세요", comment: "Backup description"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // iCloud 상태 · 마지막 백업 — 한 장의 카드로 묶는다.
            VStack(spacing: MacSpacing.md) {
                HStack(spacing: MacSpacing.sm) {
                    Image(systemName: cloudService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                    Text(NSLocalizedString("iCloud 상태:", comment: "iCloud status label"))
                        .foregroundStyle(.secondary)

                    Text(cloudService.isAuthenticated ? NSLocalizedString("연결됨", comment: "Connected status") : NSLocalizedString("연결 안 됨", comment: "Disconnected status"))

                    Spacer()

                    Button(NSLocalizedString("상태 확인", comment: "Check status button")) {
                        cloudService.checkAccountStatus()
                    }
                }

                if let lastBackupDate = cloudService.lastBackupDate {
                    Divider()
                    HStack(spacing: MacSpacing.sm) {
                        Text(NSLocalizedString("마지막 백업:", comment: "Last backup label"))
                            .foregroundStyle(.secondary)

                        Text(lastBackupDate, style: .relative)

                        Text(NSLocalizedString("전", comment: "ago"))

                        Spacer()
                    }
                }
            }
            .font(MacFont.body)
            .padding(MacSpacing.lg)
            .macSurface()

            // 액션 버튼들
            VStack(spacing: MacSpacing.md) {
                Button {
                    performBackup()
                } label: {
                    actionLabel(
                        symbol: AppSymbol.icloudAndArrowUp,
                        title: cloudService.isBackingUp ? NSLocalizedString("백업 중...", comment: "Backing up status") : NSLocalizedString("백업하기", comment: "Backup button"),
                        isBusy: cloudService.isBackingUp
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!cloudService.isAuthenticated || cloudService.isBackingUp)

                Button {
                    performRestore()
                } label: {
                    actionLabel(
                        symbol: AppSymbol.icloudAndArrowDown,
                        title: cloudService.isRestoring ? NSLocalizedString("복구 중...", comment: "Restoring status") : NSLocalizedString("복구하기", comment: "Restore button"),
                        isBusy: cloudService.isRestoring
                    )
                }
                .disabled(!cloudService.isAuthenticated || cloudService.isRestoring)

                Button {
                    performDelete()
                } label: {
                    actionLabel(symbol: AppSymbol.trash, title: NSLocalizedString("백업 삭제", comment: "Delete backup button"))
                }
                .tint(.red)
                .disabled(!cloudService.isAuthenticated || cloudService.lastBackupDate == nil)

                Text(NSLocalizedString("⚠️ 복구 시 현재 데이터가 백업 데이터로 교체됩니다", comment: "Restore warning"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, MacSpacing.xs)
            }

            Divider()

            timeMachineSection

            Divider()

            // 파일 백업 — iCloud가 막혀도 데이터를 기기 파일로 직접 빼낼 수 있는 최후의 보루
            VStack(spacing: MacSpacing.md) {
                Button {
                    performExportToFile()
                } label: {
                    actionLabel(symbol: AppSymbol.arrowUpDocFill, title: NSLocalizedString("파일로 내보내기", comment: "Export to file button"))
                }

                Button {
                    showImporter = true
                } label: {
                    actionLabel(symbol: AppSymbol.arrowDownDocFill, title: NSLocalizedString("파일에서 가져오기", comment: "Import from file button"))
                }

                Text(NSLocalizedString("📁 파일 백업은 iCloud와 별개로 데이터를 파일로 보관하는 가장 확실한 방법입니다. 가져오기는 현재 데이터를 지우지 않고 합칩니다.", comment: "File backup info"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, MacSpacing.xs)
            }
            }
            .controlSize(.large)
            .padding(MacSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 500, minHeight: 460)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                alertTitle = NSLocalizedString("내보내기 완료", comment: "Export completed")
                alertMessage = NSLocalizedString("데이터를 파일로 저장했습니다. 안전한 곳에 보관하세요.", comment: "Export success message")
            case .failure(let error):
                alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
                alertMessage = error.localizedDescription
            }
            showAlert = true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 타임머신

    /// 백업할 때마다 쌓인 시점별 스냅샷 목록. 최근 형상으로 되돌아가는 자리.
    private var timeMachineSection: some View {
        VStack(alignment: .leading, spacing: MacSpacing.md) {
            HStack {
                Label(NSLocalizedString("이전 시점으로 되돌리기", comment: "Time machine section title"),
                      systemImage: "clock.arrow.circlepath")
                    .font(MacFont.sectionTitle)
                Spacer()
                if isLoadingSnapshots {
                    ProgressView().controlSize(.small)
                } else {
                    Button(NSLocalizedString("새로고침", comment: "Refresh button")) { loadSnapshots() }
                        .buttonStyle(.link)
                        .font(MacFont.secondary)
                }
            }

            if snapshots.isEmpty {
                Text(isLoadingSnapshots
                     ? NSLocalizedString("불러오는 중…", comment: "Loading snapshots")
                     : NSLocalizedString("보관된 시점이 아직 없습니다. 백업을 한 번 하면 그때부터 쌓입니다.", comment: "No snapshots yet"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(snapshots) { snap in
                        snapshotRow(snap)
                        if snap.id != snapshots.last?.id { Divider() }
                    }
                }
                .macSurface()

                Text(NSLocalizedString("⚠️ 되돌리면 현재 데이터가 그 시점의 데이터로 교체됩니다. 최근 15개까지 보관됩니다.", comment: "Time machine warning"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { loadSnapshots() }
    }

    private func snapshotRow(_ snap: BackupSnapshotInfo) -> some View {
        HStack(spacing: MacSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                    .font(MacFont.body)
                Text(String(format: NSLocalizedString("단축어 %d개", comment: "Snapshot memo count"), snap.memoCount))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if restoringSnapshot == snap.recordName {
                ProgressView().controlSize(.small)
            } else {
                Button(NSLocalizedString("되돌리기", comment: "Restore to this point")) {
                    confirmRestoreSnapshot(snap)
                }
                .controlSize(.small)
                .disabled(cloudService.isRestoring || restoringSnapshot != nil)
            }
        }
        .padding(.horizontal, MacSpacing.md)
        .padding(.vertical, MacSpacing.sm)
    }

    private func loadSnapshots() {
        guard cloudService.isAuthenticated, !isLoadingSnapshots else { return }
        isLoadingSnapshots = true
        Task {
            let list = await cloudService.listSnapshots()
            await MainActor.run {
                snapshots = list
                isLoadingSnapshots = false
            }
        }
    }

    /// 되돌리기는 현재 데이터를 지우는 동작이라 반드시 한 번 묻는다.
    @MainActor
    private func confirmRestoreSnapshot(_ snap: BackupSnapshotInfo) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("이 시점으로 되돌릴까요?", comment: "Restore snapshot confirm title")
        alert.informativeText = String(
            format: NSLocalizedString("%1$@ 시점(단축어 %2$d개)으로 되돌립니다. 지금의 데이터는 이 시점의 데이터로 교체됩니다.", comment: "Restore snapshot confirm body"),
            snap.date.formatted(date: .abbreviated, time: .shortened), snap.memoCount)
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("되돌리기", comment: "Restore to this point"))
        alert.addButton(withTitle: NSLocalizedString("취소", comment: "Cancel button"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        restoringSnapshot = snap.recordName
        Task {
            do {
                // 사용자가 방금 동의했으므로 덮어쓰기 확인을 다시 묻지 않는다.
                try await cloudService.restoreData(forceOverwrite: true, snapshotName: snap.recordName)
                await MainActor.run {
                    restoringSnapshot = nil
                    alertTitle = NSLocalizedString("되돌리기 완료", comment: "Snapshot restore completed")
                    alertMessage = String(
                        format: NSLocalizedString("%@ 시점의 데이터로 되돌렸습니다.", comment: "Snapshot restore success"),
                        snap.date.formatted(date: .abbreviated, time: .shortened))
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    restoringSnapshot = nil
                    alertTitle = NSLocalizedString("되돌리기 실패", comment: "Snapshot restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    /// 백업/복구/내보내기 버튼의 공통 라벨 — 폭·높이·글자 크기를 하나로 맞춘다.
    private func actionLabel(symbol: String, title: String, isBusy: Bool = false) -> some View {
        HStack(spacing: MacSpacing.sm) {
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol)
            }
            Text(title)
        }
        .font(MacFont.body)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MacSpacing.xs)
    }

    // MARK: - Actions

    /// - Parameter allowReduce: 축소 경고에 사용자가 "계속"을 눌러 다시 부를 때 true.
    private func performBackup(allowReduce: Bool = false) {
        Task {
            do {
                let outcome = try await cloudService.backupData(allowReduce: allowReduce)
                await MainActor.run { showBackupOutcome(outcome) }
            } catch let error as CloudKitError {
                // 기존 백업을 대폭 줄이는 백업은 묻고 나서 한다 - 조용히 덮으면
                // 아이폰이 올려 둔 백업이 이 맥의 적은 데이터로 사라진다.
                if case .backupWouldReduceData = error {
                    await MainActor.run { confirmReducingBackup(message: error.localizedDescription) }
                } else {
                    await MainActor.run { showBackupFailure(error.localizedDescription) }
                }
            } catch {
                await MainActor.run { showBackupFailure(error.localizedDescription) }
            }
        }
    }

    @MainActor
    private func showBackupOutcome(_ outcome: BackupOutcome) {
        switch outcome {
        case .backedUp(let memoCount):
            alertTitle = NSLocalizedString("백업 완료", comment: "Backup completed")
            alertMessage = String(format: NSLocalizedString("단축어 %d개를 iCloud에 백업했습니다.", comment: "Backup success with count"), memoCount)
            loadSnapshots()   // 방금 쌓인 시점이 목록에 바로 보이도록
        case .nothingToBackUp:
            alertTitle = NSLocalizedString("백업할 것이 없습니다", comment: "Nothing to back up title")
            alertMessage = NSLocalizedString("저장된 단축어가 없어 백업하지 않았습니다.", comment: "Nothing to back up body")
        case .skippedToProtectExisting(let existing, let new):
            alertTitle = NSLocalizedString("기존 백업을 지켰습니다", comment: "Backup skipped title")
            alertMessage = String(format: NSLocalizedString("이 기기의 단축어가 %2$d개뿐이라 %1$d개짜리 기존 백업을 덮어쓰지 않았습니다.", comment: "Backup skipped body"), existing, new)
        }
        showAlert = true
    }

    @MainActor
    private func showBackupFailure(_ message: String) {
        alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
        alertMessage = message
        showAlert = true
    }

    @MainActor
    private func showRestoreFailure(_ message: String) {
        alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
        alertMessage = message
        showAlert = true
    }

    /// 덮어쓰기 동의 창. "복구"면 overwrite=true 로 다시 부른다.
    @MainActor
    private func confirmReplacingLocalData(message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("지금의 단축어를 교체할까요?", comment: "Restore overwrite confirm title")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("복구", comment: "Restore button (confirm)"))
        alert.addButton(withTitle: NSLocalizedString("취소", comment: "Cancel button"))
        if alert.runModal() == .alertFirstButtonReturn {
            performRestore(overwrite: true)
        }
    }

    /// 축소 백업 동의 창. "계속"이면 allowReduce=true 로 다시 부른다.
    @MainActor
    private func confirmReducingBackup(message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("기존 백업이 줄어듭니다", comment: "Reducing backup confirm title")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("계속", comment: "Continue button"))
        alert.addButton(withTitle: NSLocalizedString("취소", comment: "Cancel button"))
        if alert.runModal() == .alertFirstButtonReturn {
            performBackup(allowReduce: true)
        }
    }

    /// - Parameter overwrite: 덮어쓰기 확인에 사용자가 "복구"를 눌러 다시 부를 때 true.
    private func performRestore(overwrite: Bool = false) {
        Task {
            do {
                try await cloudService.restoreData(forceOverwrite: overwrite)
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("백업 데이터가 성공적으로 복구되었습니다.", comment: "Backup data successfully restored")
                    showAlert = true
                }
            } catch let error as CloudKitError {
                // 이 기기의 단축어를 덮어쓰는 복구는 묻고 나서 한다 - 조용히 덮으면
                // 백업 시점 이후에 만든 단축어가 말 없이 사라진다.
                if case .restoreWouldReplaceData = error {
                    await MainActor.run { confirmReplacingLocalData(message: error.localizedDescription) }
                } else {
                    await MainActor.run { showRestoreFailure(error.localizedDescription) }
                }
            } catch {
                await MainActor.run { showRestoreFailure(error.localizedDescription) }
            }
        }
    }

    private func performDelete() {
        Task {
            do {
                try await cloudService.deleteBackup()
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 완료", comment: "Deletion completed")
                    alertMessage = NSLocalizedString("백업 데이터가 삭제되었습니다.", comment: "Backup data deleted")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 실패", comment: "Deletion failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    // MARK: - 파일 백업 (내보내기/가져오기)

    private func performExportToFile() {
        do {
            let data = try DataPortability.makeBundleData()
            exportDocument = BackupFileDocument(data: data)
            exportFilename = DataPortability.suggestedFilename()
            showExporter = true
        } catch {
            alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
            alertMessage = error.localizedDescription
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let summary = try DataPortability.importBundle(data)
                NotificationCenter.default.post(name: .dataRestored, object: nil)
                alertTitle = NSLocalizedString("가져오기 완료", comment: "Import completed")
                alertMessage = summary.localizedDescription
                showAlert = true
            } catch {
                alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - 파일 백업 번들 (내보내기/가져오기)

/// App Group에 저장된 모든 사용자 데이터를 담는 자기완결형 백업 번들.
/// 이미지까지 base64로 동봉하므로 이 파일 하나로 전체 복원이 가능하다.
struct ExportBundle: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var memos: [Memo]
    var smartClipboard: [SmartClipboardHistory]
    var combos: [Combo]
    var images: [String: Data]
}

/// 가져오기 결과 요약.
struct ImportSummary {
    var addedMemos: Int
    var updatedMemos: Int
    var totalMemos: Int
    var addedCombos: Int
    var addedClips: Int
    var images: Int

    var localizedDescription: String {
        String(format: NSLocalizedString("단축어 %1$d개 추가, %2$d개 갱신 (총 %3$d개).\n콤보 %4$d개, 이미지 %5$d개를 가져왔습니다.", comment: "Import summary message"),
               addedMemos, updatedMemos, totalMemos, addedCombos, images)
    }
}

enum PortabilityError: LocalizedError {
    case noContainer
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .noContainer:
            return NSLocalizedString("저장소를 찾을 수 없습니다.", comment: "App Group container missing")
        case .unreadableFile:
            return NSLocalizedString("이 파일은 ClipKeyboard 백업 파일이 아니거나 손상되었습니다.", comment: "Unrecognized backup file")
        }
    }
}

/// 내보내기/가져오기 공통 로직. App Group 컨테이너 파일을 직접 다루므로
/// UIKit/AppKit 의존이 없고 iOS·macOS 양쪽에서 동일하게 동작한다.
enum DataPortability {
    static let currentFormatVersion = 1

    private static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    private static func read<T: Decodable>(_ file: String, as type: T.Type) -> T? {
        guard let url = container()?.appendingPathComponent(file),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to file: String) throws {
        guard let url = container()?.appendingPathComponent(file) else { throw PortabilityError.noContainer }
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    static var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    static func suggestedFilename() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return "ClipKeyboard-Backup-\(f.string(from: Date())).json"
    }

    /// 현재 App Group의 모든 데이터를 JSON 번들로 직렬화(이미지 동봉).
    static func makeBundleData() throws -> Data {
        let memos = read(StorageFile.memos, as: [Memo].self) ?? []
        let smart = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        let combos = read(StorageFile.combos, as: [Combo].self) ?? []

        var images: [String: Data] = [:]
        if let imagesDir = container()?.appendingPathComponent("Images", isDirectory: true) {
            for name in Set(memos.flatMap { $0.imageFileNames }) {
                if let d = try? Data(contentsOf: imagesDir.appendingPathComponent(name)) {
                    images[name] = d
                }
            }
        }

        let bundle = ExportBundle(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            appVersion: appVersionString,
            memos: memos, smartClipboard: smart, combos: combos, images: images
        )
        return try JSONEncoder().encode(bundle)
    }

    /// 번들을 병합 가져오기. 절대 삭제하지 않고, id 기준으로 합치며 충돌 시 최신본(lastEdited) 유지.
    @discardableResult
    static func importBundle(_ data: Data) throws -> ImportSummary {
        guard let bundle = try? JSONDecoder().decode(ExportBundle.self, from: data) else {
            throw PortabilityError.unreadableFile
        }
        guard let container = container() else { throw PortabilityError.noContainer }

        // 1) 이미지 먼저 복원(메모가 참조). 이미 있으면 보존.
        var restoredImages = 0
        if !bundle.images.isEmpty {
            let imagesDir = container.appendingPathComponent("Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            for (name, bytes) in bundle.images {
                let dest = imagesDir.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try? bytes.write(to: dest, options: .atomic)
                    restoredImages += 1
                }
            }
        }

        // 2) 메모 병합 (순서 보존, id 충돌 시 최신 lastEdited 우선)
        var memos = read(StorageFile.memos, as: [Memo].self) ?? []
        var indexById = [UUID: Int]()
        for (i, m) in memos.enumerated() { indexById[m.id] = i }
        var added = 0, updated = 0
        for m in bundle.memos {
            if let i = indexById[m.id] {
                if m.lastEdited > memos[i].lastEdited { memos[i] = m; updated += 1 }
            } else {
                indexById[m.id] = memos.count
                memos.append(m)
                added += 1
            }
        }
        try write(memos, to: StorageFile.memos)

        // 3) 콤보 병합 (union by id)
        var combos = read(StorageFile.combos, as: [Combo].self) ?? []
        var comboIds = Set(combos.map { $0.id })
        var addedCombos = 0
        for c in bundle.combos where !comboIds.contains(c.id) {
            combos.append(c); comboIds.insert(c.id); addedCombos += 1
        }
        try write(combos, to: StorageFile.combos)

        // 4) 스마트 클립보드 병합 (union by id)
        var clips = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        var clipIds = Set(clips.map { $0.id })
        var addedClips = 0
        for c in bundle.smartClipboard where !clipIds.contains(c.id) {
            clips.append(c); clipIds.insert(c.id); addedClips += 1
        }
        try write(clips, to: StorageFile.smartClipboardHistory)

        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)

        return ImportSummary(addedMemos: added, updatedMemos: updated, totalMemos: memos.count,
                             addedCombos: addedCombos, addedClips: addedClips, images: restoredImages)
    }
}

// MARK: - 파일 도큐먼트 (fileExporter/fileImporter 용)

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    CloudBackupView()
}
