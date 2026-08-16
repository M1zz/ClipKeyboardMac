//
//  MacDefaultsKey.swift
//  ClipKeyboard.tap
//
//  맥 전용 UserDefaults 키.
//
//  ⚠️ 공유 파일인 `Shared/DefaultsKey.swift` 는 iOS 원본과 **바이트 단위로 같아야** 한다
//     (scripts/check_shared_drift.sh 가 배포를 막는다). 맥에만 있는 키를 거기 끼워 넣으면
//     다음 동기화 때 조용히 지워지고, 그 사이엔 드리프트로 배포가 막힌다.
//     → 맥에만 필요한 키는 여기에 확장으로 둔다.
//

import Foundation

extension DefaultsKey {
    /// 맥 온보딩을 한 번이라도 끝냈는지.
    /// 지금은 기록만 하고 읽는 곳이 없다 — 온보딩은 Help 메뉴에서 수동으로만 연다
    /// (`WindowManager.openOnboardingWindow`). 나중에 자동 표시를 붙일 때 쓰려고 남겨 둔다.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
