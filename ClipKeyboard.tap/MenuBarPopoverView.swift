//
//  MenuBarPopoverView.swift
//  ClipKeyboard.tap
//
//  Menu bar popover with instant search + keyboard navigation.
//  Designed for parity with Maccy/Paste table-stakes UX.
//

import AppKit
import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var memos: [Memo] = []
    @Published var selectedIndex: Int = 0

    var filtered: [Memo] {
        guard !searchText.isEmpty else { return memos }
        let q = searchText.lowercased()
        return memos.filter { memo in
            if memo.title.lowercased().contains(q) { return true }
            // 보안 메모는 값(암호문)으로 검색하지 않음 — 제목으로만 매칭.
            if memo.isSecure { return false }
            if memo.value.lowercased().contains(q) { return true }
            // Fuzzy: check char sequence (usr lcl → /usr/local 같은 매칭)
            return fuzzyMatch(needle: q, haystack: (memo.title + " " + memo.value).lowercased())
        }
    }

    func reload() {
        do {
            let loaded = try MemoStore.shared.load(type: .memo)
            // 사용자가 지정한 수동 순서(있으면) → 없으면 즐겨찾기 먼저, 최근순. iOS와 순서 공유.
            memos = MacMemoOrder.sorted(loaded)
            if selectedIndex >= filtered.count { selectedIndex = max(0, filtered.count - 1) }
        } catch {
            print("⚠️ [Popover] 메모 로드 실패: \(error)")
        }
    }

    /// 간이 fuzzy — 순서대로 문자가 등장하면 매치 (공백은 무시).
    private func fuzzyMatch(needle: String, haystack: String) -> Bool {
        let chars = Array(needle.filter { !$0.isWhitespace })
        guard !chars.isEmpty else { return true }
        var i = 0
        for c in haystack {
            if c == chars[i] {
                i += 1
                if i == chars.count { return true }
            }
        }
        return false
    }
}

// MARK: - View

struct MenuBarPopoverView: View {
    @StateObject private var viewModel = PopoverViewModel()
    @FocusState private var searchFocused: Bool

    /// 팝오버를 닫는 콜백 (MenuBarManager에서 주입).
    let dismiss: () -> Void
    /// 선택 시 바로 붙여넣기할지 — Preferences 토글 결정.
    @AppStorage("macAutoPaste") private var autoPaste: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if viewModel.filtered.isEmpty {
                emptyState
            } else {
                memoList
            }

            Divider()
            bottomToolbar
        }
        .frame(width: 360, height: 480)
        .onAppear {
            viewModel.reload()
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.magnifyingglass)
                .foregroundColor(.secondary)
                .font(.system(.subheadline))

            TextField(
                NSLocalizedString("Search memos", comment: "Popover search placeholder"),
                text: $viewModel.searchText
            )
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .onChange(of: viewModel.searchText) { _ in
                // 필터링되면 선택 인덱스를 0으로
                viewModel.selectedIndex = 0
            }
            .onSubmit {
                activateSelected()
            }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: AppSymbol.xmarkCircleFill)
                        .foregroundColor(.secondary)
                        .font(.system(.subheadline))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(KeyboardShortcutCapture(
            onArrowUp: { moveSelection(by: -1) },
            onArrowDown: { moveSelection(by: 1) },
            onEscape: { dismiss() },
            onReturn: { activateSelected() },
            onOptionReturn: { activateSelected(forcePaste: !autoPaste) }
        ))
    }

    private var memoList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.filtered.enumerated()), id: \.element.id) { index, memo in
                        PopoverRow(
                            memo: memo,
                            index: index,
                            isSelected: index == viewModel.selectedIndex,
                            showShortcut: index < 9
                        ) {
                            viewModel.selectedIndex = index
                            activateSelected()
                        }
                        .id(index)
                        .contextMenu {
                            Button(NSLocalizedString("Copy", comment: "Popover context: copy")) {
                                copyMemo(memo, paste: false)
                            }
                            Button(NSLocalizedString("Copy and Paste", comment: "Popover context: copy + paste")) {
                                copyMemo(memo, paste: true)
                            }
                            .keyboardShortcut(.return, modifiers: .option)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedIndex) { newValue in
                withAnimation(.linear(duration: 0.08)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: AppSymbol.docOnClipboard)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(
                viewModel.searchText.isEmpty
                ? NSLocalizedString("No memos yet", comment: "Popover empty state")
                : NSLocalizedString("No matches", comment: "Popover empty state (searching)")
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            quickButton(
                title: NSLocalizedString("New Memo", comment: "Menu: new memo"),
                symbol: "plus",
                shortcut: "N"
            ) {
                NotificationCenter.default.post(name: .showNewMemo, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }
            quickButton(
                title: NSLocalizedString("Clipboard History", comment: "Menu: clipboard history"),
                symbol: "clock.arrow.circlepath",
                shortcut: "H"
            ) {
                NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }
            // 메모 목록 창 — 드래그로 단축어 순서를 바꿀 수 있는 유일한 화면.
            quickButton(
                title: NSLocalizedString("Memo List", comment: "Menu: memo list"),
                symbol: "list.bullet",
                shortcut: "L"
            ) {
                NotificationCenter.default.post(name: .showMemoList, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }
            Spacer()
            quickButton(
                title: NSLocalizedString("Preferences", comment: "Settings window title"),
                symbol: "gearshape",
                shortcut: ","
            ) {
                NotificationCenter.default.post(name: .showSettings, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func quickButton(title: String, symbol: String, shortcut: Character, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(.footnote))
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
        .help(title)
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        let items = viewModel.filtered
        guard !items.isEmpty else { return }
        let next = (viewModel.selectedIndex + delta).clamped(to: 0...(items.count - 1))
        viewModel.selectedIndex = next
    }

    private func activateSelected(forcePaste: Bool? = nil) {
        let items = viewModel.filtered
        guard viewModel.selectedIndex >= 0, viewModel.selectedIndex < items.count else { return }
        let memo = items[viewModel.selectedIndex]
        let paste = forcePaste ?? autoPaste
        copyMemo(memo, paste: paste)
    }

    private func copyMemo(_ memo: Memo, paste: Bool) {
        // 보안 메모면 Touch ID 인증 + 복호화 후 복사. 일반 메모는 즉시.
        MacSecureAccess.resolveForPaste(memo) { resolved in
            guard let resolved else { return } // 인증 취소/실패/키 미동기화
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            print("✅ [Popover] 복사: \(memo.title)")
            dismiss()
            if paste {
                // 팝오버 닫힌 뒤 짧은 지연 후 ⌘V 자동 주입.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    DirectPasteHelper.pasteToFrontmostApp()
                }
            }
        }
    }
}

// MARK: - Row

private struct PopoverRow: View {
    let memo: Memo
    let index: Int
    let isSelected: Bool
    let showShortcut: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 즐겨찾기 하트 / 인덱스 배지
                if memo.isFavorite {
                    Image(systemName: AppSymbol.heartFill)
                        .foregroundColor(.pink)
                        .font(.system(.caption))
                        .frame(width: 16, height: 16)
                } else if showShortcut {
                    Text("⌘\(index + 1)")
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 16)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: MacRadius.xs))
                } else {
                    Spacer().frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(memo.title)
                        .font(.system(.subheadline).weight(.medium))
                        .lineLimit(1)
                    // 보안 메모는 값을 마스킹(인증 전 노출 금지).
                    let preview = MacSecureAccess.maskedPreview(memo)
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                    if !preview.isEmpty {
                        Text(memo.isSecure ? AttributedString(preview) : preview.templateChipAttributed())
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.18)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(
            showShortcut ? KeyEquivalent(Character("\(index + 1)")) : KeyEquivalent("\0"),
            modifiers: .command
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }
}

// MARK: - Keyboard shortcut capture

/// NSView 호스팅으로 화살표/ESC/Enter 키 이벤트를 잡는다.
/// SwiftUI `.onKeyPress`는 macOS 14+에서도 focus 문제가 있어, 안정적인 NSView 방식 사용.
private struct KeyboardShortcutCapture: NSViewRepresentable {
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onEscape: () -> Void
    let onReturn: () -> Void
    let onOptionReturn: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onArrowUp = onArrowUp
        view.onArrowDown = onArrowDown
        view.onEscape = onEscape
        view.onReturn = onReturn
        view.onOptionReturn = onOptionReturn
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private class KeyHandlerView: NSView {
        var onArrowUp: (() -> Void)?
        var onArrowDown: (() -> Void)?
        var onEscape: (() -> Void)?
        var onReturn: (() -> Void)?
        var onOptionReturn: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // 전역 monitor로 window-scoped로 키 인식
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window == event.window else { return event }
                switch event.keyCode {
                case 126: // up arrow
                    self.onArrowUp?()
                    return nil
                case 125: // down arrow
                    self.onArrowDown?()
                    return nil
                case 53: // escape
                    self.onEscape?()
                    return nil
                case 36, 76: // return / keypad enter
                    if event.modifierFlags.contains(.option) {
                        self.onOptionReturn?()
                    } else {
                        self.onReturn?()
                    }
                    return nil
                default:
                    return event
                }
            }
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
