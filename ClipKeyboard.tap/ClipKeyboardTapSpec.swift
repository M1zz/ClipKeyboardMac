//
//  ClipKeyboardTapSpec.swift
//  ClipKeyboard.tap
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//

import Foundation
import LeeoKit

enum ClipKeyboardTapSpec: LeeoAppSpec {
    static let appName = "ClipKeyboard"
    static let developerEmail = "leeo@kakao.com"
    /// 키보드와 나눠 쓰는 기록. 백업 금고가 함께 떠 둔다.
    static let appGroups = ["group.com.Ysoup.TokenMemo"]

    /// ClipKeyboard.tap.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier로 앱을 구분한다.
    /// (백업/동기화는 iCloud.com.Ysoup.TokenMemo 컨테이너에서 계속 담당한다.)
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.ysoup.TokenMemo-tap"
    )

    /// 법적·지원 링크 — LeeoKit 3.0 계약 필수 항목.
    /// ⚠️ 아이폰 앱(`ClipKeyboardSpec.legal`)과 **같은 주소**여야 한다. 같은 제품의 두 판이라
    ///    처리방침이 갈라지면 안 되고, 개인정보 처리방침 주소는 App Store Connect 에
    ///    등록한 것과도 일치해야 한다.
    ///    (아이폰은 `Constants` 가 단일 출처인데 그 파일은 맥에 공유되지 않아 여기 적는다.
    ///     주소를 바꿀 일이 생기면 양쪽을 함께 고칠 것.)
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ClipKeyboard/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/ClipKeyboard/")!,
        termsURL: URL(string: "https://m1zz.github.io/ClipKeyboard/terms.html")!,
        // 계정을 만들지 않는다 — 데이터는 사용자의 iCloud·기기에만 있다.
        createsAccounts: false,
        marketingURL: URL(string: "https://m1zz.github.io/ClipKeyboard/")!
    )

    /// 수익모델 — 무료 다운로드 + 무료 · Plus · Pro(주 · 월 · 연 구독과 평생). 상품과 권한은 `MacPlan`.
    ///
    /// 5.1.9 까지는 스토어 유료 다운로드였다. 그때 산 사람은 `AppTransaction.originalAppVersion` 으로
    /// 확인해 Pro 평생을 준다(`MacPlan.boughtBeforeFree`).
    ///
    /// ⚠️ 5.0.5(20) 은 아이폰 결제를 비추는 Pro 게이트 때문에 Guideline 2.1(b) 로 거절됐다(이 앱 레코드에
    ///    제출된 IAP 가 없었다). 이제 이 타겟이 StoreKit 으로 직접 팔고, 페이월 · 복원 · 약관이 이 타겟에 있다.
    ///    심사에 낼 때 이 상품들을 같은 버전과 함께 제출할 것.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: MacPlan.allProductIDs,
            termsURL: URL(string: "https://m1zz.github.io/ClipKeyboard/terms.html")!
        )
    )

    /// 개발자 응원하기(팁, 소모성 세 가지 — 작은 것부터). 기능을 열지 않는다.
    /// 권한 상품은 `MacPlan` 이 따로 다뤄 LeeoStore 가 없다 — 앱이 뜰 때 `startStandalone()` 으로 혼자 선다.
    /// ⚠️ 상품 ID 에는 하이픈을 쓸 수 없어 번들 ID(`com.ysoup.TokenMemo-tap`)의 `-` 를 `.` 으로 바꿨다.
    @MainActor static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.ysoup.TokenMemo.tap.tip.small",
        "com.ysoup.TokenMemo.tap.tip.medium",
        "com.ysoup.TokenMemo.tap.tip.large"
    ]))
}
