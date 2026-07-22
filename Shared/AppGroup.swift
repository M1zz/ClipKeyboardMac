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
}
