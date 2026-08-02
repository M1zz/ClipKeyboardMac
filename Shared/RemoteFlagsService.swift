//
//  RemoteFlagsService.swift
//  ClipKeyboard
//
//  원격 킬스위치 — 심사 없이 문제 기능을 끌 수 있는 최소 장치.
//
//  왜 필요한가: 지금은 기능 하나가 사고를 내면 고쳐서 심사를 통과할 때까지(며칠)
//  손쓸 방법이 없다. 피드백/통계용 CloudKit 공개 DB가 이미 있으므로 레코드 하나만
//  더 두면 된다 — 새 인프라 비용이 사실상 0이다.
//
//  설계 원칙
//   ⚠️ **가용성 우선**: 조회에 실패하면 전부 "켬"으로 둔다. 네트워크가 없다고 앱
//      기능이 꺼지면 킬스위치가 오히려 장애 원인이 된다.
//   ⚠️ 앱 실행당 한 번만 조회하고 App Group에 캐시한다. 다음 실행은 캐시로 즉시
//      시작하고 백그라운드에서 갱신한다(플래그 때문에 런치가 느려지면 안 된다).
//   ⚠️ 여기서 끄는 건 **기능**이지 사용자 데이터가 아니다. 꺼져도 데이터는 남는다.
//
//  운영 방법 (CloudKit Dashboard)
//   컨테이너: iCloud.com.Ysoup.FeedbackHub (피드백·통계와 동일)
//   레코드 타입: RemoteFlags / recordName: "flags_com.Ysoup.TokenMemo"
//   필드: syncEnabled·usageReportingEnabled·paywallEnabled (Int64, 1=켬 0=끔)
//   → 값을 0으로 바꾸고 저장하면 다음 실행부터 해당 기능이 꺼진다.
//

import Foundation
import CloudKit
import Combine   // ObservableObject — 맥 타겟엔 SwiftUI 경유 암묵 임포트가 없어 명시한다.

@MainActor
final class RemoteFlagsService: ObservableObject {

    static let shared = RemoteFlagsService()

    /// 원격에서 끌 수 있는 기능 목록.
    /// ⚠️ 새 플래그를 추가할 땐 반드시 기본값을 `true`(켬)로 둘 것 —
    ///    Dashboard에 필드를 안 만든 상태에서 기능이 꺼져버리면 안 된다.
    enum Flag: String, CaseIterable {
        /// 기기 간 단축어 동기화(베타). 사고 시 1순위 차단 대상.
        case syncEnabled
        /// 익명 사용 통계 전송. 옵트아웃이 없는 설계라, 문제가 되면 이걸로 즉시 멈춘다.
        case usageReportingEnabled
        /// 페이월 노출. 결제 흐름이 깨졌을 때 임시로 감춘다.
        case paywallEnabled
    }

    private static let recordType = "RemoteFlags"

    /// 킬스위치 레코드가 사는 공용 허브 컨테이너 — 피드백·통계와 동일.
    /// ⚠️ 앱의 `LeeoAppSpec`(iOS `ClipKeyboardSpec` / 맥 `ClipKeyboardTapSpec`)을 참조하지 않는다.
    ///    타입 이름이 타겟마다 달라, 참조하면 이 파일을 두 앱이 공유할 수 없다.
    private static let flagsContainerID = "iCloud.com.Ysoup.FeedbackHub"

    /// ⚠️ 맥 앱(`com.ysoup.TokenMemo-tap`)도 **이 레코드 하나**를 함께 읽는다.
    ///    동기화는 iOS↔맥 공용 프로토콜이라, 한쪽만 끄면 나머지 한쪽이 계속 올려서
    ///    상태가 어긋난다(끄나 마나가 된다). Dashboard 에서 여기만 바꾸면 두 앱이 같이 멈춘다.
    private static let flagsRecordName = "flags_com.Ysoup.TokenMemo"

    /// `nonisolated`: 아래 `cachedValue(_:)`가 메인 액터 밖(키보드·백그라운드)에서도
    /// 읽어야 한다. 불변 String 상수라 격리가 필요 없고, 격리된 채 두면 Swift 6에서 에러가 된다.
    nonisolated private static let cachePrefix = "remote.flag."
    /// 조회 실패가 반복될 때 매 실행마다 네트워크를 때리지 않도록 하는 최소 간격.
    private static let refreshInterval: TimeInterval = 6 * 3600
    private static let lastFetchKey = "remote.flags.lastFetchAt"

    private var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    private init() {}

    // MARK: - 조회

    /// 플래그 값. **네트워크를 타지 않는다** — 캐시에 없으면 켬으로 본다.
    /// 호출부는 이 값을 그냥 읽으면 되고, 갱신은 `refreshInBackground()`가 담당한다.
    func isEnabled(_ flag: Flag) -> Bool {
        guard let defaults,
              defaults.object(forKey: Self.cachePrefix + flag.rawValue) != nil else {
            return true   // 캐시 없음 = 아직 한 번도 못 받아봄 → 켬
        }
        return defaults.bool(forKey: Self.cachePrefix + flag.rawValue)
    }

    /// nonisolated 편의 접근자 — 키보드 익스텐션·백그라운드 코드에서 쓴다.
    /// (익스텐션에는 이 서비스가 없으므로 App Group 캐시만 직접 읽는다.)
    nonisolated static func cachedValue(_ flag: Flag) -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier),
              defaults.object(forKey: cachePrefix + flag.rawValue) != nil else { return true }
        return defaults.bool(forKey: cachePrefix + flag.rawValue)
    }

    // MARK: - 갱신

    /// 앱 실행 시 호출. 쓰로틀 간격 안이면 아무것도 안 한다.
    /// 실패해도 조용히 넘어간다 — 캐시(또는 기본값 켬)로 계속 동작한다.
    func refreshInBackground() {
        let last = defaults?.double(forKey: Self.lastFetchKey) ?? 0
        let elapsed = Date().timeIntervalSince1970 - last
        guard elapsed > Self.refreshInterval else { return }

        Task(priority: .utility) { [weak self] in
            await self?.fetch()
        }
    }

    /// 실제 조회. 성공한 필드만 캐시에 반영한다(부분 성공 허용).
    func fetch() async {
        let database = CKContainer(identifier: Self.flagsContainerID).publicCloudDatabase

        do {
            let record = try await database.record(for: CKRecord.ID(recordName: Self.flagsRecordName))
            for flag in Flag.allCases {
                // 필드가 없으면 건드리지 않는다 — 기존 캐시(또는 기본 켬)를 유지.
                guard let raw = record[flag.rawValue] as? Int64 else { continue }
                defaults?.set(raw != 0, forKey: Self.cachePrefix + flag.rawValue)
            }
            defaults?.set(Date().timeIntervalSince1970, forKey: Self.lastFetchKey)
            AppLog.info(.flags, "🎛 [RemoteFlagsService.fetch] 플래그 갱신 완료")
        } catch let error as CKError where error.code == .unknownItem {
            // 레코드를 아직 안 만든 정상 상태 — 전부 켬으로 두고 다음 주기까지 조용히 지낸다.
            defaults?.set(Date().timeIntervalSince1970, forKey: Self.lastFetchKey)
            AppLog.info(.flags, "🎛 [RemoteFlagsService.fetch] 플래그 레코드 없음 — 전부 켬으로 동작")
        } catch {
            // 네트워크·권한 실패. **캐시를 건드리지 않는다** — 마지막으로 알던 값을 유지.
            AppLog.warning(.flags, "⚠️ [RemoteFlagsService.fetch] 갱신 실패(기존 값 유지): \(error.localizedDescription)")
        }
    }
}
