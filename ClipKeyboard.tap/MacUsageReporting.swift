//
//  MacUsageReporting.swift
//  ClipKeyboard.tap
//
//  익명 사용 통계 - 피드백과 같은 공용 허브(FeedbackHub, CloudKit public DB)로 보낸다.
//  전송 엔진은 LeeoKit(LeeoUsageReporter)이고, 여기서는 맥 앱의 지표·이벤트 정책만 정한다.
//  아이폰 `UsageReportingService` 와 같은 레코드(UsageSnapshot / UsageEvent)에 쌓이고,
//  `appId`(com.ysoup.TokenMemo-tap)와 `platform`(macOS)으로 갈린다.
//
//  보내는 것
//   ① UsageSnapshot - 설치당 1개(익명 UUID, upsert, 12시간 쓰로틀). 사용자 수 · 대략 지표.
//   ② UsageEvent - 주요 행동 이름만. 이름당 6시간에 1건(`app_open` 은 20시간).
//
//  ⚠️ PII 없음: 단축어 제목 · 내용, 클립보드 내용, 기기 · 계정 식별자는 절대 보내지 않는다.
//     보내는 값은 개수 같은 집계 수치와 이벤트 이름뿐이다.
//  ⚠️ 원격 킬스위치(`usageReportingEnabled`)가 꺼지면 아무것도 보내지 않는다(아이폰과 같은 플래그).
//

import Foundation
import LeeoKit

@MainActor
enum MacUsageReporting {

    private static var reporter: LeeoUsageReporter {
        LeeoUsageReporter(spec: ClipKeyboardTapSpec.self)
    }

    /// 같은 이벤트 이름을 다시 보내기까지의 최소 간격 - 공개 DB 쓰기 폭주 방지.
    nonisolated private static let eventThrottle: TimeInterval = 6 * 3600

    /// "이 설치가 오늘 활동했다" - 일간 활성 사용자 차트의 근거. 아이폰과 같은 이름이다.
    static let appOpenEvent = "app_open"

    private static var isReportingAllowed: Bool {
        RemoteFlagsService.cachedValue(.usageReportingEnabled)
    }

    // MARK: - 전송

    /// 앱이 뜰 때 1회. 설치 스냅샷을 갱신하고 오늘의 활동을 남긴다.
    ///
    /// 메뉴바 앱이라 로그인 항목으로 켜져 사람이 손대지 않은 날도 이 경로가 돈다.
    /// 그래서 여기의 `app_open` 은 "켜져 있었다" 까지만 뜻한다 - 실제로 쓴 날은
    /// `panel_open` · `popover_open` · `memo_copy` 가 증명한다.
    static func reportLaunch() {
        guard isReportingAllowed else { return }
        let metrics = currentMetrics()
        Task(priority: .utility) {
            await reporter.report(metrics: metrics)
        }
        record(event: appOpenEvent, minInterval: 20 * 3600, countsAsEngagement: false)
    }

    /// 주요 행동 1건. 로컬 참여도 카운터를 올리고, 허브 쓰기는 이름당 쓰로틀 간격에 한 번만.
    /// - Parameters:
    ///   - name: 이벤트 이름(snake_case). 슬라이스가 있으면 `memo_copy:panel` 형태.
    ///   - minInterval: 같은 이름을 다시 보내기까지의 최소 간격 (기본 6시간).
    ///   - countsAsEngagement: 참여도 카운터(리뷰 요청 게이팅)를 올릴지.
    static func record(event name: String,
                       minInterval: TimeInterval = eventThrottle,
                       countsAsEngagement: Bool = true) {
        if countsAsEngagement { LeeoEngagement.shared.registerSignificantEvent() }
        guard isReportingAllowed else { return }

        let key = DefaultsKey.usageEventLastSentPrefix + name
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < minInterval { return }

        let reporter = Self.reporter
        Task(priority: .utility) {
            // 보낸 것이 확정된 뒤에만 쓰로틀을 찍는다 - iCloud 미로그인 · 네트워크 실패로
            // 못 보낸 날이 "보냈다" 로 남아 그날의 활동이 통째로 사라지지 않게.
            if await reporter.logEvent(name) {
                await MainActor.run { UserDefaults.standard.set(Date(), forKey: key) }
            }
        }
    }

    // MARK: - 지표

    /// 설치당 대략 지표. 전부 개수다 - 내용은 하나도 담지 않는다.
    /// 키 이름은 아이폰 스냅샷과 같게 둬서 한 표에서 나란히 비교되게 한다.
    private static func currentMetrics() -> [String: Double] {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let samples = SampleMemoStorage.load()
        let clips = (try? MemoStore.shared.loadClipboardHistory()) ?? []

        return [
            "shortcuts": Double(memos.count),
            "ownShortcuts": Double(memos.filter { !samples.contains($0.id) }.count),
            "templates": Double(memos.filter(\.isTemplate).count),
            "combos": Double(memos.filter(\.isStack).count),
            "secure": Double(memos.filter(\.isSecure).count),
            "favorites": Double(memos.filter(\.isFavorite).count),
            "categories": Double(Set(memos.map(\.category)).count),
            "uses": Double(memos.reduce(0) { $0 + $1.clipCount }),
            "clips": Double(clips.count),
            "flag.syncOn": MemoSyncFlags.enabled ? 1 : 0
        ]
    }
}
