//
//  MemoSyncEngine.swift
//  ClipKeyboard
//
//  메모 실시간 동기화(iPhone ↔ Mac) - CKSyncEngine 기반 레코드 단위 동기화.
//  로컬 JSON 저장소(MemoStore)는 그대로 두고, 그 위에서 CloudKit 프라이빗 DB의
//  커스텀 존을 동기화한다. 충돌은 id 단위 최신 우선 + 툼스톤(소프트 삭제)으로 해결.
//  순수 로직은 MemoSyncCore(단위 테스트 완비), 여기서는 CloudKit 연결만 담당한다.
//  iOS·macOS(.tap) 두 타겟이 공유한다(AppGroup.swift 패턴).
//
//  ⚠️ 기본 비활성(MemoSyncFlags.enabled = false). Pro + 플래그 ON일 때만 start().
//

import Foundation
import CloudKit
import CryptoKit   // 카테고리 스냅샷 지문(SHA256) - 실행 간 안정적인 해시가 필요하다
import os

enum MemoSyncFlags {
    /// 마스터 스위치. **이 기기의 값만** 본다(App Group).
    ///
    /// ⚠️ 예전에는 iCloud KV 값도 함께 봤다. 그런데 KV 는 **앱을 지워도 남고 계정을 따라
    ///    다닌다.** 그래서 앱을 지웠다 깐 사람, 새 아이폰을 켠 사람의 **첫 실행**에 이미
    ///    켜져 있었고, 런치가 끝나기도 전에 엔진이 원격을 통째로 당겨왔다.
    ///    "기존 단축어를 불러올까요"에 **나중에**를 눌러도 이미 들어와 있던 이유가 이것이다.
    ///    (설정의 토글은 App Group 값을 그리므로 화면에는 꺼짐으로 보였다. 보이는 것과
    ///     도는 것이 어긋난 셈이다.)
    ///
    /// ⚠️ 남의 데이터를 이 기기로 당겨오는 일은 **이 기기에서 예라고 한 뒤**에만 한다.
    ///    다른 기기의 설정은 "이 기능을 원한다"는 뜻이지, 아직 아무것도 담기지 않은
    ///    기기가 계정 전체를 내려받아도 좋다는 뜻이 아니다.
    static var enabled: Bool {
        AppGroup.defaults?.bool(forKey: DefaultsKey.memoSyncEnabled) == true
    }

    /// 토글 시 양쪽(App Group + iCloud KV)에 기록 - 다른 기기로 전파.
    static func setEnabled(_ on: Bool) {
        AppGroup.defaults?.set(on, forKey: DefaultsKey.memoSyncEnabled)
        // 사람이 이 기기에서 직접 골랐다 - 아래 승계 판정이 이 선택을 덮지 않도록 못박는다.
        AppGroup.defaults?.set(true, forKey: DefaultsKey.memoSyncCloudAdoptedV1)
        NSUbiquitousKeyValueStore.default.set(on, forKey: DefaultsKey.memoSyncEnabled)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// iCloud KV 에 켜져 있는 설정을 **이 기기가 이어받을지** 한 번만 판정한다.
    ///
    /// 이어받는 경우는 하나뿐이다: **이 기기가 이미 동기화를 돌린 적이 있다.**
    /// 그 표식(마지막 수신·전송 시각)이 남아 있다면 이 기기에는 이미 계정 데이터가 있고,
    /// 더 받아온다고 놀랄 일이 없다. 켜 둔 채로 업데이트한 사람의 동기화가 이 변경으로
    /// 조용히 멎지 않게 하는 것이 이 함수의 몫이다.
    ///
    /// 갓 설치한 기기에는 그 표식이 없다 - 그래서 아무것도 이어받지 않고, 사람이
    /// 설정에서 직접 켤 때까지 엔진은 잠들어 있다.
    static func adoptCloudPreferenceIfNeeded() {
        guard let defaults = AppGroup.defaults else { return }
        guard !defaults.bool(forKey: DefaultsKey.memoSyncCloudAdoptedV1) else { return }
        defaults.set(true, forKey: DefaultsKey.memoSyncCloudAdoptedV1)

        guard NSUbiquitousKeyValueStore.default.bool(forKey: DefaultsKey.memoSyncEnabled) else { return }

        let hasSyncedHere = defaults.object(forKey: DefaultsKey.syncLastPullAt) != nil
            || defaults.object(forKey: DefaultsKey.syncLastPushAt) != nil
        guard hasSyncedHere else {
            print("🔒 [MemoSync] iCloud 설정은 켜져 있지만 이 기기는 처음이다. 사람이 켤 때까지 쉰다")
            return
        }
        defaults.set(true, forKey: DefaultsKey.memoSyncEnabled)
        print("🔄 [MemoSync] 이미 동기화하던 기기, iCloud 설정 승계")
    }
}

/// 동기화가 실제로 돌고 있는지 보여주기 위한 최소 기록.
/// "지금 다른 기기(아이폰) 데이터를 받아오고 있나?"에 답하는 화면(맥 앱의 동기화 상태)이 이 값을 읽는다.
/// 마지막 수신/전송/확인/오류는 App Group에 남겨 앱을 다시 켜도 유지되고,
/// 엔진 실행 여부만 프로세스 메모리에 둔다(실행 때마다 새로 시작하므로).
enum MemoSyncStatus {
    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 이번 실행에서 엔진이 시작됐는지 - false면 게이트(플래그/Pro)에 막혀 아예 안 돌고 있는 것.
    nonisolated(unsafe) private static var running = false
    static var isRunning: Bool { running }

    /// 마지막으로 원격 변경을 이 기기에 적용한 시각과 건수 - "받아오고 있다"의 직접 증거.
    static var lastPullAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastPullAt) as? Date }
    static var lastPullCount: Int { defaults?.integer(forKey: DefaultsKey.syncLastPullCount) ?? 0 }
    /// 마지막으로 이 기기 변경을 올린 시각과 건수.
    static var lastPushAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastPushAt) as? Date }
    static var lastPushCount: Int { defaults?.integer(forKey: DefaultsKey.syncLastPushCount) ?? 0 }
    /// 받을 게 없어도 갱신되는 마지막 확인 시각 - 연결이 살아있다는 근거.
    static var lastCheckAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastCheckAt) as? Date }
    /// 마지막 오류(성공하면 지워진다).
    static var lastError: String? { defaults?.string(forKey: DefaultsKey.syncLastError) }
    static var lastErrorAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastErrorAt) as? Date }

    // MARK: - 기록 (엔진 전용)

    static func markRunning() { running = true }

    static func recordPull(count: Int, at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastPullAt)
        defaults?.set(count, forKey: DefaultsKey.syncLastPullCount)
    }

    static func recordPush(count: Int, at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastPushAt)
        defaults?.set(count, forKey: DefaultsKey.syncLastPushCount)
    }

    static func recordCheck(at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastCheckAt)
    }

    static func recordError(_ message: String, at date: Date = Date()) {
        defaults?.set(message, forKey: DefaultsKey.syncLastError)
        defaults?.set(date, forKey: DefaultsKey.syncLastErrorAt)
    }

    static func clearError() {
        defaults?.removeObject(forKey: DefaultsKey.syncLastError)
        defaults?.removeObject(forKey: DefaultsKey.syncLastErrorAt)
    }
}

@available(iOS 17.0, macOS 14.0, *)
final class MemoSyncEngine: NSObject, CKSyncEngineDelegate {
    static let shared = MemoSyncEngine()

    private let log = Logger(subsystem: "com.Ysoup.TokenMemo", category: "MemoSync")
    private let containerID = "iCloud.com.Ysoup.TokenMemo"
    static let zoneName = "MemosZone"
    static let recordType = "Memo"

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // 싱글톤 직렬 사용(메인 흐름 + CKSyncEngine 콜백). Sendable 경고 의도적 수용.
    nonisolated(unsafe) private var engine: CKSyncEngine?
    nonisolated(unsafe) private var started = false
    /// 배선을 만드는 중인 작업. `engine` 이 생기는 시점이 `startIfEnabled()` 리턴보다
    /// 뒤이므로, 곧바로 이어지는 `syncNow()` 가 이걸 기다렸다가 엔진을 본다.
    nonisolated(unsafe) private var startTask: Task<Void, Never>?
    /// 원격 변경을 로컬에 적용하는 동안 true - 이 사이의 .memoDataChanged는 무시(에코 루프 차단).
    nonisolated(unsafe) private var isApplyingRemoteChanges = false

    private var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - Lifecycle

    /// 권한 + 플래그가 켜져 있을 때만 동기화를 시작한다. 멱등. (맥은 권한 게이트 없음)
    func startIfEnabled() {
        // 켜 둔 채로 업데이트한 기기를 먼저 건져낸다 - 게이트를 보기 전에 한 번만 돈다.
        MemoSyncFlags.adoptCloudPreferenceIfNeeded()
        guard MemoSyncFlags.enabled else { log.info("sync disabled by flag"); return }
        // 원격 킬스위치 - 동기화가 사고를 냈을 때 심사 없이 끌 수 있는 경로.
        // 조회 실패 시엔 true(켬)라 네트워크가 없다고 동기화가 막히지는 않는다.
        guard RemoteFlagsService.cachedValue(.syncEnabled) else {
            log.info("sync disabled by remote flag"); return
        }
        guard hasSyncEntitlement else { log.info("sync gated: no entitlement"); return }
        guard !started else { return }
        // ⚠️ 실제 시작은 아래 Task 안에서 끝나지만, 이 표식은 **여기서** 세운다.
        //    포그라운드 복귀가 잇따라 오면 Task 가 뜨기 전에 다시 불릴 수 있고,
        //    그러면 엔진이 두 개 만들어진다.
        started = true
        MemoSyncStatus.markRunning()

        // ⚠️ **CloudKit 배선을 메인 스레드에서 만들지 않는다.**
        //    `CKContainer(identifier:)` 도 `CKSyncEngine(_:)` 도 cloudd 와 XPC 를 주고받는다.
        //    이 메서드는 런치 시퀀스와 포그라운드 복귀(`scenePhase == .active`) 양쪽에서
        //    메인 액터로 불리는데, 그 자리에서 데몬이 대답하지 않으면 화면이 통째로 멈춘다.
        //    같은 종류의 한 줄이 4.4.6 런치를 22초 붙잡아 워치독에 죽었다.
        //    기록: docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md
        startTask = Task { [weak self] in
            guard let self else { return }
            let database = await CloudKitContainer.privateDatabase(self.containerID)
            // 엔진 상태를 읽기 **전에** 확인한다 - 다른 데이터베이스의 상태로 엔진을 만들면
            // 그 엔진은 받을 것도 보낼 것도 없다고 여기고 조용히 논다.
            await self.verifyBaseline(in: database)
            let config = CKSyncEngine.Configuration(
                database: database,
                stateSerialization: self.loadState(),
                delegate: self
            )
            let engine = CKSyncEngine(config)
            self.engine = engine
            // 존 생성(이미 있으면 무시됨) - CKSyncEngine이 처리.
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: self.zoneID))])

            NotificationCenter.default.addObserver(
                self, selector: #selector(self.localDataChanged),
                name: .memoDataChanged, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(self.localCategoriesChanged),
                name: .categoryDataChanged, object: nil)

            self.log.info("MemoSyncEngine started")
            // 시작 시 한 번: 로컬 미동기 변경을 큐에 올리고, 원격을 당겨온다.
            self.cleanUpLegacyCategoryRecords()
            self.enqueueLocalChanges()
            self.announceTombstonesIfNeeded()
            try? await engine.fetchChanges()
        }
    }

    /// 동기화 권한 - ProFeatureManager의 키를 직접 읽어 양 타겟 의존을 피한다.
    ///
    /// ⚠️ **맥은 게이트가 없다.** 맥 앱은 스토어 유료 다운로드라 구매 자체가 전체 권한이다
    ///    (`ClipKeyboardTapSpec.monetization = .paidUpfront`). 아이폰 결제 키를 보던 시절엔
    ///    맥만 산 사용자가 토글을 켜도 엔진이 조용히 거부해 아무것도 올라가지 않았다.
    ///
    /// ⚠️ 결제 키(`proStatus`) 하나만 보면 안 된다. 이 앱은 **결제 외 경로**로도 전체 접근 권한을 준다:
    /// v4.0 이전 유료 구매자(`wasProAtV3`) · TestFlight/체험 (`syncEntitled` 로 미러링).
    /// ⚠️ `existingFreeUser` 는 보지 않는다. 기기에서 짐작한 표시라 권한이 아니다
    ///    (`ProFeatureManager.isGrandfathered(hasPurchase:wasExistingFreeUser:existingFreeUserVerified:)`).
    ///    아직 영수증으로 확인 못 한 옛 표시는 `syncEntitled` 에 이미 반영돼 있다.
    /// 설정의 동기화 토글은 `hasFullAccess` 로 열리는데 엔진만 결제를
    /// 요구하던 탓에, 그랜드파더 사용자는 **토글이 켜져 있는데도 엔진이 조용히 거부**해
    /// 아이폰에서 아무것도 올라가지 않았다.
    private var hasSyncEntitlement: Bool {
        #if os(macOS)
        return true
        #else
        // App Group + iCloud KV 어느 쪽이든 켜져 있으면 인정(기존 백업 게이팅과 동일 취지).
        let keys = [DefaultsKey.proStatus, DefaultsKey.wasProAtV3, DefaultsKey.syncEntitled]
        for key in keys {
            if defaults?.bool(forKey: key) == true { return true }
            if NSUbiquitousKeyValueStore.default.bool(forKey: key) { return true }
        }
        return false
        #endif
    }

    /// 외부(포그라운드/푸시)에서 즉시 동기화를 요청.
    ///
    /// ⚠️ 엔진이 아직 만들어지는 중일 수 있다. 배선을 메인 스레드 밖으로 옮긴 뒤로
    ///    `startIfEnabled()` 는 엔진을 만들기 전에 리턴한다. 기다리지 않으면 콜드 런치
    ///    직후 첫 요청이 조용히 아무 일도 안 하고 끝난다.
    func syncNow() {
        Task { [weak self] in
            guard let self else { return }
            await self.startTask?.value
            guard let engine = self.engine else { return }
            self.enqueueLocalChanges()
            try? await engine.fetchChanges()
            try? await engine.sendChanges()
        }
    }

    // MARK: - Local change detection (push)

    /// 카테고리 열쇠만 바뀌었을 때 - 단축어 비교까지 돌릴 필요는 없다.
    @objc private func localCategoriesChanged() {
        guard !isApplyingRemoteChanges else { return }
        enqueueCategoryItemChanges()
    }

    @objc private func localDataChanged() {
        guard !isApplyingRemoteChanges else { return }
        enqueueLocalChanges()
    }

    /// 동기화 대상 메모 - **시드 샘플은 제외한다.**
    ///
    /// ⚠️ 샘플은 기기마다 **새 UUID로** 심기고 내용이 기기 언어를 따른다(영어 폰은 영어 샘플,
    ///    한국어 폰은 한국어 샘플). 그대로 올리면 동기화가 서로 다른 메모로 보고 양쪽에
    ///    퍼뜨려서, 폰 2대를 쓰거나 맥·아이폰을 함께 쓰면 "모르는 단축어가 섞여" 보인다.
    ///    샘플은 온보딩 장식이지 사용자 데이터가 아니다 - 백업도 이미 실데이터에서 제외한다.
    ///
    /// ⚠️ **병합(applyFetched)의 기준 목록에는 쓰지 말 것.** 거기서 샘플을 빼면
    ///    병합 결과를 저장할 때 로컬 샘플이 통째로 지워진다. 업로드 산출에만 쓴다.
    private func syncableMemos() -> [Memo] {
        let all = (try? MemoStore.shared.load(type: .memo)) ?? []
        let sampleIDs = SampleMemoStorage.load()
        guard !sampleIDs.isEmpty else { return all }
        return all.filter { !sampleIDs.contains($0.id) }
    }

    private func enqueueLocalChanges() {
        guard let engine else { return }
        enqueueCategorySettingsIfChanged()
        enqueueCategoryItemChanges()

        let current = syncableMemos()
        let changes = MemoSyncCore.localChanges(
            current: current, shadow: loadShadow(),
            knownTombstones: loadTombstones(), now: Date())
        guard !changes.isEmpty else { return }

        var tombstones = loadTombstones()
        for (id, at) in changes.newTombstones { tombstones[id] = at }
        // 살아있는 단축어의 툼스톤은 남아 있으면 안 된다 - 남으면 그 id 로 오는 원격 메모를
        // "이미 지운 것"으로 보고 계속 무시한다(되살린 단축어가 다른 기기에서 안 보이는 원인).
        let aliveIDs = Set(((try? MemoStore.shared.load(type: .memo)) ?? []).map(\.id))
        tombstones = tombstones.filter { !aliveIDs.contains($0.key) }
        saveTombstones(tombstones)

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for memo in changes.upserts { pending.append(.saveRecord(recordID(memo.id))) }
        for id in changes.newTombstones.keys { pending.append(.saveRecord(recordID(id))) }
        engine.state.add(pendingRecordZoneChanges: pending)

        // ⚠️ 여기서 섀도를 갱신하지 않는다 - 서버 저장이 확정된 뒤(confirmSent)에만 기록한다.
        // 예전엔 큐에 넣자마자 갱신해서, 전송 전에 앱이 종료되면 큐는 사라지고 섀도는 "보냄"으로
        // 남아 그 변경이 **영영 재전송되지 않았다**(메모를 다시 고치기 전까지 조용히 누락).
        log.info("enqueued \(changes.upserts.count) upserts, \(changes.newTombstones.count) deletes")
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e):
            saveState(e.stateSerialization)
        case .fetchedRecordZoneChanges(let e):
            await applyFetched(modifications: e.modifications.map { $0.record },
                               deletionIDs: e.deletions.map { $0.recordID })
        case .sentRecordZoneChanges(let e):
            if !e.failedRecordSaves.isEmpty {
                log.error("failed record saves: \(e.failedRecordSaves.count)")
                if let first = e.failedRecordSaves.first {
                    MemoSyncStatus.recordError(first.error.localizedDescription)
                }
                handleFailedSaves(e.failedRecordSaves, syncEngine: syncEngine)
            }
            let sent = e.savedRecords.count + e.deletedRecordIDs.count
            if sent > 0 { MemoSyncStatus.recordPush(count: sent) }
            // 서버가 돌려준 레코드의 변경 태그를 기억해 둔다 - 다음 수정·삭제가 거절당하지 않으려면 필수.
            cacheRecordMetas(e.savedRecords)
            // 서버 저장이 확정된 것만 섀도에 반영한다.
            if !e.savedRecords.isEmpty { confirmSent(e.savedRecords) }
        case .sentDatabaseChanges(let e):
            // 존(MemosZone) 생성 실패가 여기로 온다 - Production 스키마 미배포처럼
            // "아무것도 못 올리는" 상황의 유일한 단서라 반드시 기록한다.
            if let failure = e.failedZoneSaves.first {
                log.error("failed zone save: \(failure.error.localizedDescription)")
                MemoSyncStatus.recordError(failure.error.localizedDescription)
            }
        case .didFetchRecordZoneChanges(let e):
            // 존 단위 fetch 결과 - 성공하면 이전 오류를 지워 상태 화면이 낡은 오류를 보여주지 않게 한다.
            if let error = e.error {
                log.error("fetch zone changes failed: \(error.localizedDescription)")
                MemoSyncStatus.recordError(error.localizedDescription)
            } else {
                MemoSyncStatus.clearError()
            }
        case .didFetchChanges:
            // 받을 변경이 없어도 도달한다 - "언제 마지막으로 확인했는지"의 근거.
            MemoSyncStatus.recordCheck()
        case .accountChange(let e):
            handleAccountChange(e)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                   syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        let current = syncableMemos()
        let byId = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let tombstones = loadTombstones()
        let categoryItems = CategoryItemStore.load()

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
            guard let self else { return nil }
            // 카테고리 설정은 UUID 가 아닌 고정 이름이라 메모 경로보다 먼저 가른다.
            if recordID.recordName == Self.categoryRecordName {
                return self.makeCategoryRecord()
            }
            if let categoryID = CategorySyncCore.id(fromRecordName: recordID.recordName) {
                // 옛 이름(`Memo` 종류)으로는 다시 저장하지 않는다 - 새 이름으로만 간다.
                guard !recordID.recordName.hasPrefix(CategorySyncCore.legacyRecordPrefix),
                      let item = categoryItems[categoryID] else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    return nil
                }
                return self.makeCategoryItemRecord(recordID, item: item)
            }
            guard let id = UUID(uuidString: recordID.recordName) else { return nil }
            if let memo = byId[id] {
                return self.makeRecord(id: recordID, memo: memo, deletedAt: nil)
            } else if let at = tombstones[id] {
                return self.makeRecord(id: recordID, memo: nil, deletedAt: at)
            } else {
                // 양쪽에서 사라짐 - 보낼 게 없으니 큐에서 제거.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
        }
    }

    /// 서버 저장이 확정된 레코드만 섀도에 기록한다 - 확정 전에는 계속 "보낼 것"으로 남겨 재시도되게 한다.
    private func confirmSent(_ records: [CKRecord]) {
        let current = syncableMemos()
        let byId = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var shadow = loadShadow()
        var categoryShadow = CategoryItemStore.loadShadow()
        defer { CategoryItemStore.saveShadow(categoryShadow) }
        for record in records {
            // 카테고리 설정 업로드 확정 - 지문을 기록해 같은 내용이 다시 올라가지 않게 한다.
            if record.recordID.recordName == Self.categoryRecordName {
                AppGroup.defaults?
                    .set(categoryFingerprint(currentSyncableCategories()), forKey: Self.categoryShadowKey)
                continue
            }
            // 카테고리 항목 - **보낸 레코드의 내용**으로 기록한다. 그 사이 또 바뀌었으면 다음에 다시 간다.
            if let categoryID = CategorySyncCore.id(fromRecordName: record.recordID.recordName) {
                if let payload = record["payload"] as? Data,
                   let item = try? JSONDecoder().decode(CategoryItem.self, from: payload) {
                    categoryShadow[categoryID] = CategorySyncCore.fingerprint(item)
                }
                continue
            }
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            if let memo = byId[id] {
                shadow[id] = MemoSyncCore.fingerprint(memo)
            } else {
                shadow.removeValue(forKey: id)   // 툼스톤 확정 - 살아있는 목록에 없음
            }
        }
        saveShadow(shadow)
    }

    // MARK: - Apply remote → local

    private func applyFetched(modifications: [CKRecord], deletionIDs: [CKRecord.ID]) async {
        guard !modifications.isEmpty || !deletionIDs.isEmpty else { return }
        // 서버 버전을 기억해 둔다 - 이 기기가 나중에 이 레코드를 고치거나 지울 때 필요하다.
        cacheRecordMetas(modifications)

        var remotes: [RemoteMemo] = []
        var remoteCategoryItems: [CategoryItem] = []
        for record in modifications {
            // 카테고리 설정 레코드는 메모가 아니므로 따로 처리하고 넘어간다.
            if record.recordID.recordName == Self.categoryRecordName {
                applyRemoteCategories(record)
                continue
            }
            if CategorySyncCore.id(fromRecordName: record.recordID.recordName) != nil {
                if let payload = record["payload"] as? Data,
                   let item = try? JSONDecoder().decode(CategoryItem.self, from: payload) {
                    remoteCategoryItems.append(item)
                }
                continue
            }
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            if let deletedAt = record["deletedAt"] as? Date {
                remotes.append(RemoteMemo(id: id, memo: nil, lastEdited: deletedAt))
            } else if let payload = record["payload"] as? Data,
                      let memo = try? JSONDecoder().decode(Memo.self, from: payload) {
                // 메모 본문을 적용하기 전에 첨부 이미지를 먼저 Images/에 기록(깨진 참조 방지).
                writeImages(from: record)
                remotes.append(RemoteMemo(id: id, memo: memo, lastEdited: memo.lastEdited))
            }
        }
        // 하드 삭제(존재 시) - deletedAt 정보가 없으므로 distantFuture로 처리해 삭제 우선.
        for recordID in deletionIDs {
            forgetRecordMeta(recordID)   // 서버에서 사라진 레코드의 태그는 들고 있으면 안 된다
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            remotes.append(RemoteMemo(id: id, memo: nil, lastEdited: Date()))
        }

        applyRemoteCategoryItems(remoteCategoryItems)

        let local = (try? MemoStore.shared.load(type: .memo)) ?? []
        let result = MemoSyncCore.merge(local: local, localTombstones: loadTombstones(), remote: remotes)

        isApplyingRemoteChanges = true
        // ⚠️ 저장이 보내는 .memoDataChanged 는 **메인 큐에 예약**돼 이 함수가 끝난 뒤 도착한다.
        //    여기서 곧바로 false 로 되돌리면 그 알림이 "로컬 변경"으로 오해돼 방금 받은 것을
        //    되올린다(에코). 예약된 알림이 다 지나간 뒤에 풀어 준다.
        defer { DispatchQueue.main.async { self.isApplyingRemoteChanges = false } }

        // ⚠️ 저장에 실패하면 **섀도/툼스톤을 갱신하면 안 된다.**
        //    갱신해 버리면 "이미 반영했다"고 기록되어 다음 동기화에서 이 원격 변경을
        //    다시 받아오지 않는다 → 사용자 눈에는 데이터가 조용히 사라진 것으로 보인다.
        //    실패 시엔 그대로 두어 다음 동기화가 다시 시도하게 한다.
        do {
            try MemoStore.shared.save(memos: result.memos, type: .memo)
        } catch {
            log.error("원격 병합 결과 저장 실패, 섀도 갱신을 건너뛰고 다음 동기화에서 재시도: \(error.localizedDescription, privacy: .public)")
            return
        }
        saveTombstones(result.tombstones)
        // ⚠️ 섀도는 **올릴 대상과 같은 목록**(시드 샘플 제외)으로 만들어야 한다.
        //    전체로 만들면 다음 비교에서 샘플이 "사라진 단축어"로 잡혀 엉뚱한 툼스톤이 올라간다.
        let sampleIDs = SampleMemoStorage.load()
        let syncable = sampleIDs.isEmpty ? result.memos : result.memos.filter { !sampleIDs.contains($0.id) }
        saveShadow(MemoSyncCore.buildShadow(syncable))

        // 로컬이 이긴 항목은 다시 올린다 - 편집이든 삭제든. 안 올리면 상대 기기는 제 사본을 계속 든다.
        let reuploadIDs = result.toReupload.map(\.id) + Array(result.tombstonesToReupload.keys)
        if let engine, !reuploadIDs.isEmpty {
            engine.state.add(pendingRecordZoneChanges: reuploadIDs.map { .saveRecord(recordID($0)) })
        }

        MemoSyncStatus.recordPull(count: remotes.count)
        NotificationCenter.postOnMain(name: .dataRestored)
        log.info("applied remote: \(remotes.count) records → \(result.memos.count) local memos")
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        // 로그아웃/계정 전환 시 로컬 상태는 보존(파괴하지 않음). 상태만 초기화해 재시작에 대비.
        log.info("account change: \(String(describing: event.changeType))")
    }

    // MARK: - Record materialization

    private func recordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    /// memo가 있으면 살아있는 레코드, nil이면 툼스톤(deletedAt 설정, payload 없음).
    /// 첨부 이미지(PNG)는 메모 레코드에 CKAsset 배열로 함께 올린다(메모와 원자적으로 이동).
    ///
    /// ⚠️ **반드시 서버가 준 레코드(변경 태그) 위에 얹어 올린다.** 태그 없는 새 CKRecord 로
    ///    이미 있는 레코드를 저장하면 CloudKit 이 `serverRecordChanged` 로 거절한다.
    ///    예전엔 매번 새 레코드를 만들었던 탓에 **첫 업로드만 성공하고, 그 뒤의 수정·삭제는
    ///    조용히 버려졌다**. 아이폰에서 지운 단축어가 맥에서 영영 안 사라지고,
    ///    고친 내용도 반대편에 반영되지 않았다(사용자 눈엔 "추가만 되는 동기화").
    private func makeRecord(id: CKRecord.ID, memo: Memo?, deletedAt: Date?) -> CKRecord? {
        let record = cachedRecord(for: id) ?? CKRecord(recordType: Self.recordType, recordID: id)
        if let memo, let payload = try? JSONEncoder().encode(memo) {
            record["payload"] = payload as CKRecordValue
            record["lastEdited"] = memo.lastEdited as CKRecordValue
            record["deletedAt"] = nil          // 되살린 경우 - 툼스톤 표시를 지운다
            attachImages(of: memo, to: record)
        } else if let deletedAt {
            record["deletedAt"] = deletedAt as CKRecordValue
            record["lastEdited"] = deletedAt as CKRecordValue
            // 툼스톤엔 본문·이미지를 남기지 않는다(용량 + 실수로 되살아나는 것 방지).
            record["payload"] = nil
            record["images"] = nil
            record["imageNames"] = nil
        } else {
            return nil
        }
        return record
    }

    // MARK: - 서버 레코드 메타(변경 태그) 캐시
    //
    // CloudKit 은 "내가 알고 있는 서버 버전" 위에서만 덮어쓰기를 허용한다. 그 버전을 알려면
    // 서버가 준 레코드의 **시스템 필드**(recordID·타입·변경 태그)를 보관했다가 재사용해야 한다.
    // 값 필드는 담기지 않으므로(암호화된 payload 포함) 여기 저장해도 내용이 새지 않는다.

    private static let recordMetaKey = "memo.sync.recordMeta"
    /// serverRecordChanged 재시도 횟수 - 서버와 계속 어긋날 때 무한 재전송을 막는다.
    nonisolated(unsafe) private var conflictRetries: [String: Int] = [:]
    private static let maxConflictRetries = 3

    /// 디스크(App Group)에 있는 것과 같은 내용의 메모리 사본.
    /// 배치 전송은 레코드마다 조회하므로, 매번 디스크에서 통째로 디코드하면 건수² 로 느려진다.
    nonisolated(unsafe) private var recordMetaCache: [String: Data]?

    private func loadRecordMeta() -> [String: Data] {
        if let recordMetaCache { return recordMetaCache }
        let raw: [String: Data]
        if let data = defaults?.data(forKey: Self.recordMetaKey),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            raw = decoded
        } else {
            raw = [:]
        }
        recordMetaCache = raw
        return raw
    }

    private func saveRecordMeta(_ meta: [String: Data]) {
        recordMetaCache = meta
        defaults?.set(try? JSONEncoder().encode(meta), forKey: Self.recordMetaKey)
    }

    /// 서버가 준 레코드의 시스템 필드만 저장한다.
    private func cacheRecordMeta(_ record: CKRecord) {
        cacheRecordMetas([record])
    }

    /// 여러 건을 한 번에 - 첫 동기화처럼 수백 건이 몰릴 때 건건이 전체 사전을 다시 쓰지 않도록.
    private func cacheRecordMetas(_ records: [CKRecord]) {
        guard !records.isEmpty else { return }
        var meta = loadRecordMeta()
        for record in records {
            let coder = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: coder)
            coder.finishEncoding()
            meta[record.recordID.recordName] = coder.encodedData
        }
        saveRecordMeta(meta)
    }

    private func forgetRecordMeta(_ recordID: CKRecord.ID) {
        var meta = loadRecordMeta()
        guard meta.removeValue(forKey: recordID.recordName) != nil else { return }
        saveRecordMeta(meta)
    }

    /// 캐시된 시스템 필드로 되살린 빈 레코드(값 필드는 비어 있다).
    private func cachedRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let data = loadRecordMeta()[recordID.recordName],
              let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
    }

    /// 레코드의 마지막 수정 시각. 단축어는 `lastEdited`, 카테고리 레코드(`CategorySettings` 종류)는
    /// `updatedAt` 에 둔다. ⚠️ 한쪽만 보면 다른 쪽은 늘 "아주 옛날"이 되어, 충돌 때 서버의 새 버전을
    /// 내 옛 버전으로 덮어쓴다.
    static func editedDate(of record: CKRecord) -> Date {
        (record["lastEdited"] as? Date) ?? (record["updatedAt"] as? Date) ?? .distantPast
    }

    /// 저장 실패 처리 - 특히 `serverRecordChanged` 는 **버리면 안 되는** 실패다.
    /// 서버 레코드를 받아 태그를 갱신하고, 내 변경이 더 최신일 때만 다시 올린다.
    private func handleFailedSaves(_ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave],
                                   syncEngine: CKSyncEngine) {
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []
        for failure in failures {
            let recordID = failure.record.recordID
            let name = recordID.recordName
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord else { continue }
                cacheRecordMeta(serverRecord)
                // 서버 쪽이 더 최신이면 내 변경은 접는다 - 다음 fetch 가 서버 값을 가져온다.
                let serverEdited = Self.editedDate(of: serverRecord)
                let mineEdited = Self.editedDate(of: failure.record)
                guard mineEdited >= serverEdited else {
                    conflictRetries[name] = nil
                    continue
                }
                let count = (conflictRetries[name] ?? 0) + 1
                guard count <= Self.maxConflictRetries else {
                    log.error("conflict retry limit reached: \(name, privacy: .public)")
                    conflictRetries[name] = nil
                    continue
                }
                conflictRetries[name] = count
                retry.append(.saveRecord(recordID))
            case .unknownItem:
                // 들고 있던 태그가 가리키는 레코드가 서버에 없다(존 삭제·계정 전환 등).
                // 태그를 버리고 새 레코드로 다시 올린다.
                forgetRecordMeta(recordID)
                retry.append(.saveRecord(recordID))
            default:
                break
            }
        }
        guard !retry.isEmpty else { return }
        syncEngine.state.add(pendingRecordZoneChanges: retry)
        log.info("re-queued \(retry.count) records after save conflict")
    }

    // MARK: - 기준선 확인 (이 기기의 동기화 기록이 지금 데이터베이스의 것인가)
    //
    // 이 기기는 동기화 기록을 세 가지 들고 있다: 엔진 상태(어디까지 받았나),
    // 섀도(무엇을 이미 보냈나), 레코드 메타(서버 버전 태그). 셋 다 **특정 데이터베이스**에
    // 대한 기억인데, 기기는 그 데이터베이스가 바뀐 걸 알 방법이 없었다.
    //
    // ⚠️ 실제로 있었던 일: Xcode 로 깐 개발 빌드(CloudKit Development) 위에 TestFlight 판
    //    (Production)을 덮어 깔았다. 앱 데이터는 그대로 남았고, 엔진은 Development 에서
    //    받은 위치를 들고 Production 에 붙어 **서버에 한 번도 묻지 않고** 받기를 끝냈다.
    //    섀도는 "전부 보냈음"이라 단축어도 하나도 올리지 않았다. 토글은 켜져 있고 오류도
    //    없는데 맥과 아이폰이 대놓고 다른 목록을 보여 줬다.
    //    계정을 바꾸거나 iCloud 데이터를 지워 존이 새로 생긴 경우도 같은 모양이 된다.
    //
    // → 존 안에 무작위 표식(epoch)을 하나 두고, 기기는 마지막으로 맞춘 표식을 기억한다.
    //   서버 표식이 기억과 다르면 기록을 비우고 처음부터 다시 받고 다시 올린다.
    //
    // ⚠️ 표식은 새 레코드 종류가 아니라 **기존 `Memo` 종류의 `payload`** 에 싣는다.
    //    Production 스키마에 없는 종류는 대시보드에서 배포하기 전까지 저장이 거절된다.
    //    이름이 UUID 가 아니라서 구버전을 포함한 모든 수신 경로가 메모로 읽지 않고 건너뛴다.

    /// ⚠️ 종류는 `Memo` 가 아니라 `CategorySettings` 다. 이미 나간 맥 5.1.4 의 "다시 받기"와 진단은
    ///    `Memo` 종류를 **이름을 보지 않고** 단축어로 센다. 거기에 이 레코드가 끼면 iCloud 에 단축어가
    ///    하나도 없어도 "받을 것이 있다"가 되어 맥을 비워 버릴 수 있다. `CategorySettings` 는 이미
    ///    Production 스키마에 있어(`payload`) 배포 없이 쓸 수 있고, 옛 버전은 이름이 달라 읽지 않는다.
    /// ⚠️ 이름이 `.v2` 인 까닭: 개발 빌드가 `Memo` 종류로 만든 `sync-epoch` 가 남아 있고, CloudKit 은
    ///    같은 이름의 레코드 종류를 바꿀 수 없다. 옛 것은 새로 심을 때 지운다(`legacyEpochRecordName`).
    static let epochRecordName = "sync-epoch.v2"
    static let legacyEpochRecordName = "sync-epoch"
    /// 이 기기가 마지막으로 맞춘 서버 표식.
    private static let epochKey = "memo.sync.epoch"

    private func verifyBaseline(in database: CKDatabase) async {
        let recordID = CKRecord.ID(recordName: Self.epochRecordName, zoneID: zoneID)
        let localEpoch = defaults?.string(forKey: Self.epochKey)
        do {
            let remoteEpoch: String
            if let existing = try await fetchEpoch(recordID, in: database) {
                remoteEpoch = existing
            } else {
                remoteEpoch = try await createEpoch(recordID, in: database)
            }
            guard remoteEpoch != localEpoch else { return }
            // 표식을 처음 맞추는 기기(이 확인이 들어간 첫 실행)도 여기로 온다. 멀쩡한 기기라면
            // 한 번 전부 다시 받고 다시 올리는 비용뿐이고, 어긋난 기기는 이걸로 살아난다.
            resetBaseline(reason: localEpoch == nil ? "first epoch check" : "epoch changed")
            defaults?.set(remoteEpoch, forKey: Self.epochKey)
        } catch {
            // 확인하지 못했으면 아무것도 지우지 않는다 - 네트워크가 없다고 기록을 날리면 안 된다.
            log.error("baseline check skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 서버의 표식. 없으면 nil(존이 아직 없어도 nil).
    private func fetchEpoch(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> String? {
        do {
            let record = try await database.record(for: recordID)
            guard let data = record["payload"] as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    /// 표식을 새로 심는다. 다른 기기가 먼저 심었으면 그쪽 것을 따른다.
    private func createEpoch(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> String {
        _ = try await database.save(CKRecordZone(zoneID: zoneID))   // 이미 있으면 그대로 둔다
        let epoch = UUID().uuidString
        let record = CKRecord(recordType: Self.categoryRecordType, recordID: recordID)
        record["payload"] = Data(epoch.utf8) as CKRecordValue
        do {
            _ = try await database.save(record)
            log.info("sync epoch created")
            // `Memo` 종류로 남은 옛 표식은 치운다 - 맥 5.1.4 가 단축어로 센다. 없거나 실패해도 그만이다.
            _ = try? await database.deleteRecord(
                withID: CKRecord.ID(recordName: Self.legacyEpochRecordName, zoneID: zoneID))
            return epoch
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let existing = try await fetchEpoch(recordID, in: database) else { throw error }
            return existing
        }
    }

    /// 표식을 마지막으로 맞춘 뒤 삭제를 알린 표식.
    private static let tombstonesAnnouncedKey = "memo.sync.tombstonesAnnounced"

    /// 이 기기가 아는 삭제를 **지금 데이터베이스에 표식마다 한 번** 다시 알린다.
    ///
    /// ⚠️ 툼스톤은 "섀도에는 있는데 목록에서 사라진 것"일 때만 올라간다. 기준선을 비우면
    ///    섀도가 비어 그 판정이 다시는 서지 않고, 병합도 원격 사본을 받으면 "내가 더 나중에
    ///    지웠다"며 조용히 무시할 뿐 알리지 않는다. 그래서 끊겨 있던 동안(다른 데이터베이스에
    ///    붙어 있던 동안) 아이폰에서 지운 단축어가 맥에는 영영 남아 있었다.
    ///    다른 기기가 지운 뒤에 고친 단축어라면 서버 쪽이 더 최신이라 `serverRecordChanged`
    ///    처리가 이 삭제를 접는다 - 고친 것이 지워지지는 않는다.
    private func announceTombstonesIfNeeded() {
        guard let engine,
              let epoch = defaults?.string(forKey: Self.epochKey),
              defaults?.string(forKey: Self.tombstonesAnnouncedKey) != epoch else { return }
        let aliveIDs = Set(((try? MemoStore.shared.load(type: .memo)) ?? []).map(\.id))
        let ids = loadTombstones().keys.filter { !aliveIDs.contains($0) }
        if !ids.isEmpty {
            engine.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(recordID($0)) })
        }
        // 대기열은 엔진 상태와 함께 저장되므로 보내기 전에 앱이 꺼져도 사라지지 않는다.
        defaults?.set(epoch, forKey: Self.tombstonesAnnouncedKey)
        log.info("announced \(ids.count) tombstones to this database")
    }

    /// 이 기기의 동기화 기록을 비운다. 다음 엔진은 처음부터 받고, 이 기기 단축어를 전부 다시 올린다.
    ///
    /// ⚠️ **툼스톤은 남긴다.** 이 기기에서 지운 단축어를 기억하는 유일한 기록이라,
    ///    지우면 다른 기기에 남은 사본이 받아지는 순간 되살아난다.
    private func resetBaseline(reason: String) {
        defaults?.removeObject(forKey: DefaultsKey.syncEngineState)
        defaults?.removeObject(forKey: DefaultsKey.syncShadow)
        defaults?.removeObject(forKey: Self.recordMetaKey)
        defaults?.removeObject(forKey: Self.categoryShadowKey)
        // 카테고리 항목은 남기고 "올린 것"만 비운다 - 새 데이터베이스에 전부(지운 것 포함) 다시 올라간다.
        defaults?.removeObject(forKey: CategoryItemStore.shadowKey)
        recordMetaCache = nil
        log.info("sync baseline reset: \(reason, privacy: .public)")
    }

    // MARK: - 이 기기를 정본으로 (다른 기기를 이 기기에 맞춘다)
    //
    // 평소 동기화는 id 마다 **마지막 수정 시각이 늦은 쪽**을 고른다. 그런데 시각이 꼬이면
    // (끊겨 있던 동안의 편집, 복원·다시 받기로 새로 찍힌 시각) 사람이 보기엔 틀린 쪽이 이긴다.
    // 아이폰에서 카테고리를 옮겼는데 맥 사본의 시각이 더 늦어 맥 것이 남은 일이 그랬다.
    // → 사람이 "이 기기가 정답"이라고 정하면, 서버를 이 기기와 똑같이 만든다.
    //   다른 기기는 평소처럼 받기만 하면 이 기기와 같아진다.

    struct AuthorityPlan {
        /// 서버와 내용이 달라 이 기기 것으로 다시 올릴 단축어.
        let updates: [UUID]
        /// 서버에는 살아 있는데 이 기기에는 없는 단축어 - 지운 것으로 올린다.
        let deletions: [UUID]
        /// 서버와 내용이 다른 카테고리(이 기기에서 지운 것 포함).
        var categoryUpdates: [UUID] = []
        /// 서버에는 살아 있는데 이 기기는 모르는 카테고리.
        var categoryDeletions: [CategoryItem] = []
        var isEmpty: Bool {
            updates.isEmpty && deletions.isEmpty && categoryUpdates.isEmpty && categoryDeletions.isEmpty
        }
    }

    enum AuthorityError: LocalizedError {
        case notRunning
        var errorDescription: String? {
            NSLocalizedString("기기 간 동기화가 꺼져 있거나 아직 시작되지 않았어요.",
                              comment: "Make-authoritative error: sync engine is not running")
        }
    }

    /// 서버의 단축어 레코드를 전부 받아 이 기기와 비교한다. **아무것도 바꾸지 않는다.**
    func planMakeThisDeviceAuthoritative() async throws -> AuthorityPlan {
        await startTask?.value
        guard engine != nil else { throw AuthorityError.notRunning }
        let database = await CloudKitContainer.privateDatabase(containerID)

        // 이미지는 받지 않는다 - 비교에는 본문(payload)과 삭제 표시만 있으면 된다.
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var moreComing = true
        while moreComing {
            let changes = try await database.recordZoneChanges(
                inZoneWith: zoneID, since: token, desiredKeys: ["payload", "deletedAt", "lastEdited", "updatedAt"])
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result { records.append(modification.record) }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        // 받은 김에 서버 버전 태그를 새로 기억한다 - 곧 올릴 때 충돌 없이 덮어쓰게.
        cacheRecordMetas(records)

        var remoteAlive: [UUID: Memo] = [:]
        var remoteSeen = Set<UUID>()
        var remoteCategories: [UUID: CategoryItem] = [:]
        for record in records {
            if let categoryID = CategorySyncCore.id(fromRecordName: record.recordID.recordName) {
                if let payload = record["payload"] as? Data,
                   let item = try? JSONDecoder().decode(CategoryItem.self, from: payload) {
                    remoteCategories[categoryID] = item
                }
                continue
            }
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            remoteSeen.insert(id)
            if record["deletedAt"] == nil,
               let payload = record["payload"] as? Data,
               let memo = try? JSONDecoder().decode(Memo.self, from: payload) {
                remoteAlive[id] = memo
            }
        }

        let local = syncableMemos()
        // 지울 것은 **샘플까지 포함한** 이 기기 목록으로 가른다 - 샘플은 올리지 않을 뿐 여기 있다.
        let localIDs = Set(((try? MemoStore.shared.load(type: .memo)) ?? []).map(\.id))
        let updates = local.filter { memo in
            guard let remote = remoteAlive[memo.id] else { return true }   // 없거나 지워진 것으로 있음
            return MemoSyncCore.fingerprint(remote) != MemoSyncCore.fingerprint(memo)
        }.map(\.id)
        let deletions = remoteAlive.keys.filter { !localIDs.contains($0) }

        let localCategories = refreshCategoryItems()
        let categoryUpdates = localCategories.values.filter { item in
            guard let remote = remoteCategories[item.id] else { return true }
            return !remote.hasSameContent(as: item)
        }.map(\.id)
        let categoryDeletions = remoteCategories.values.filter { !$0.isDeleted && localCategories[$0.id] == nil }

        log.info("authority plan: \(remoteSeen.count) remote, \(updates.count) updates, \(deletions.count) deletions, categories \(categoryUpdates.count)/\(categoryDeletions.count)")
        return AuthorityPlan(updates: updates, deletions: Array(deletions),
                             categoryUpdates: categoryUpdates, categoryDeletions: categoryDeletions)
    }

    /// 계획대로 올린다. 다른 단축어는 **지금 시각**으로 고쳐 올려 어느 기기에서든 이기게 하고,
    /// 이 기기에 없는 단축어는 지금 시각의 삭제로 올린다.
    func applyMakeThisDeviceAuthoritative(_ plan: AuthorityPlan) async throws {
        await startTask?.value
        guard let engine else { throw AuthorityError.notRunning }
        guard !plan.isEmpty else { return }
        let now = Date()

        if !plan.updates.isEmpty {
            let targets = Set(plan.updates)
            var memos = try MemoStore.shared.load(type: .memo)
            for index in memos.indices where targets.contains(memos[index].id) {
                memos[index].lastEdited = now
            }
            try MemoStore.shared.save(memos: memos, type: .memo)
        }
        if !plan.deletions.isEmpty {
            var tombstones = loadTombstones()
            for id in plan.deletions { tombstones[id] = now }
            saveTombstones(tombstones)
        }

        var categoryIDs: [UUID] = []
        if !plan.categoryUpdates.isEmpty || !plan.categoryDeletions.isEmpty {
            var items = CategoryItemStore.load()
            for id in plan.categoryUpdates { items[id]?.lastEdited = now }
            for remote in plan.categoryDeletions {
                var gone = remote
                gone.deletedAt = now
                gone.lastEdited = now
                items[remote.id] = gone
            }
            CategoryItemStore.save(items)
            categoryIDs = plan.categoryUpdates + plan.categoryDeletions.map(\.id)
        }

        let ids = plan.updates + plan.deletions
        engine.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(recordID($0)) }
                                                  + categoryIDs.map { .saveRecord(categoryItemRecordID($0)) })
        try await engine.sendChanges()
        log.info("authority applied: \(plan.updates.count) updates, \(plan.deletions.count) deletions, categories \(categoryIDs.count)")
    }

    // MARK: - 카테고리 항목 동기화 (카테고리 하나에 레코드 하나)
    //
    // 원본은 App Group 열쇠다. 올릴 때 열쇠를 읽어 항목을 갱신하고(`refresh`),
    // 받으면 항목을 합친 뒤 열쇠에 되쓴다(`project`). 규칙: CategorySyncCore.

    private func categoryItemRecordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: CategorySyncCore.recordName(id), zoneID: zoneID)
    }

    /// 열쇠 → 항목. 처음 옮기는 중이면 이름 기반 id 와 가장 옛날 시각을 쓴다.
    @discardableResult
    private func refreshCategoryItems() -> [UUID: CategoryItem] {
        let snapshot = CategorySnapshotStore.current()
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let sampleIDs = SampleMemoStorage.load()
        let used = Set(memos.filter { !sampleIDs.contains($0.id) }.map(\.category))
        let hidden = Set(snapshot.hiddenTabs)
        // 쓰는 카테고리이거나 사람이 보이게 둔 카테고리만 새로 만든다. 페르소나가 숨긴 채 심은
        // 빈 카테고리는 기기 언어마다 이름이 달라, 싣으면 언어별로 겹친다(`syncable` 과 같은 이유).
        let eligible: (String) -> Bool = { used.contains($0) || !hidden.contains($0) }
        let migrating = !CategoryItemStore.isMigrated
        let before = CategoryItemStore.load()
        let after = CategorySyncCore.refresh(items: before, from: snapshot, eligible: eligible,
                                             migrating: migrating, now: Date())
        if after != before { CategoryItemStore.save(after) }
        if migrating {
            CategoryItemStore.markMigrated()
            log.info("category items migrated: \(after.count)")
        }
        return after
    }

    private static let legacyCategoryCleanedKey = "category.sync.legacyRecordsCleaned"

    /// 개발 빌드가 `Memo` 종류로 올린 `category.<id>` 를 한 번 지우고, 항목을 새 이름으로 다시 올린다.
    /// ⚠️ 남겨 두면 맥 5.1.4 의 "다시 받기"가 이것을 단축어로 센다(SyncBackwardCompatibilityTests).
    ///    지우는 신호는 옛 엔진이든 새 엔진이든 이름이 UUID 가 아니라 단축어 삭제로 읽지 않고,
    ///    새 엔진은 카테고리 삭제로도 읽지 않는다(`applyFetched` 의 삭제는 UUID 만 본다).
    private func cleanUpLegacyCategoryRecords() {
        guard let engine, defaults?.bool(forKey: Self.legacyCategoryCleanedKey) != true else { return }
        let ids = Array(CategoryItemStore.load().keys)
        if !ids.isEmpty {
            engine.state.add(pendingRecordZoneChanges: ids.map {
                .deleteRecord(CKRecord.ID(recordName: CategorySyncCore.legacyRecordName($0), zoneID: zoneID))
            })
            // 새 이름으로 전부 다시 올라가게 "올린 것"을 비운다.
            defaults?.removeObject(forKey: CategoryItemStore.shadowKey)
        }
        defaults?.set(true, forKey: Self.legacyCategoryCleanedKey)
        log.info("legacy category records queued for deletion: \(ids.count)")
    }

    /// 올린 것과 다른 항목을 올린다.
    private func enqueueCategoryItemChanges() {
        guard let engine else { return }
        let items = refreshCategoryItems()
        let shadow = CategoryItemStore.loadShadow()
        let dirty = items.values.filter { shadow[$0.id] != CategorySyncCore.fingerprint($0) }.map(\.id)
        guard !dirty.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: dirty.map { .saveRecord(categoryItemRecordID($0)) })
        log.info("category items queued: \(dirty.count)")
    }

    /// ⚠️ **옛 버전과 스키마를 지키는 모양**이다. 종류는 `CategorySettings`, 필드는 그 종류에 이미 있는
    ///    `payload`(항목 전체, 삭제 표시 포함)와 `updatedAt`(수정 시각) 둘뿐이다.
    ///    - `Memo` 종류로 올리면 맥 5.1.4 의 "다시 받기"와 진단이 단축어로 센다(표식과 같은 이유).
    ///    - 새 필드(`lastEdited`, `deletedAt`)를 붙이면 Production 스키마에 없어 저장이 거절된다.
    ///    - 이름이 `category-settings` 가 아니고 UUID 도 아니라서, 모든 옛 버전이 읽지 않고 건너뛴다.
    private func makeCategoryItemRecord(_ recordID: CKRecord.ID, item: CategoryItem) -> CKRecord? {
        Self.buildCategoryItemRecord(recordID, item: item, base: cachedRecord(for: recordID))
    }

    /// 레코드 모양만 만든다(네트워크 없음) - 시험이 옛 버전과의 약속을 확인하는 자리.
    static func buildCategoryItemRecord(_ recordID: CKRecord.ID, item: CategoryItem, base: CKRecord?) -> CKRecord? {
        guard let payload = try? JSONEncoder().encode(item) else { return nil }
        let record = base ?? CKRecord(recordType: categoryRecordType, recordID: recordID)
        record["payload"] = payload as CKRecordValue
        record["updatedAt"] = item.lastEdited as CKRecordValue
        return record
    }

    /// 받은 항목을 합치고 열쇠에 되쓴다.
    private func applyRemoteCategoryItems(_ remote: [CategoryItem]) {
        guard !remote.isEmpty else { return }
        // 이 기기에서 방금 바꾼 것을 먼저 항목에 담는다 - 안 그러면 되쓰기가 그 편집을 덮는다.
        let before = refreshCategoryItems()
        let merged = CategorySyncCore.merge(local: before, remote: remote)
        let deduped = CategorySyncCore.dedupe(merged.items, now: Date())
        CategoryItemStore.save(deduped.items)

        // 받은 그대로 남은 항목은 "올린 것"으로 기록한다 - 받자마자 되올리지 않게.
        var shadow = CategoryItemStore.loadShadow()
        for item in remote where deduped.items[item.id] == item {
            shadow[item.id] = CategorySyncCore.fingerprint(item)
        }
        CategoryItemStore.saveShadow(shadow)

        CategorySnapshotStore.writeItemFields(
            CategorySyncCore.project(deduped.items, onto: CategorySnapshotStore.current(),
                                     formerNames: Set(before.values.map(\.name))))

        let reupload = merged.toReupload.union(deduped.changed)
        if let engine, !reupload.isEmpty {
            engine.state.add(pendingRecordZoneChanges: reupload.map { .saveRecord(categoryItemRecordID($0)) })
        }
        log.info("category items applied: \(remote.count) remote, \(reupload.count) re-queued")
    }

    // MARK: - 카테고리 설정 동기화
    //
    // 메모 레코드는 id(UUID)당 하나지만, 카테고리 설정은 **기기당 하나**의 단일 레코드로
    // 같은 존에 올린다. 목록·아이콘·순서·숨김이 메모와 함께 기기 간에 따라다니게 하기 위함이다.
    // (예전엔 App Group UserDefaults 에만 있어 새 기기에서 탭이 통째로 사라졌다.)

    static let categoryRecordType = "CategorySettings"
    static let categoryRecordName = "category-settings"
    /// 마지막으로 올린 스냅샷 지문 - 안 바뀌었으면 다시 올리지 않는다(불필요한 쓰기 방지).
    private static let categoryShadowKey = "memo.sync.categoryShadow"

    /// 동기화에 실을 카테고리 - 실제 쓰이는 것만(페르소나 시드·언어별 중복 방지).
    private func currentSyncableCategories() -> CategorySnapshot {
        CategorySnapshotStore.syncable(memos: (try? MemoStore.shared.load(type: .memo)) ?? [],
                                       sampleIDs: SampleMemoStorage.load())
    }

    private var categoryRecordID: CKRecord.ID {
        CKRecord.ID(recordName: Self.categoryRecordName, zoneID: zoneID)
    }

    private func categoryFingerprint(_ snapshot: CategorySnapshot) -> String {
        // updatedAt 은 매번 달라지므로 지문에서 뺀다 - 넣으면 내용이 같아도 계속 올라간다.
        var stable = snapshot
        stable.updatedAt = .distantPast
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // 딕셔너리 키 순서까지 결정적으로
        let data = (try? encoder.encode(stable)) ?? Data()
        // ⚠️ `hashValue` 를 쓰면 안 된다 - Swift 의 Hasher 는 프로세스마다 시드가 달라
        //    실행할 때마다 값이 바뀌고, 그러면 내용이 그대로여도 매 실행 재업로드된다.
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 로컬 카테고리 설정이 바뀌었으면 업로드 큐에 올린다.
    private func enqueueCategorySettingsIfChanged() {
        guard let engine else { return }
        let snapshot = currentSyncableCategories()
        guard !snapshot.isEmpty else { return }

        let fingerprint = categoryFingerprint(snapshot)
        let defaults = AppGroup.defaults
        guard defaults?.string(forKey: Self.categoryShadowKey) != fingerprint else { return }

        engine.state.add(pendingRecordZoneChanges: [.saveRecord(categoryRecordID)])
        log.info("category settings queued for upload")
    }

    /// 업로드용 레코드. `nextRecordZoneChangeBatch` 에서 이 recordID 를 만나면 여기로 온다.
    private func makeCategoryRecord() -> CKRecord? {
        var snapshot = currentSyncableCategories()
        guard !snapshot.isEmpty else { return nil }

        // 메모 레코드와 같은 이유로 서버 버전 위에 얹는다(태그 없이 올리면 두 번째부터 거절당한다).
        let record = cachedRecord(for: categoryRecordID)
            ?? CKRecord(recordType: Self.categoryRecordType, recordID: categoryRecordID)

        // ⚠️ 올리는 것은 **교체**다. 이 기기 목록만 올리면 공용 레코드가 그만큼 깎인다.
        //    원격에 이미 있던 것을 지우지 않도록 얹는다(카테고리를 새로 만들지는 않는다).
        //    자세한 이유: CategorySnapshotStore.union
        if let remotePayload = record["payload"] as? Data,
           let remote = try? JSONDecoder().decode(CategorySnapshot.self, from: remotePayload) {
            snapshot = CategorySnapshotStore.union(local: snapshot, remote: remote)
        }

        snapshot.updatedAt = Date()
        guard let payload = try? JSONEncoder().encode(snapshot) else { return nil }
        record["payload"] = payload as CKRecordValue
        record["updatedAt"] = snapshot.updatedAt as CKRecordValue
        return record
    }

    /// 원격 카테고리 설정을 로컬에 반영한다.
    /// ⚠️ 병합(merge) 전략을 쓴다 - 이 기기에만 있는 카테고리를 원격이 지우면 안 된다.
    ///    다른 기기에서 지운 카테고리는 여기서 되살아날 수 있지만, **지워지는 것보다
    ///    남는 쪽이 안전하다**(이름만 남을 뿐 메모는 그대로다).
    private func applyRemoteCategories(_ record: CKRecord) {
        guard let payload = record["payload"] as? Data,
              let snapshot = try? JSONDecoder().decode(CategorySnapshot.self, from: payload) else { return }

        if CategoryItemStore.isMigrated {
            // 목록·아이콘·색·숨김은 이제 **카테고리 항목**이 옮긴다. 이 덩어리는 옛 버전이 더하기만 하며
            // 올리는 것이라, 여기서 목록을 받으면 지운 카테고리가 되살아난다.
            // → 화면 구성(기본 제공·즐겨찾기 숨김·기능 켬)만 받고, 항목이 **한 번도 본 적 없는** 이름만
            //   받아들인다(아직 업데이트하지 않은 기기가 새로 만든 카테고리).
            let known = Set(CategoryItemStore.load().values.map(\.name))
            var unseen = CategorySnapshot()
            unseen.categories = snapshot.categories.filter { !known.contains($0) }
            unseen.icons = snapshot.icons.filter { unseen.categories.contains($0.key) }
            unseen.colors = snapshot.colors.filter { unseen.categories.contains($0.key) }
            if !unseen.categories.isEmpty { CategorySnapshotStore.apply(unseen, strategy: .merge) }
            CategorySnapshotStore.applyLayout(snapshot)
        } else {
            // 동기화는 `.sync` - 목록·아이콘·색은 더하고, 숨김·기본 제공은 그대로 비춘다.
            // (`.merge` 로 두면 끈 것·되살린 것이 다른 기기로 영영 안 넘어간다)
            CategorySnapshotStore.apply(snapshot, strategy: .sync)
        }
        // 방금 받은 상태를 그대로 섀도에 기록 - 받자마자 되올리는 핑퐁을 막는다.
        AppGroup.defaults?
            .set(categoryFingerprint(currentSyncableCategories()), forKey: Self.categoryShadowKey)
        log.info("remote category settings applied")
    }

    // MARK: - Images (App Group Images/ ↔ CKAsset)

    private var imagesDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 메모가 참조하는 이미지 파일들을 CKAsset 배열로 첨부(존재하는 파일만).
    private func attachImages(of memo: Memo, to record: CKRecord) {
        var names = memo.imageFileNames
        if let single = memo.imageFileName, !single.isEmpty, !names.contains(single) { names.append(single) }
        guard !names.isEmpty, let dir = imagesDir else { return }
        var assets: [CKAsset] = []
        var attached: [String] = []
        for name in names {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                assets.append(CKAsset(fileURL: url))
                attached.append(name)
            }
        }
        if !assets.isEmpty {
            record["images"] = assets as CKRecordValue
            record["imageNames"] = attached as CKRecordValue
        }
    }

    /// 수신 레코드의 CKAsset들을 App Group Images/에 기록(아직 없는 파일만).
    private func writeImages(from record: CKRecord) {
        guard let assets = record["images"] as? [CKAsset],
              let names = record["imageNames"] as? [String],
              let dir = imagesDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (asset, name) in zip(assets, names) {
            guard let src = asset.fileURL else { continue }
            let dest = dir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: src, to: dest)
            }
        }
    }

    // MARK: - Persistence (App Group)

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = defaults?.data(forKey: DefaultsKey.syncEngineState) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }
    private func saveState(_ state: CKSyncEngine.State.Serialization) {
        defaults?.set(try? JSONEncoder().encode(state), forKey: DefaultsKey.syncEngineState)
    }

    private func loadShadow() -> [UUID: String] {
        guard let data = defaults?.data(forKey: DefaultsKey.syncShadow),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }
    private func saveShadow(_ shadow: [UUID: String]) {
        let raw = Dictionary(uniqueKeysWithValues: shadow.map { ($0.key.uuidString, $0.value) })
        defaults?.set(try? JSONEncoder().encode(raw), forKey: DefaultsKey.syncShadow)
    }

    private func loadTombstones() -> [UUID: Date] {
        guard let data = defaults?.data(forKey: DefaultsKey.syncTombstones),
              let raw = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }
    private func saveTombstones(_ tombstones: [UUID: Date]) {
        let raw = Dictionary(uniqueKeysWithValues: tombstones.map { ($0.key.uuidString, $0.value) })
        defaults?.set(try? JSONEncoder().encode(raw), forKey: DefaultsKey.syncTombstones)
    }
}
