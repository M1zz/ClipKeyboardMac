//
//  MemoSyncEngine.swift
//  ClipKeyboard
//
//  메모 실시간 동기화(iPhone ↔ Mac) — CKSyncEngine 기반 레코드 단위 동기화.
//  로컬 JSON 저장소(MemoStore)는 그대로 두고, 그 위에서 CloudKit 프라이빗 DB의
//  커스텀 존을 동기화한다. 충돌은 id 단위 최신 우선 + 툼스톤(소프트 삭제)으로 해결.
//  순수 로직은 MemoSyncCore(단위 테스트 완비), 여기서는 CloudKit 연결만 담당한다.
//  iOS·macOS(.tap) 두 타겟이 공유한다(AppGroup.swift 패턴).
//
//  ⚠️ 기본 비활성(MemoSyncFlags.enabled = false). Pro + 플래그 ON일 때만 start().
//

import Foundation
import CloudKit
import os

enum MemoSyncFlags {
    /// 마스터 스위치. 실기기 2대(iCloud)에서 검증 전까지 OFF로 출시 안전성 확보.
    /// App Group(기기별) 또는 iCloud KV(기기 간 동기)에 켜져 있으면 활성 —
    /// 한 기기에서 켜면 KV를 통해 다른 기기에도 전파된다(Pro 상태와 동일 방식).
    static var enabled: Bool {
        if UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: DefaultsKey.memoSyncEnabled) == true { return true }
        return NSUbiquitousKeyValueStore.default.bool(forKey: DefaultsKey.memoSyncEnabled)
    }

    /// 토글 시 양쪽(App Group + iCloud KV)에 기록 — 다른 기기로 전파.
    static func setEnabled(_ on: Bool) {
        UserDefaults(suiteName: AppGroup.identifier)?.set(on, forKey: DefaultsKey.memoSyncEnabled)
        NSUbiquitousKeyValueStore.default.set(on, forKey: DefaultsKey.memoSyncEnabled)
        NSUbiquitousKeyValueStore.default.synchronize()
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
    /// 원격 변경을 로컬에 적용하는 동안 true — 이 사이의 .memoDataChanged는 무시(에코 루프 차단).
    nonisolated(unsafe) private var isApplyingRemoteChanges = false

    private var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    // MARK: - Lifecycle

    /// Pro + 플래그가 켜져 있을 때만 동기화를 시작한다. 멱등.
    func startIfEnabled() {
        guard MemoSyncFlags.enabled else { log.info("sync disabled by flag"); return }
        guard isProUser else { log.info("sync gated: not Pro"); return }
        guard !started else { return }
        started = true

        let config = CKSyncEngine.Configuration(
            database: CKContainer(identifier: containerID).privateCloudDatabase,
            stateSerialization: loadState(),
            delegate: self
        )
        let engine = CKSyncEngine(config)
        self.engine = engine
        // 존 생성(이미 있으면 무시됨) — CKSyncEngine이 처리.
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])

        NotificationCenter.default.addObserver(
            self, selector: #selector(localDataChanged),
            name: .memoDataChanged, object: nil)

        log.info("MemoSyncEngine started")
        // 시작 시 한 번: 로컬 미동기 변경을 큐에 올리고, 원격을 당겨온다.
        enqueueLocalChanges()
        Task { try? await engine.fetchChanges() }
    }

    /// Pro 여부 — ProFeatureManager의 키를 직접 읽어 양 타겟(맥은 자체 매니저) 의존을 피한다.
    private var isProUser: Bool {
        // App Group + iCloud KV 어느 쪽이든 Pro면 Pro로 간주(기존 백업 게이팅과 동일 취지).
        if defaults?.bool(forKey: DefaultsKey.proStatus) == true { return true }
        if NSUbiquitousKeyValueStore.default.bool(forKey: DefaultsKey.proStatus) { return true }
        return false
    }

    /// 외부(포그라운드/푸시)에서 즉시 동기화를 요청.
    func syncNow() {
        guard let engine else { return }
        enqueueLocalChanges()
        Task {
            try? await engine.fetchChanges()
            try? await engine.sendChanges()
        }
    }

    // MARK: - Local change detection (push)

    @objc private func localDataChanged() {
        guard !isApplyingRemoteChanges else { return }
        enqueueLocalChanges()
    }

    private func enqueueLocalChanges() {
        guard let engine else { return }
        let current = (try? MemoStore.shared.load(type: .memo)) ?? []
        let changes = MemoSyncCore.localChanges(
            current: current, shadow: loadShadow(),
            knownTombstones: loadTombstones(), now: Date())
        guard !changes.isEmpty else { return }

        var tombstones = loadTombstones()
        for (id, at) in changes.newTombstones { tombstones[id] = at }
        saveTombstones(tombstones)

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for memo in changes.upserts { pending.append(.saveRecord(recordID(memo.id))) }
        for id in changes.newTombstones.keys { pending.append(.saveRecord(recordID(id))) }
        engine.state.add(pendingRecordZoneChanges: pending)

        // 섀도를 현재 살아있는 상태로 갱신(전송 확정 전이라도, 지문이 안 바뀌면 재전송 안 됨).
        saveShadow(MemoSyncCore.buildShadow(current))
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
            }
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
        let current = (try? MemoStore.shared.load(type: .memo)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let tombstones = loadTombstones()

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
            guard let self, let id = UUID(uuidString: recordID.recordName) else { return nil }
            if let memo = byId[id] {
                return self.makeRecord(id: recordID, memo: memo, deletedAt: nil)
            } else if let at = tombstones[id] {
                return self.makeRecord(id: recordID, memo: nil, deletedAt: at)
            } else {
                // 양쪽에서 사라짐 — 보낼 게 없으니 큐에서 제거.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
        }
    }

    // MARK: - Apply remote → local

    private func applyFetched(modifications: [CKRecord], deletionIDs: [CKRecord.ID]) async {
        guard !modifications.isEmpty || !deletionIDs.isEmpty else { return }
        var remotes: [RemoteMemo] = []
        for record in modifications {
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
        // 하드 삭제(존재 시) — deletedAt 정보가 없으므로 distantFuture로 처리해 삭제 우선.
        for id in deletionIDs.compactMap({ UUID(uuidString: $0.recordName) }) {
            remotes.append(RemoteMemo(id: id, memo: nil, lastEdited: Date()))
        }

        let local = (try? MemoStore.shared.load(type: .memo)) ?? []
        let result = MemoSyncCore.merge(local: local, localTombstones: loadTombstones(), remote: remotes)

        isApplyingRemoteChanges = true
        defer { isApplyingRemoteChanges = false }

        try? MemoStore.shared.save(memos: result.memos, type: .memo)
        saveTombstones(result.tombstones)
        saveShadow(MemoSyncCore.buildShadow(result.memos))

        // 로컬이 이긴 항목(원격 삭제를 로컬 최신편집이 덮음)은 다시 올린다.
        if let engine, !result.toReupload.isEmpty {
            engine.state.add(pendingRecordZoneChanges: result.toReupload.map { .saveRecord(recordID($0.id)) })
        }

        await MainActor.run { NotificationCenter.default.post(name: .dataRestored, object: nil) }
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
    private func makeRecord(id: CKRecord.ID, memo: Memo?, deletedAt: Date?) -> CKRecord? {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        if let memo, let payload = try? JSONEncoder().encode(memo) {
            record["payload"] = payload as CKRecordValue
            record["lastEdited"] = memo.lastEdited as CKRecordValue
            attachImages(of: memo, to: record)
        } else if let deletedAt {
            record["deletedAt"] = deletedAt as CKRecordValue
            record["lastEdited"] = deletedAt as CKRecordValue
        } else {
            return nil
        }
        return record
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
