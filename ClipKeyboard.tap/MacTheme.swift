//
//  MacTheme.swift
//  ClipKeyboard.tap
//
//  맥 앱 디자인 토큰 — iOS 앱(AppTheme)의 radius 스케일과 같은 결을 맞춘다.
//  맥 타겟은 iOS의 AppTheme를 공유하지 않으므로(별도 코드베이스) 여기에 동일 스케일을 둔다.
//  색은 macOS 네이티브에 자연스럽게 녹아들도록 시스템 시맨틱 색을 쓰고,
//  모서리·간격만 iOS와 동일한 토큰으로 통일한다.
//

import SwiftUI

/// 코너 radius 토큰 — iOS AppTheme(Dusk 기준 xs6/sm10/md14/lg20/xl28)과 동일.
enum MacRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}
