//
//  MacTheme.swift
//  ClipKeyboard.tap
//
//  맥 앱 디자인 토큰 — iOS 앱(AppTheme)의 radius 스케일과 같은 결을 맞춘다.
//  맥 타겟은 iOS의 AppTheme를 공유하지 않으므로(별도 코드베이스) 여기에 동일 스케일을 둔다.
//  색은 macOS 네이티브에 자연스럽게 녹아들도록 시스템 시맨틱 색을 쓰고,
//  모서리·간격·글자 크기만 토큰으로 통일한다.
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

/// 간격 토큰 — 화면마다 제각각이던 padding/spacing을 이 다섯 단계로만 쓴다.
enum MacSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// 타이포 토큰 — **모든 글자는 .body 이상**. 정보 위계는 크기가 아니라
/// 굵기(weight)와 색(.secondary)으로 만든다. 작은 글씨를 섞지 않는 쪽이
/// 맥에서 훨씬 깔끔하게 읽힌다.
enum MacFont {
    /// 화면 제목 (창·시트 최상단)
    static let screenTitle = Font.title2.weight(.semibold)
    /// 섹션 제목 (그룹 헤더)
    static let sectionTitle = Font.headline
    /// 목록 행 제목
    static let rowTitle = Font.body.weight(.medium)
    /// 본문 · 입력 필드
    static let body = Font.body
    /// 보조 설명 — 크기는 본문과 같고 `.secondary` 색으로만 낮춘다.
    static let secondary = Font.body
    /// 단축키·인덱스 배지 등 고정폭
    static let mono = Font.system(.body, design: .monospaced)
}

/// 아이콘 크기 토큰 — 60pt 짜리 장식 아이콘들을 이 두 단계로 정리한다.
enum MacIcon {
    /// 행·툴바 안의 기호
    static let glyph: CGFloat = 16
    /// 빈 상태·헤더의 대표 기호
    static let hero: CGFloat = 32
}

/// 색 토큰 — 화면마다 다르던 `Color.gray.opacity(...)` 를 하나로 모은다.
enum MacColor {
    /// 검색창·카드 등 옅은 면
    static let surface = Color.primary.opacity(0.06)
    /// 마우스 호버
    static let hover = Color.primary.opacity(0.07)
    /// 선택된 행
    static let selection = Color.accentColor.opacity(0.15)
    /// 얇은 테두리
    static let border = Color.primary.opacity(0.08)
}

extension View {
    /// 옅은 배경 면 — 카드·검색창·미리보기 박스에 공통으로 쓴다.
    func macSurface(_ radius: CGFloat = MacRadius.sm) -> some View {
        background(MacColor.surface, in: RoundedRectangle(cornerRadius: radius))
    }
}
