//
//  MacRecentClips.swift
//  ClipKeyboard.tap
//
//  '최근' 탭 - 이 맥에서 복사한 글. 아이폰 키보드의 '최근' 탭과 같은 경험이다.
//
//    · 탭 줄 맨 앞에 선다. 색은 파랑이고, 다른 카테고리는 이 색을 쓰지 않는다.
//    · 복사한 것이 저절로 담긴다(`ClipboardMonitorService`). 담는 버튼은 없다.
//    · 누르면 복사, 밀거나(트랙패드) 오른쪽 클릭하거나 ⌘⌫ 로 지운다.
//
//  ⚠️ 저장소는 클립보드 기록 창(`ClipboardHistoryView`)과 같은 파일이다. 여기서 지우면 그 창에서도 사라진다.
//

import AppKit
import SwiftUI

enum MacRecentClips {

    /// '최근' 탭의 색. 카테고리 칩은 이 색을 쓰지 않는다(`MacCategoryChipBar`).
    static let tint: Color = .blue

    // MARK: - 저장소

    static func load() -> [ClipboardHistory] {
        do {
            return try MemoStore.shared.loadClipboardHistory()
        } catch {
            print("❌ [MacRecentClips.load] 클립보드 기록 읽기 실패: \(error)")
            return []
        }
    }

    /// 검색어가 있으면 글에 그 말이 든 것만.
    static func filtered(_ clips: [ClipboardHistory], query: String) -> [ClipboardHistory] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return clips }
        return clips.filter { $0.contentType != .image && $0.content.localizedCaseInsensitiveContains(q) }
    }

    static func delete(_ clip: ClipboardHistory) {
        var all = load()
        all.removeAll { $0.id == clip.id }
        do {
            try MemoStore.shared.saveClipboardHistory(history: all)
            if let fileName = clip.imageFileName {
                try? MemoStore.shared.deleteImage(fileName: fileName)
            }
            print("🗑️ [MacRecentClips.delete] 최근 항목 1개 삭제")
        } catch {
            print("❌ [MacRecentClips.delete] 삭제 실패: \(error)")
        }
    }

    /// 클립보드에 다시 담는다. 담지 못했으면 false.
    @discardableResult
    static func copy(_ clip: ClipboardHistory) -> Bool {
        let pasteboard = NSPasteboard.general
        if clip.contentType == .image {
            guard let fileName = clip.imageFileName,
                  let image = MemoStore.shared.loadImage(fileName: fileName) else {
                print("❌ [MacRecentClips.copy] 이미지 로드 실패")
                return false
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        } else {
            pasteboard.clearContents()
            pasteboard.setString(clip.content, forType: .string)
        }
        MacUsageReporting.record(event: "recent_copy")
        return true
    }
}

// MARK: - 목록

/// 최근 항목 목록. 줄 모양은 단축어 줄(`PopoverRow`)과 같다.
///
/// ⚠️ `List` 로 그린다. 트랙패드로 밀어 지우기(`swipeActions`)는 `List` 에서만 된다.
struct MacRecentClipsList: View {
    let clips: [ClipboardHistory]
    /// 화살표로 고른 줄(팝오버). 고르는 기능이 없는 곳은 nil.
    let selectedIndex: Int?
    let copiedID: UUID?
    let isFiltering: Bool
    let onPick: (ClipboardHistory) -> Void
    let onDelete: (ClipboardHistory) -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        if clips.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        row(clip, index: index)
                            .id(clip.id)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(clip)
                                } label: {
                                    Label(NSLocalizedString("삭제", comment: "Delete button"), systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(NSLocalizedString("Copy", comment: "Popover context: copy")) {
                                    onPick(clip)
                                }
                                Divider()
                                Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) {
                                    onDelete(clip)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: selectedIndex) { _, newValue in
                    guard let newValue, clips.indices.contains(newValue) else { return }
                    withAnimation(.linear(duration: 0.08)) {
                        proxy.scrollTo(clips[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(_ clip: ClipboardHistory, index: Int) -> some View {
        let isCopied = copiedID == clip.id
        let isSelected = selectedIndex == index
        return Button {
            onPick(clip)
        } label: {
            HStack(spacing: MacSpacing.md) {
                Group {
                    if isCopied {
                        Image(systemName: AppSymbol.checkmarkCircleFill)
                            .foregroundStyle(.green)
                            .font(MacFont.body.weight(.semibold))
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    } else if selectedIndex != nil, index < 9 {
                        Text(verbatim: "⌘\(index + 1)")
                            .font(MacFont.mono)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: clip.contentType == .image ? "photo" : AppSymbol.docOnClipboard)
                            .font(MacFont.body)
                            .foregroundStyle(MacRecentClips.tint)
                    }
                }
                .frame(width: 28, alignment: .center)

                VStack(alignment: .leading, spacing: MacSpacing.xs / 2) {
                    Text(preview(clip))
                        .font(MacFont.rowTitle)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(isCopied
                         ? NSLocalizedString("Copied — press ⌘V to paste", comment: "Quick paste panel: shown on a row right after copying it")
                         : Self.relativeFormatter.localizedString(for: clip.copiedAt, relativeTo: Date()))
                        .font(MacFont.secondary)
                        .foregroundStyle(isCopied ? AnyShapeStyle(Color.green) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MacSpacing.lg)
            .padding(.vertical, MacSpacing.sm)
            .background(
                isCopied ? Color.green.opacity(0.18)
                    : isSelected ? MacColor.selection
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(
            selectedIndex != nil && index < 9 ? KeyEquivalent(Character("\(index + 1)")) : KeyEquivalent("\0"),
            modifiers: .command
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preview(clip))
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
        .accessibilityAction(named: Text(NSLocalizedString("삭제", comment: "Delete button"))) {
            onDelete(clip)
        }
    }

    /// 한 줄로 펴서 보인다. 이미지는 '이미지'.
    private func preview(_ clip: ClipboardHistory) -> String {
        guard clip.contentType != .image else {
            return NSLocalizedString("이미지", comment: "Image type")
        }
        return clip.content
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private var emptyState: some View {
        VStack(spacing: MacSpacing.md) {
            Image(systemName: isFiltering ? AppSymbol.magnifyingglass : AppSymbol.docOnClipboard)
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tertiary)
            Text(isFiltering
                 ? NSLocalizedString("No matches", comment: "Popover empty state (searching)")
                 : NSLocalizedString("아직 담아 둔 것이 없어요", comment: "Keyboard recent tab: empty title"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
            if !isFiltering {
                Text(NSLocalizedString("복사한 내용이 자동으로 여기에 저장됩니다\n(최대 100개, 7일간 유지)",
                                       comment: "Clipboard history empty description"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, MacSpacing.xl)
    }
}
