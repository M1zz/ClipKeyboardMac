//
//  MacTemplateFillSheet.swift
//  ClipKeyboard.tap
//
//  템플릿 메모에 사용자 정의 플레이스홀더({이름} 등)가 있을 때, 값을 채운 뒤
//  복사/붙여넣기하도록 안내하는 시트. iOS의 PlaceholderSelectorView 흐름과
//  같은 결(칩 미리보기 + 라벨 입력 + 실시간 결과)을 맥에서 재현한다.
//

import SwiftUI
import AppKit

struct MacTemplateFillSheet: View {
    let memo: Memo
    /// (치환 완료 문자열, 붙여넣기 여부)
    let onComplete: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputs: [String: String] = [:]

    private var placeholders: [String] { memo.customPlaceholders }

    /// 비어있지 않은 입력만 치환에 사용 (빈 칸은 칩으로 남겨 안내).
    private var filledInputs: [String: String] {
        inputs.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var resolved: String {
        TemplateVariableProcessor.substitute(memo.value, with: filledInputs)
    }

    /// 아직 치환되지 않은 플레이스홀더가 남았는지 (결과 미리보기 칩 강조용).
    private var hasUnfilled: Bool {
        !resolved.extractTemplatePlaceholders().isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("값 채우기", comment: "Mac template fill sheet title"))
                    .font(.headline)
                Text(memo.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 원본 템플릿 (칩 미리보기)
            Text(memo.value.templateChipAttributed())
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: MacRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: MacRadius.sm)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            // 입력 필드
            VStack(alignment: .leading, spacing: 10) {
                ForEach(placeholders, id: \.self) { token in
                    let name = token.trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(name, text: binding(for: token))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: MacRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: MacRadius.sm)
                                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }

            // 결과 미리보기
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("미리보기", comment: "Preview label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(resolved.isEmpty ? " " : resolved)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: MacRadius.sm))
            }

            // 액션
            HStack {
                Button(NSLocalizedString("취소", comment: "Cancel button")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(NSLocalizedString("복사", comment: "Copy")) {
                    onComplete(resolved, false)
                    dismiss()
                }
                Button(NSLocalizedString("복사 후 붙여넣기", comment: "Copy then paste")) {
                    onComplete(resolved, true)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func binding(for token: String) -> Binding<String> {
        Binding(
            get: { inputs[token] ?? "" },
            set: { inputs[token] = $0 }
        )
    }
}
