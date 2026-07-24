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
}
