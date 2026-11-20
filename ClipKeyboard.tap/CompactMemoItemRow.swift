//
//  CompactMemoItemRow.swift
//  ClipKeyboard.tap
//
//  단축어 목록의 줄 하나와, 여러 값 중 하나를 골라 복사하는 고르개.
//  `MemoListView.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import SwiftUI
import AppKit
import LeeoKit

// MARK: - Compact Memo Item Row

// MARK: - Combo Value Picker (여러 값 중 하나 골라 복사)

/// 콤보(여러 값) 메모 탭 시 뜨는 값 선택 시트 — 값 하나를 눌러 복사한다.
struct MacComboValuePicker: View {
    let memo: Memo
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var values: [String] {
        memo.stackValues.isEmpty ? [memo.value] : memo.stackValues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacSpacing.md) {
            VStack(alignment: .leading, spacing: MacSpacing.xs) {
                Text(memo.title)
                    .font(MacFont.sectionTitle)
                    .lineLimit(1)
                Text(NSLocalizedString("값을 눌러 복사하세요", comment: "Combo preview: tap a value to copy"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: MacSpacing.sm) {
                    ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                        Button {
                            onPick(value)
                            dismiss()
                        } label: {
                            // 칸 **이름**을 값 위에 세운다. 번호만 있을 때는 무엇을 고르는지
                            // 값을 읽어야 알 수 있었는데, 값이 길거나 비슷하면 그게 잘 안 된다.
                            // 이름은 아이폰에서 짓고(`StackItem.key`), 안 지었으면 자리로 부른다.
                            HStack(spacing: MacSpacing.md) {
                                Text("\(idx + 1)")
                                    .font(MacFont.mono)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(memo.displayKey(at: idx))
                                        .font(MacFont.secondary)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(value.isEmpty ? "-" : value)
                                        .font(MacFont.body)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(MacSpacing.md)
                            .macSurface()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(value.isEmpty)
                    }
                }
            }
        }
        .padding(MacSpacing.xl)
        .frame(width: 380, height: 400)
    }
}

struct CompactMemoItemRow: View {
    let memo: Memo
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: MacSpacing.xs) {
            copyButton
            // 수정·삭제는 복사 버튼 **바깥**에 둔다 — 버튼 안에 버튼을 넣으면
            // macOS 에서 바깥 버튼이 클릭을 먼저 먹어 눌리지 않는다.
            if isHovering {
                rowActions
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(NSLocalizedString("복사", comment: "Context: copy")) { onCopy() }
            Button(NSLocalizedString("수정…", comment: "Context: edit")) { onEdit() }
            Button(memo.isFavorite
                   ? NSLocalizedString("즐겨찾기 해제", comment: "Context: unfavorite")
                   : NSLocalizedString("즐겨찾기", comment: "Favorite toggle")) { onToggleFavorite() }
            Divider()
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) { onDelete() }
        }
    }

    /// 수정·삭제 버튼 — 마우스를 올렸을 때만 나타나 평소 목록을 조용하게 둔다.
    private var rowActions: some View {
        HStack(spacing: MacSpacing.xs) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(MacFont.body)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("수정…", comment: "Context: edit"))
            .accessibilityLabel(NSLocalizedString("수정…", comment: "Context: edit"))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(MacFont.body)
                    .foregroundStyle(.red)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("삭제", comment: "Delete button"))
            .accessibilityLabel(NSLocalizedString("삭제", comment: "Delete button"))
        }
        .padding(.trailing, MacSpacing.xs)
    }

    private var copyButton: some View {
        // Button(.plain)으로 감싸야 macOS List의 드래그 순서변경(.onMove)과 클릭-복사가
        // 공존한다. .onTapGesture 는 List의 reorder 드래그 제스처를 가로채 드래그가 안 먹는다.
        Button(action: onCopy) {
        HStack(spacing: MacSpacing.md) {
            // 아이콘 — 즐겨찾기만 색으로 강조하고 나머지는 무채색으로 통일.
            Image(systemName: memo.contentType == .image ? "photo" :
                  memo.isFavorite ? "star.fill" :
                  memo.isSecure ? "lock.fill" : "doc.text")
                .foregroundStyle(memo.isFavorite ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                .font(MacFont.body)
                .frame(width: MacIcon.glyph)

            // 콘텐츠
            VStack(alignment: .leading, spacing: MacSpacing.xs / 2) {
                HStack(spacing: MacSpacing.xs) {
                    Text(memo.title)
                        .font(MacFont.rowTitle)
                        .lineLimit(1)

                    Spacer()

                    if isHovering {
                        Image(systemName: memo.contentType == .image ? "photo" : "doc.on.doc")
                            .font(MacFont.body)
                            .foregroundStyle(.tint)
                    }
                }

                if memo.contentType == .image || memo.contentType == .mixed {
                    // 이미지 미리보기
                    let imageFileNames = memo.imageFileNames.isEmpty && memo.imageFileName != nil
                        ? [memo.imageFileName!]
                        : memo.imageFileNames

                    if !imageFileNames.isEmpty {
                        HStack(spacing: MacSpacing.xs) {
                            ForEach(Array(imageFileNames.prefix(3).enumerated()), id: \.offset) { _, fileName in
                                if let image = MemoStore.shared.loadImage(fileName: fileName) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipped()
                                        .cornerRadius(MacRadius.xs)
                                }
                            }

                            if imageFileNames.count > 3 {
                                Text("+\(imageFileNames.count - 3)")
                                    .font(MacFont.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memo.contentType == .mixed && !memo.value.isEmpty {
                        Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                            .font(MacFont.secondary)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(memo.isSecure ? AttributedString(memo.listPreviewText) : memo.listPreviewText.templateChipAttributed())
                        .font(MacFont.secondary)
                        .lineLimit(memo.listPreviewLineLimit)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, MacSpacing.sm)
        .padding(.horizontal, MacSpacing.sm)
        .background(isHovering ? MacColor.hover : Color.clear)
        .cornerRadius(MacRadius.xs)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
        // 수정·삭제 단추는 마우스를 올려야 나타난다 - VoiceOver 에서는 동작으로 고른다.
        .accessibilityAction(named: Text(NSLocalizedString("수정…", comment: "Context: edit")), onEdit)
        .accessibilityAction(named: Text(memo.isFavorite
                                         ? NSLocalizedString("즐겨찾기 해제", comment: "Context: unfavorite")
                                         : NSLocalizedString("즐겨찾기", comment: "Favorite toggle")), onToggleFavorite)
        .accessibilityAction(named: Text(NSLocalizedString("삭제", comment: "Delete button")), onDelete)
        .accessibilityActions {
            if let onMoveUp {
                Button(NSLocalizedString("Move up", comment: "Reorder: move up"), action: onMoveUp)
            }
            if let onMoveDown {
                Button(NSLocalizedString("Move down", comment: "Reorder: move down"), action: onMoveDown)
            }
        }
    }
}

#Preview {
    MemoListView()
}
