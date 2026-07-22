//
//  MemoSyncCore.swift
//  ClipKeyboard
//
//  메모 CloudKit 동기화의 순수(네트워크 없는) 로직.
//  - 로컬 변경 감지(섀도 diff)
//  - 원격 변경 병합(id 단위 최신 우선 + 툼스톤 소프트 삭제)
//  네트워크/CloudKit 타입에 의존하지 않아 단위 테스트로 전수 검증한다.
//  iOS·macOS(.tap) 두 타겟이 공유한다(AppGroup.swift 패턴).
//

import Foundation
import CryptoKit

/// 원격(CloudKit `Memo` 레코드)에서 디코드한 한 항목의 동기화 표현.
/// 살아있는 메모면 `memo`가 있고, 삭제(툼스톤)면 `memo == nil` + `lastEdited == deletedAt`.
struct RemoteMemo {
    let id: UUID
    let memo: Memo?
    /// 살아있으면 memo.lastEdited, 툼스톤이면 deletedAt.
    let lastEdited: Date
    var isTombstone: Bool { memo == nil }
}

enum MemoSyncCore {

    // MARK: - Fingerprint

    /// 동기화 지문 — 순수 사용량 필드(clipCount/lastUsedAt)는 제외하고 결정적으로 인코딩해
    /// 해시한다. 같은 내용이면 항상 같은 값 → 복사할 때마다 불필요하게 재전송하지 않는다.
    static func fingerprint(_ memo: Memo) -> String {
        var normalized = memo
        normalized.clipCount = 0
        normalized.lastUsedAt = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // 딕셔너리 키 순서까지 결정적
        let data = (try? encoder.encode(normalized)) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 메모 목록으로 [id: 지문] 섀도를 만든다.
    static func buildShadow(_ memos: [Memo]) -> [UUID: String] {
        var shadow: [UUID: String] = [:]
        for memo in memos { shadow[memo.id] = fingerprint(memo) }
        return shadow
    }

    // MARK: - Conflict order

    /// 최신 우선 비교 — lastEdited가 크면 우선, 동률이면 id 사전순으로 결정(결정성 보장).
    static func isNewer(_ lhs: Date, idLhs: UUID, than rhs: Date, idRhs: UUID) -> Bool {
        if lhs != rhs { return lhs > rhs }
        return idLhs.uuidString > idRhs.uuidString
    }

    // MARK: - Local change detection (push)

    struct LocalChanges: Equatable {
        var upserts: [Memo] = []
        /// 새로 삭제된 (id, 삭제시각).
        var newTombstones: [UUID: Date] = [:]
        var isEmpty: Bool { upserts.isEmpty && newTombstones.isEmpty }

        static func == (l: LocalChanges, r: LocalChanges) -> Bool {
            let lIds: [UUID] = l.upserts.map { $0.id }
            let rIds: [UUID] = r.upserts.map { $0.id }
            return lIds == rIds && l.newTombstones == r.newTombstones
        }
    }

    /// 현재 메모 vs 직전 동기 섀도를 비교해 올려보낼 변경을 산출한다.
    /// - shadow: 직전에 동기화된 살아있는 메모들의 [id: 지문].
    /// - knownTombstones: 이미 삭제로 처리된 id들(중복 툼스톤 방지).
    /// - now: 새 삭제의 deletedAt(테스트 결정성을 위해 주입).
    static func localChanges(current: [Memo],
                             shadow: [UUID: String],
                             knownTombstones: [UUID: Date],
                             now: Date) -> LocalChanges {
        var changes = LocalChanges()
        let currentIds = Set(current.map(\.id))

        for memo in current where shadow[memo.id] != fingerprint(memo) {
            changes.upserts.append(memo)
        }
        // 섀도엔 있었는데 현재 목록에서 사라졌고, 아직 툼스톤이 아닌 id → 새 삭제.
        for id in shadow.keys where !currentIds.contains(id) && knownTombstones[id] == nil {
            changes.newTombstones[id] = now
        }
        return changes
    }

    // MARK: - Remote merge (pull)

    struct MergeResult: Equatable {
        var memos: [Memo]
        var tombstones: [UUID: Date]
        /// 로컬이 이겨서 원격에 다시 올려야 하는 메모(원격 삭제를 로컬 최신 편집이 덮은 경우).
        var toReupload: [Memo]

        static func == (l: MergeResult, r: MergeResult) -> Bool {
            let lIds: [String] = l.memos.map { $0.id.uuidString }.sorted()
            let rIds: [String] = r.memos.map { $0.id.uuidString }.sorted()
            let lReupload: [UUID] = l.toReupload.map { $0.id }
            let rReupload: [UUID] = r.toReupload.map { $0.id }
            return lIds == rIds && l.tombstones == r.tombstones && lReupload == rReupload
        }
    }

    /// 원격 변경을 로컬 상태에 병합한다(최신 우선 + 툼스톤).
    /// - local: 현재 로컬 메모.
    /// - localTombstones: 로컬이 알고 있는 삭제 [id: deletedAt].
    /// - remote: 원격에서 받은 레코드들(살아있는 메모/툼스톤 혼재).
    static func merge(local: [Memo],
                      localTombstones: [UUID: Date],
                      remote: [RemoteMemo]) -> MergeResult {
        var alive: [UUID: Memo] = [:]
        for memo in local { alive[memo.id] = memo }
        var tombstones = localTombstones
        var toReupload: [Memo] = []

        for r in remote {
            let localMemo = alive[r.id]
            let localTomb = tombstones[r.id]

            if r.isTombstone {
                // 원격 삭제. 로컬 살아있는 메모가 더 최신이면 로컬 편집이 이김(되살림 + 재업로드).
                if let lm = localMemo,
                   isNewer(lm.lastEdited, idLhs: lm.id, than: r.lastEdited, idRhs: r.id) {
                    toReupload.append(lm)               // 로컬 alive 유지
                } else {
                    alive.removeValue(forKey: r.id)     // 삭제 반영
                    tombstones[r.id] = max(localTomb ?? .distantPast, r.lastEdited)
                }
            } else if let rm = r.memo {
                // 원격 살아있는 메모.
                if let lt = localTomb, lt >= r.lastEdited {
                    // 로컬 삭제가 더(또는 같게) 최신 → 삭제 유지(원격 메모 무시).
                    continue
                }
                if let lm = localMemo {
                    if isNewer(rm.lastEdited, idLhs: rm.id, than: lm.lastEdited, idRhs: lm.id) {
                        alive[r.id] = rm
                    }
                    // else 로컬이 더 최신 → 유지(다음 push에서 올라감).
                } else {
                    alive[r.id] = rm                    // 신규 또는 되살림
                    tombstones.removeValue(forKey: r.id)
                }
            }
        }

        return MergeResult(memos: Array(alive.values), tombstones: tombstones, toReupload: toReupload)
    }
}
