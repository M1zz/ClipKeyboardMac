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

    /// 수익모델 — 이 맥 앱은 **아무것도 팔지 않는다**.
    ///
    /// 아이폰은 `.freemium` 이지만 맥은 다르다. 이 타겟에는 StoreKit 자체가 없다.
    /// 화면의 Pro 게이트(단축어 한도·iCloud 백업)는 맥이 파는 것이 아니라 **아이폰에서 산
    /// 권한을 CloudKit 으로 받아 비추는 것**이다(`MacProManager.refreshFromCloud`).
    /// 그래서 `.free` 가 이 바이너리의 실상이다 — 페이월도 결제 코드도 없고, 따라서
    /// 복원(Restore) 의무도 이 앱에는 생기지 않는다.
    ///
    /// ⚠️ 맥에서 직접 결제를 받게 되는 날에는 이 선언부터 `.freemium` 으로 바꿔야 한다.
    ///    선언만 그대로 두면 페이월·복원 의무가 빠진 채로 결제가 나간다.
    static let monetization = LeeoMonetization.free
}
