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
    /// ⚠️ `appIdentifier` 는 번들 ID 가 아니라 허브의 이름표다. 번들 ID 를 아이폰과 합친 뒤에도
    ///    맥 의견이 아이폰 의견과 섞이지 않게 예전 값을 그대로 둔다.
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

    /// 수익모델 - 무료 다운로드 + 무료 · Plus · Pro(월 · 연 구독과 평생). 상품과 권한은 `MacPlan`.
    ///
    /// 아이폰 앱과 번들 ID · App Store 레코드가 같아(유니버설 구매) 상품도 아이폰 것 그대로다.
    /// 한 번 사면 아이폰과 맥에서 함께 열린다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: MacPlan.allProductIDs,
            termsURL: URL(string: "https://m1zz.github.io/ClipKeyboard/terms.html")!
        )
    )

    /// 개발자 응원하기(팁, 소모성 세 가지 — 작은 것부터). 기능을 열지 않는다.
    /// 권한 상품은 `MacPlan` 이 따로 다뤄 LeeoStore 가 없다 — 앱이 뜰 때 `startStandalone()` 으로 혼자 선다.
    /// 아이폰과 같은 팁 상품이다.
    @MainActor static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.Ysoup.TokenMemo.tip.small",
        "com.Ysoup.TokenMemo.tip.medium",
        "com.Ysoup.TokenMemo.tip.large"
    ]))
}
