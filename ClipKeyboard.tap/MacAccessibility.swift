//
//  MacAccessibility.swift
//  ClipKeyboard.tap
//
//  맥 메모 행(팝오버·플로팅 패널·리스트)에서 공유하는 VoiceOver 라벨.
//  보안 메모는 값을 노출하지 않고 상태만 읽는다.
//

import Foundation

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
        if isCombo { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        return parts.joined(separator: ", ")
    }
}
