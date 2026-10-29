//
//  MacAccessibility.swift
//  ClipKeyboard.tap
//
//  맥 메모 행(팝오버·플로팅 패널·리스트)에서 공유하는 VoiceOver 라벨.
//  보안 메모는 값을 노출하지 않고 상태만 읽는다.
//  복사 결과 알림 · 동작 줄이기 · 대비 증가 처리도 여기 모은다.
//

import AppKit
import SwiftUI

extension Memo {
    /// 맥 VoiceOver 라벨 — 제목 + 상태(즐겨찾기/보안/이미지/템플릿/콤보).
    var macAccessibilityLabel: String {
        var parts: [String] = [title]
        if isFavorite { parts.append(NSLocalizedString("즐겨찾기", comment: "Favorites")) }
        if isSecure {
            parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge"))
        } else if contentType == .image || contentType == .mixed {
            parts.append(NSLocalizedString("이미지 단축어", comment: "VoiceOver: image memo badge"))
        }
        if isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if isStack { parts.append(NSLocalizedString("스택", comment: "VoiceOver: combo badge")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 소리로 알리기 · 움직임 줄이기

enum MacA11y {
    /// 복사됨 같은 짧은 결과를 VoiceOver 로 읽어 준다. 화면의 체크·토스트는 눈으로만 보인다.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    /// 복사한 뒤 공통 안내 - "복사됨 · ⌘V로 붙여넣으세요".
    static func announceCopied() {
        announce(NSLocalizedString("Copied — press ⌘V to paste", comment: "Quick paste panel: shown on a row right after copying it"))
    }
}

/// 시스템 설정 ▸ 손쉬운 사용 ▸ 동작 줄이기. 켜져 있으면 튀거나 미끄러지는 효과를 끄고 바로 바꾼다.
enum MacMotion {
    static var isReduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func animation(_ animation: Animation) -> Animation? {
        isReduced ? nil : animation
    }

    /// 복사 체크가 톡 튀어나오는 효과 - 줄이면 그냥 나타난다.
    static var pop: AnyTransition {
        isReduced ? .opacity : .scale(scale: 0.3).combined(with: .opacity)
    }

    /// 아래에서 올라오는 토스트 - 줄이면 그 자리에서 나타난다.
    static var toast: AnyTransition {
        isReduced ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}

/// `withAnimation` 과 같되, 동작 줄이기가 켜져 있으면 애니메이션 없이 바꾼다.
@discardableResult
func macWithAnimation<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(MacMotion.animation(animation), body)
}

extension View {
    /// 성공(복사됨) 글자 - 초록 글자는 밝은 면에서 대비가 모자라, 대비 증가를 켜면 본문색으로 바꾼다.
    func macSuccessText() -> some View {
        modifier(MacSuccessText())
    }
}

private struct MacSuccessText: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.foregroundStyle(contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.green))
    }
}
