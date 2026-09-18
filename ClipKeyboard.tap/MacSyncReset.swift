//
//  MacSyncReset.swift
//  ClipKeyboard.tap
//
//  "이 맥 것을 지우고 iCloud(아이폰)에서 통째로 다시 받기".
//
//  동기화가 한쪽으로 기울어 서로 다른 것을 보고 있을 때, 맥을 버리고 아이폰을 정본으로
//  삼는 길이다. 낱개로 합치려 들지 않고 이 맥의 기억을 통째로 버린 뒤 처음부터 받아온다.
//
//  ⚠️ 되돌릴 수 없는 일이라 지키는 것이 셋 있다.
//     1. **iCloud 에 받아올 것이 있는지 먼저 센다.** 비어 있으면 아무것도 지우지 않는다.
//        (지우고 나서 받을 것이 없으면 그냥 데이터가 사라진 것이다)
//     2. 지우기 전에 **지금 데이터를 파일로 한 벌** 앱 폴더에 떨어뜨리고 그 경로를 알려 준다.
//     3. 실제로 지우는 것은 이 맥의 사본과 동기화 기억뿐이다. **iCloud 는 건드리지 않는다.**
//        (여기서 지운 것을 올려 아이폰까지 비우면 그거야말로 사고다 - 그래서 지운 표식을
//         남기지 않고, 엔진 기억도 통째로 버려 "이 맥은 새 기기" 상태로 만든다)
//

import AppKit
import CloudKit
import Foundation

@MainActor
enum MacSyncReset {
    struct Plan {
        /// iCloud 에 있는 살아 있는 단축어 수.
        let cloudCount: Int
        /// 지금 이 맥에 있는 단축어 수.
        let localCount: Int
    }

    struct Result {
        let cloudCount: Int
        /// 지우기 전에 떨어뜨린 안전 사본의 경로.
        let safetyCopy: URL?
    }

    enum Failure: LocalizedError {
        case cloudEmpty
        case cloudUnreadable(String)
        case wipeFailed(String)

        var errorDescription: String? {
            switch self {
            case .cloudEmpty:
                return NSLocalizedString("iCloud 에 받아올 단축어가 없습니다. 이 맥의 데이터를 지우지 않았습니다.",
                                         comment: "Reset: cloud empty")
            case .cloudUnreadable(let message):
                return String(format: NSLocalizedString("iCloud 를 읽지 못했습니다: %@", comment: "Reset: cloud unreadable"), message)
            case .wipeFailed(let message):
                return String(format: NSLocalizedString("이 맥의 데이터를 지우지 못했습니다: %@", comment: "Reset: wipe failed"), message)
            }
        }
    }

    private static let containerID = "iCloud.com.Ysoup.TokenMemo"

    /// 무엇을 받아오게 되는지 먼저 세어 본다. 사람에게 확인받기 전에 부른다.
    static func plan() async throws -> Plan {
        let database = await CloudKitContainer.privateDatabase(containerID)
        let zoneID = CKRecordZone.ID(zoneName: MemoSyncEngine.zoneName, ownerName: CKCurrentUserDefaultName)

        var alive = 0
        do {
            var token: CKServerChangeToken?
            var more = true
            while more {
                let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
                for change in result.modificationResultsByID.values {
                    guard let record = try? change.get().record,
                          record.recordType == MemoSyncEngine.recordType,
                          record["deletedAt"] == nil else { continue }
                    alive += 1
                }
                token = result.changeToken
                more = result.moreComing
            }
        } catch {
            throw Failure.cloudUnreadable(error.localizedDescription)
        }

        let local = ((try? MemoStore.shared.load(type: .memo)) ?? []).count
        return Plan(cloudCount: alive, localCount: local)
    }

    /// 사람이 확인한 뒤에 부른다. `plan()` 을 다시 세어 비어 있으면 아무것도 하지 않는다.
    static func wipeAndPull() async throws -> Result {
        let plan = try await plan()
        guard plan.cloudCount > 0 else { throw Failure.cloudEmpty }

        // 1) 안전 사본 - 지우기 전에 반드시 남긴다.
        let safety = writeSafetyCopy()

        // 2) 이 맥의 단축어를 비운다. **지운 표식(툼스톤)은 남기지 않는다** -
        //    남기면 그 표식이 iCloud 로 올라가 아이폰의 단축어까지 지운다.
        do {
            try MemoStore.shared.save(memos: [], type: .memo)
        } catch {
            throw Failure.wipeFailed(error.localizedDescription)
        }

        // 3) 동기화 기억을 통째로 버린다 - 이 맥을 "한 번도 받아본 적 없는 기기" 로 되돌린다.
        if let defaults = AppGroup.defaults {
            for key in [DefaultsKey.syncEngineState, DefaultsKey.syncShadow, DefaultsKey.syncTombstones,
                        "memo.sync.recordMeta"] {
                defaults.removeObject(forKey: key)
            }
        }
        // 예시 단축어 표식도 지운다 - 맥이 심은 예시는 방금 함께 지워졌다.
        SampleMemoStorage.save(ids: [])

        // 4) 엔진은 이미 돌고 있고 옛 기억을 메모리에 들고 있다. 앱을 다시 켜야 새 기억으로
        //    처음부터 받아온다.
        //    ⚠️ 엔진에 restart 를 넣지 않는다. `Shared/MemoSyncEngine.swift` 는 아이폰 원본과
        //       **바이트 단위로 같아야** 하고(scripts/check_shared_drift.sh 가 배포를 막는다),
        //       맥에서만 고치면 다음 동기화 때 조용히 덮어써진다.
        NotificationCenter.default.post(name: .dataRestored, object: nil)

        return Result(cloudCount: plan.cloudCount, safetyCopy: safety)
    }

    /// 앱을 새로 띄우고 지금 것을 끈다. 지운 뒤 엔진을 새 기억으로 세우는 유일한 길이다.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error { print("⚠️ [MacSyncReset] 다시 켜기 실패: \(error.localizedDescription)") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }

    /// 지금 데이터를 앱 폴더에 파일로 떨어뜨린다. 실패해도 진행을 막지는 않되 경로는 nil 이 된다.
    private static func writeSafetyCopy() -> URL? {
        guard let data = try? DataPortability.makeBundleData() else { return nil }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let folder else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = folder.appendingPathComponent("ClipKeyboard-\(formatter.string(from: Date()))-before-reset.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        } catch {
            print("⚠️ [MacSyncReset] 안전 사본 저장 실패: \(error)")
            return nil
        }
    }
}
