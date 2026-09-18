//
//  MacTemplateFillSheet.swift
//  ClipKeyboard.tap
//
//  템플릿 메모에 사용자 정의 플레이스홀더({이름} 등)가 있을 때, 값을 채워
//  클립보드에 복사하는 시트. iOS의 PlaceholderSelectorView 흐름과
//  같은 결(칩 미리보기 + 라벨 입력 + 실시간 결과)을 맥에서 재현한다.
//

import SwiftUI
import AppKit

struct MacTemplateFillSheet: View {
    let memo: Memo
    /// 치환 완료 문자열
    let onComplete: (String) -> Void
    /// 시트가 아니라 창으로 띄웠을 때 닫는 길 - 창에서는 `dismiss` 가 아무 일도 하지 않는다
    /// (`MacPasteFlow`).
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var inputs: [String: String] = [:]
    /// 복사한 뒤 창이 닫히기 전까지 - 그냥 사라지면 복사가 된 것인지 알 수 없다.
    @State private var copied = false

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
        VStack(alignment: .leading, spacing: MacSpacing.lg) {
            // 헤더
            VStack(alignment: .leading, spacing: MacSpacing.xs) {
                Text(NSLocalizedString("값 채우기", comment: "Mac template fill sheet title"))
                    .font(MacFont.screenTitle)
                Text(memo.title)
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 칸이 많거나 템플릿이 길면 여기만 스크롤한다.
            // ⚠️ 창 크기를 내용에 맞추지 않는다 - 그렇게 했다가 크기 계산이 끝나지 않아
            //    앱이 죽었다(`MacPasteFlow` 주석).
            ScrollView {
                VStack(alignment: .leading, spacing: MacSpacing.lg) {
                    // 원본 템플릿 (칩 미리보기)
                    // ⚠️ 세로로는 줄이지 않는다 - 높이가 모자라면 SwiftUI 가 한 줄로 접어 "…" 로
                    //    잘랐고, 뒤쪽 칸({금액})이 안 보여 무엇을 채우는지 알 수 없었다.
                    Text(memo.value.templateChipAttributed())
                        .font(MacFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MacSpacing.md)
                        .macSurface()

                    // 입력 필드
                    VStack(alignment: .leading, spacing: MacSpacing.md) {
                        ForEach(placeholders, id: \.self) { token in
                            let name = token.trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
                            VStack(alignment: .leading, spacing: MacSpacing.xs) {
                                Text(name)
                                    .font(MacFont.secondary)
                                    .foregroundStyle(.secondary)
                                TextField(name, text: binding(for: token))
                                    .textFieldStyle(.roundedBorder)
                                    .font(MacFont.body)
                            }
                        }
                    }

                    // 결과 미리보기
                    VStack(alignment: .leading, spacing: MacSpacing.xs) {
                        Text(NSLocalizedString("미리보기", comment: "Preview label"))
                            .font(MacFont.secondary)
                            .foregroundStyle(.secondary)
                        Text(resolved.isEmpty ? " " : resolved)
                            .font(MacFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(MacSpacing.md)
                            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: MacRadius.sm))
                    }
                }
                .padding(.horizontal, 1)
            }

            // 액션 - 스크롤 밖에 둔다. 칸이 많아도 복사 버튼이 늘 보여야 한다.
            HStack(spacing: MacSpacing.sm) {
                Button(NSLocalizedString("취소", comment: "Cancel button")) { close() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if copied {
                    Label(NSLocalizedString("Copied — press ⌘V to paste", comment: "Quick paste panel: shown on a row right after copying it"),
                          systemImage: AppSymbol.checkmarkCircleFill)
                        .font(MacFont.body.weight(.medium))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else {
                    Button(NSLocalizedString("복사", comment: "Copy")) { copyAndClose() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(MacSpacing.xl)
        .frame(width: 420, height: 460)
    }

    /// 복사하고, 복사됐다고 잠깐 보여 준 뒤 닫는다(패널·팝오버와 같은 0.9초).
    private func copyAndClose() {
        onComplete(resolved)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { close() }
    }

    private func close() {
        dismiss()
        onClose?()
    }

    private func binding(for token: String) -> Binding<String> {
        Binding(
            get: { inputs[token] ?? "" },
            set: { inputs[token] = $0 }
        )
    }
}
