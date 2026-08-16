//
//  AppGroup.swift
//  ClipKeyboard
//
//  App Group 식별자 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 AppGroup.identifier 를 사용할 것.
//

import Foundation

enum AppGroup {
    /// App Group 컨테이너 / 공유 UserDefaults suite 식별자
    static let identifier = "group.com.Ysoup.TokenMemo"

    /// 키보드와 나눠 쓰는 UserDefaults.
    ///
    /// 예전에는 쓰는 자리마다 `UserDefaults(suiteName: AppGroup.identifier)` 로 새로 만들었다.
    /// 같은 suite를 가리키니 동작은 같지만, 읽는 사람 입장에서는 "여기만 다른 걸 보나?" 를
    /// 매번 확인해야 했고 실제로 리터럴을 그대로 적은 자리도 섞여 있었다. 통로를 하나로 둔다.
    ///
    /// suite 생성은 실패할 수 있어 옵셔널을 그대로 내보낸다. 억지로 `.standard` 로 떨어뜨리면
    /// **키보드가 못 보는 곳에 저장**되어, 안 되는 것보다 나쁜 조용한 실패가 된다.
    static let defaults = UserDefaults(suiteName: identifier)
}
