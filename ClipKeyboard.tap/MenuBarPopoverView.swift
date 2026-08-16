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
    /// 선택된 카테고리 탭. 첫 탭은 구성에 따라 다르다(아이폰 구성=기본 / 예전 구성=전체).
    @Published var selectedTab: CategoryTab = .all

    /// 아이폰에서 넘어온 카테고리 설정(순서·아이콘·숨김·기본제공) — 메모 목록 창과 같은 구성을 쓴다.
    private(set) var categorySettings: CategorySnapshot = CategorySnapshotStore.current()

    /// 표시할 탭 목록 — 아이폰 구성을 따르기로 했으면 아이폰 그대로, 아니면 4.4.6 까지의 구성.
    var tabs: [CategoryTab] {
        MacCategoryTabs.tabs(memos: memos,
                             snapshot: categorySettings,
                             followsPhone: MacCategoryTabPreference.shared.followsPhone)
    }

    var filtered: [Memo] {
        var result = memos

        // 1) 카테고리 탭 — 탭이 없으면 필터도 없다.
        if !tabs.isEmpty {
            result = MacCategoryTabs.memos(result, for: selectedTab, in: categorySettings)
        }

        // 2) 검색어
        guard !searchText.isEmpty else { return result }
        let q = searchText.lowercased()
        return result.filter { memo in
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
            // 메모와 카테고리 설정은 같은 동기화로 함께 갱신된다 — 따로 읽으면
            // 새 탭의 메모는 왔는데 탭 순서·아이콘은 옛것인 상태가 생긴다.
            categorySettings = CategorySnapshotStore.current()
            let loaded = try MemoStore.shared.load(type: .memo)
            // 사용자가 지정한 수동 순서(있으면) → 없으면 즐겨찾기 먼저, 최근순. iOS와 순서 공유.
            memos = MacMemoOrder.sorted(loaded)
            // 기존 사용자에게 "아이폰 구성으로 맞출까요?"를 물어봐야 하는 상황인지 판단한다.
            MacCategoryTabPreference.shared.evaluate(memos: memos, snapshot: categorySettings)
            // 구성이 바뀌거나 아이폰에서 카테고리를 숨기면 보고 있던 탭이 사라진다 —
            // 그 자리에 서 있는 첫 탭으로 되돌린다.
            let available = tabs
            if !available.isEmpty && !available.contains(selectedTab) { selectedTab = available[0] }
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
    @ObservedObject private var tabPreference = MacCategoryTabPreference.shared
    @FocusState private var searchFocused: Bool

    /// 팝오버를 닫는 콜백 (MenuBarManager에서 주입).
    let dismiss: () -> Void
    /// 선택 시 바로 붙여넣기할지 — Preferences 토글 결정.
    @AppStorage("macAutoPaste") private var autoPaste: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if tabPreference.needsAsk {
                Divider()
                MacCategoryAdoptBanner(preference: tabPreference)
            }
            categoryTabs
            Divider()

            if viewModel.filtered.isEmpty {
                emptyState
            } else {
                memoList
            }

            Divider()
            bottomToolbar
        }
        .frame(width: 400, height: 500)
        .onAppear {
            viewModel.reload()
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: tabPreference.followsPhone) { _ in
            // 구성이 바뀌면 탭 목록이 통째로 달라진다 — 첫 탭으로 옮기고 선택도 초기화.
            viewModel.selectedTab = viewModel.tabs.first ?? .all
            viewModel.selectedIndex = 0
        }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack(spacing: MacSpacing.sm) {
            Image(systemName: AppSymbol.magnifyingglass)
                .foregroundStyle(.secondary)

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
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(MacFont.body)
        .padding(.horizontal, MacSpacing.lg)
        .padding(.vertical, MacSpacing.md)
        .background(KeyboardShortcutCapture(
            onArrowUp: { moveSelection(by: -1) },
            onArrowDown: { moveSelection(by: 1) },
            onEscape: { dismiss() },
            onReturn: { activateSelected() },
            onOptionReturn: { activateSelected(forcePaste: !autoPaste) }
        ))
    }

    /// 카테고리 탭 — 아이폰이 설정한 목록·순서·이름·아이콘 그대로.
    /// 카테고리 기능이 꺼져 있으면(탭 없음) 줄 자체가 사라진다.
    @ViewBuilder
    private var categoryTabs: some View {
        let tabs = viewModel.tabs
        if tabs.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MacSpacing.sm) {
                    ForEach(tabs, id: \.self) { tab in
                        categoryChip(tab)
                    }
                }
                .padding(.horizontal, MacSpacing.lg)
                .padding(.bottom, MacSpacing.sm)
            }
        }
    }

    private func categoryChip(_ tab: CategoryTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            viewModel.selectedTab = tab
            viewModel.selectedIndex = 0
        } label: {
            HStack(spacing: MacSpacing.xs) {
                Image(systemName: tab.icon)
                Text(tab.displayName)
                    .lineLimit(1)
            }
            .font(MacFont.body)
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.xs)
            .background(isSelected ? MacColor.selection : MacColor.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
        VStack(spacing: MacSpacing.md) {
            Image(systemName: AppSymbol.docOnClipboard)
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tertiary)
            Text(
                viewModel.searchText.isEmpty
                ? NSLocalizedString("No memos yet", comment: "Popover empty state")
                : NSLocalizedString("No matches", comment: "Popover empty state (searching)")
            )
            .font(MacFont.body)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, MacSpacing.xl)
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

            // 전역 단축키 안내 — 메뉴바를 열지 않아도 어디서나 패널을 띄울 수 있다는 정보.
            quickPasteHint

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
        .padding(.horizontal, MacSpacing.md)
        .padding(.vertical, MacSpacing.sm)
    }

    /// "⌃⇧V 빠른 붙여넣기 패널" 안내 — 눌러도 패널이 열려, 안내이면서 버튼이다.
    private var quickPasteHint: some View {
        Button {
            dismiss()
            MemoFloatingPanelController.shared.show()
        } label: {
            HStack(spacing: MacSpacing.xs) {
                Text(verbatim: "⌃⇧V")
                    .font(MacFont.mono)
                    .padding(.horizontal, MacSpacing.xs + 2)
                    .padding(.vertical, 1)
                    .background(MacColor.surface, in: RoundedRectangle(cornerRadius: MacRadius.xs))

                Text(NSLocalizedString("Quick Paste Panel", comment: "Shortcut: quick paste"))
                    .font(MacFont.body)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("The quick paste panel (⌃⇧V) stays over your current app — click a memo and the text is pasted directly into the text field you were typing in, without losing focus.", comment: "Quick paste explainer (3-key)"))
    }

    /// 하단 툴바 버튼 — 글자를 줄여 넣는 대신 기호만 두고 이름은 툴팁(⌘단축키 포함)으로 안내한다.
    private func quickButton(title: String, symbol: String, shortcut: Character, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(MacFont.body)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
        .help("\(title) (⌘\(String(shortcut).uppercased()))")
        .accessibilityLabel(title)
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
            HStack(spacing: MacSpacing.md) {
                // 즐겨찾기 하트 / 인덱스 배지
                if memo.isFavorite {
                    Image(systemName: AppSymbol.heartFill)
                        .foregroundStyle(.pink)
                        .font(MacFont.body)
                        .frame(width: 28, alignment: .center)
                } else if showShortcut {
                    Text("⌘\(index + 1)")
                        .font(MacFont.mono)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                } else {
                    Spacer().frame(width: 28)
                }

                VStack(alignment: .leading, spacing: MacSpacing.xs / 2) {
                    Text(memo.title)
                        .font(MacFont.rowTitle)
                        .lineLimit(1)
                    // 보안 메모는 값을 마스킹(인증 전 노출 금지).
                    let preview = MacSecureAccess.maskedPreview(memo)
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                    if !preview.isEmpty {
                        Text(memo.isSecure ? AttributedString(preview) : preview.templateChipAttributed())
                            .font(MacFont.secondary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MacSpacing.lg)
            .padding(.vertical, MacSpacing.sm)
            .background(
                isSelected
                    ? MacColor.selection
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
