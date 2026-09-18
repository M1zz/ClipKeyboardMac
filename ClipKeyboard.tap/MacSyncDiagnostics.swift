//
//  MacSyncDiagnostics.swift
//  ClipKeyboard.tap
//
//  "iCloud 에 실제로 무엇이 들어 있는가" 를 앱이 직접 보고 말해 주는 진단.
//
//  왜 필요했나: 아이폰과 맥이 서로 상대가 올린 것을 못 보는 일이 있었다. 로그로는
//  맥이 계속 묻고 있고 오류도 없는데 받아오는 것이 없다는 것까지만 알 수 있어,
//  **창고가 빈 것인지, 맥이 "이미 다 올렸다"고 잘못 기억하는 것인지** 가릴 수 없었다.
//  이 진단은 동기화 엔진의 기억을 거치지 않고 저장 구역을 통째로 읽어 세어 본다.
//

import CloudKit
import Foundation

@MainActor
enum MacSyncDiagnostics {
    private static let containerID = "iCloud.com.Ysoup.TokenMemo"

    /// 사람에게 그대로 보여 줄 여러 줄짜리 결과.
    static func inspect() async -> String {
        var lines: [String] = []

        let container = await CloudKitContainer.resolve(containerID)
        let database = await CloudKitContainer.privateDatabase(containerID)

        // 1) 계정
        do {
            let status = try await container.accountStatus()
            lines.append(String(format: NSLocalizedString("iCloud 계정: %@", comment: "Diagnostics: account status"),
                                describe(status)))
        } catch {
            lines.append(String(format: NSLocalizedString("iCloud 계정 확인 실패: %@", comment: "Diagnostics: account check failed"),
                                error.localizedDescription))
        }

        // 2) 저장 구역
        let zoneID = CKRecordZone.ID(zoneName: MemoSyncEngine.zoneName, ownerName: CKCurrentUserDefaultName)
        do {
            let zones = try await database.allRecordZones()
            let names = zones.map(\.zoneID.zoneName).sorted().joined(separator: ", ")
            lines.append(String(format: NSLocalizedString("저장 구역: %@", comment: "Diagnostics: zones"),
                                names.isEmpty ? "-" : names))
            guard zones.contains(where: { $0.zoneID.zoneName == MemoSyncEngine.zoneName }) else {
                lines.append(NSLocalizedString("동기화 구역이 아직 없습니다. 아무 기기도 올린 적이 없다는 뜻입니다.",
                                               comment: "Diagnostics: zone missing"))
                return lines.joined(separator: "\n")
            }
        } catch {
            lines.append(String(format: NSLocalizedString("저장 구역 확인 실패: %@", comment: "Diagnostics: zone check failed"),
                                error.localizedDescription))
            return lines.joined(separator: "\n")
        }

        // 3) 구역 안의 레코드 - 엔진의 기억(변경 표식)을 쓰지 않고 처음부터 통째로 읽는다.
        do {
            var memoCount = 0
            var tombstoneCount = 0
            var hasCategories = false
            var newest: Date?
            var token: CKServerChangeToken?
            var more = true

            while more {
                let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
                for change in result.modificationResultsByID.values {
                    guard let record = try? change.get().record else { continue }
                    switch record.recordType {
                    case MemoSyncEngine.recordType:
                        if record["deletedAt"] != nil { tombstoneCount += 1 } else { memoCount += 1 }
                    case MemoSyncEngine.categoryRecordType:
                        hasCategories = true
                    default:
                        break
                    }
                    if let modified = record.modificationDate, modified > (newest ?? .distantPast) {
                        newest = modified
                    }
                }
                token = result.changeToken
                more = result.moreComing
            }

            lines.append(String(format: NSLocalizedString("iCloud 안의 단축어: %1$d개 (지운 표식 %2$d개)", comment: "Diagnostics: record counts"),
                                memoCount, tombstoneCount))
            lines.append(hasCategories
                         ? NSLocalizedString("카테고리 설정: 있음", comment: "Diagnostics: category record present")
                         : NSLocalizedString("카테고리 설정: 없음", comment: "Diagnostics: category record missing"))
            if let newest {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                lines.append(String(format: NSLocalizedString("가장 최근에 올라온 것: %@", comment: "Diagnostics: newest record"),
                                    formatter.string(from: newest)))
            }

            // 4) 이 맥이 가진 것과 견줘 본다 - 어느 쪽이 안 올리고 있는지가 여기서 갈린다.
            let local = ((try? MemoStore.shared.load(type: .memo)) ?? []).count
            lines.append(String(format: NSLocalizedString("이 맥의 단축어: %d개", comment: "Diagnostics: local count"), local))
        } catch {
            lines.append(String(format: NSLocalizedString("구역 읽기 실패: %@", comment: "Diagnostics: zone read failed"),
                                error.localizedDescription))
        }

        return lines.joined(separator: "\n")
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return NSLocalizedString("사용 가능", comment: "Diagnostics: account available")
        case .noAccount: return NSLocalizedString("로그인 안 됨", comment: "Diagnostics: no account")
        case .restricted: return NSLocalizedString("제한됨", comment: "Diagnostics: restricted")
        case .couldNotDetermine: return NSLocalizedString("알 수 없음", comment: "Diagnostics: unknown")
        case .temporarilyUnavailable: return NSLocalizedString("잠시 사용 불가", comment: "Diagnostics: temporarily unavailable")
        @unknown default: return NSLocalizedString("알 수 없음", comment: "Diagnostics: unknown")
        }
    }
}
