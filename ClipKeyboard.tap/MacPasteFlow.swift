//
//  MacPasteFlow.swift
//  ClipKeyboard.tap
//
//  한 번에 복사할 수 없는 단축어(템플릿·스택)를 위한 입력 창.
//  ⌃⇧V 빠른 붙여넣기 패널과 메뉴바 팝오버가 같은 길을 쓴다.
//
//  - 템플릿({이름} 같은 칸이 있을 때): 값을 채우는 창. 글자를 받아야 하니 이 창은 포커스를
//    가져간다. 그래서 열기 전의 앞 앱을 기억해 두었다가, 복사하고 닫으면 그 앱으로 돌려준다
//    (커서가 있던 자리에서 곧바로 ⌘V).
//  - 스택: 칸 목록 창. 입력이 없으니 빠른 붙여넣기 패널처럼 포커스를 뺏지 않는다.
//    칸을 누르면 복사되고 잠깐 뒤 창이 닫힌다(빠른 붙여넣기 패널과 같다). 다시 열면
//    다음 칸부터 이어진다 - 열고 누르고 ⌘V, 열고 누르고 ⌘V.
//
//  ⚠️ 어느 쪽도 직접 붙여넣지 않는다. 다른 앱에 ⌘V 를 누르는 것(CGEvent)은 5.0.5(18)이
//     Guideline 2.4.5 로 거절된 이유다 (docs/RELEASE_NOTES_5.0.5_macOS.md).
//

import AppKit
import SwiftUI

@MainActor
enum MacPasteFlow {
    /// 한 번 눌러 바로 복사할 수 없는 단축어인가 - 그렇다면 `open(_:)` 으로 창을 띄운다.
    static func needsInput(_ memo: Memo) -> Bool {
        if memo.isStack && !memo.pasteStackValues.isEmpty { return true }
        // 잠긴 단축어의 값은 암호문이라 칸을 읽을 수 없다 - 인증 뒤 그대로 복사한다.
        return !memo.isSecure && memo.hasCustomPlaceholders
    }

    static func open(_ memo: Memo) {
        if memo.isStack && !memo.pasteStackValues.isEmpty {
            StackPasteWindow.shared.show(memo)
        } else {
            TemplateFillWindow.shared.show(memo)
        }
    }
}

extension Memo {
    /// 스택이 차례로 넣는 값. 칸(`stackItems`)이 있으면 그 값, 없으면 옛 값 목록.
    var pasteStackValues: [String] {
        guard isStack else { return [] }
        let fromItems = stackItems.map(\.value)
        return fromItems.isEmpty ? stackValues : fromItems
    }
}

// MARK: - Template

@MainActor
private final class TemplateFillWindow: NSObject, NSWindowDelegate {
    static let shared = TemplateFillWindow()

    private var window: NSPanel?
    /// 창을 열기 전에 쓰던 앱 - 닫을 때 돌려준다.
    private var previousApp: NSRunningApplication?

    func show(_ memo: Memo) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }

        window?.close()
        let content = MacTemplateFillSheet(
            memo: memo,
            onComplete: { [weak self] resolved in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(resolved, forType: .string)
                self?.finish()
            },
            onCancel: { [weak self] in self?.finish() }
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        // ⚠️ 창 크기를 내용에 맞추려 하지 않는다(`sizingOptions` + `setContentSize`).
        //    줄이지 않는 글과 물려 크기 계산이 끝나지 않았고, AppKit 이
        //    "Update Constraints in Window pass" 예외를 내며 앱이 죽었다.
        //    크기는 고정하고, 긴 템플릿은 시트 안에서 스크롤한다.
        panel.contentViewController = NSHostingController(rootView: content)
        panel.setContentSize(NSSize(width: 420, height: 460))
        panel.center()
        window = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // 쓰던 앱으로 돌려준다 - 그래야 커서 자리에서 바로 ⌘V 가 된다.
        previousApp?.activate()
        previousApp = nil
    }
}

// MARK: - Stack

/// 포커스를 뺏지 않는 떠 있는 창 - `MemoFloatingPanel` 과 같은 이유로 키 창이 되지 않는다.
private final class StackPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class StackPasteWindow {
    static let shared = StackPasteWindow()

    private var panel: StackPanel?
    /// 스택마다 어디까지 넣었는지 - 창이 복사 뒤 닫히므로, 다시 열면 여기서 이어진다.
    /// 앱이 켜져 있는 동안만 기억한다(아이폰 키보드도 기기에 적지 않는다).
    private var progress: [UUID: StackProgress] = [:]
    /// 열 때마다 +1 - 복사 뒤 늦게 닫는 동작이 그 사이 새로 연 창을 닫지 않게 한다.
    private var generation = 0

    /// 복사했다는 표시를 보여 줄 시간 - 빠른 붙여넣기 패널과 같게 맞춘다.
    private static let closeDelay: TimeInterval = 0.9

    func show(_ memo: Memo) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        generation += 1
        var saved = progress[memo.id] ?? StackProgress()
        // 칸 수가 바뀌었거나(아이폰에서 고침) 끝까지 넣었으면 처음부터.
        if saved.done.count >= memo.pasteStackValues.count || saved.current >= memo.pasteStackValues.count {
            saved = StackProgress()
        }
        panel.contentViewController = NSHostingController(
            rootView: StackPasteView(memo: memo,
                                     initial: saved,
                                     onCopied: { [weak self] updated in self?.didCopy(memo, updated) },
                                     onClose: { [weak self] in self?.close() })
        )
        if let screen = NSScreen.main {
            let size = panel.frame.size
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                         y: frame.midY - size.height / 2 + 80))
        }
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func didCopy(_ memo: Memo, _ updated: StackProgress) {
        progress[memo.id] = updated
        let opened = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeDelay) { [weak self] in
            guard let self, self.generation == opened else { return }
            self.close()
        }
    }

    private func makePanel() -> StackPanel {
        let panel = StackPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        return panel
    }
}

struct StackProgress {
    /// 다음에 넣을 칸
    var current = 0
    /// 이미 복사한 칸
    var done: Set<Int> = []
}

private struct StackPasteView: View {
    let memo: Memo
    let onCopied: (StackProgress) -> Void
    let onClose: () -> Void

    /// 다음에 넣을 칸 - 복사하면 한 칸 넘어간다.
    @State private var current: Int
    /// 이미 복사한 칸 - 체크로 남긴다.
    @State private var done: Set<Int>
    /// 방금 복사한 칸 - 그 줄에만 ⌘V 안내를 띄운다.
    @State private var justCopied: Int?

    init(memo: Memo, initial: StackProgress,
         onCopied: @escaping (StackProgress) -> Void,
         onClose: @escaping () -> Void) {
        self.memo = memo
        self.onCopied = onCopied
        self.onClose = onClose
        _current = State(initialValue: initial.current)
        _done = State(initialValue: initial.done)
    }

    private var values: [String] { memo.pasteStackValues }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: MacSpacing.xs) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            row(index: index, value: value).id(index)
                        }
                    }
                    .padding(MacSpacing.sm)
                }
                .onChange(of: current) { newValue in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(newValue, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(current, anchor: .center) }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MacRadius.md))
        .overlay(RoundedRectangle(cornerRadius: MacRadius.md).stroke(MacColor.border, lineWidth: 0.5))
        .frame(minWidth: 300, minHeight: 220)
    }

    private var header: some View {
        HStack(spacing: MacSpacing.sm) {
            Image(systemName: AppSymbol.squareStack3dUpFill)
                .foregroundStyle(.secondary)
            Text(memo.title)
                .font(MacFont.sectionTitle)
                .lineLimit(1)
            Text(verbatim: "\(min(done.count, values.count))/\(values.count)")
                .font(MacFont.mono)
                .foregroundStyle(.secondary)
            Spacer(minLength: MacSpacing.sm)
            Button(action: onClose) {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MacSpacing.md)
        .padding(.vertical, MacSpacing.sm)
        // 제목줄이 없으니 이 줄의 빈 곳을 끌어 창을 옮긴다.
        .background(Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()))
    }

    private func row(index: Int, value: String) -> some View {
        let isCurrent = index == current
        let isDone = done.contains(index)
        return Button {
            copy(index)
        } label: {
            HStack(spacing: MacSpacing.md) {
                Group {
                    if isDone {
                        Image(systemName: AppSymbol.checkmarkCircleFill).foregroundStyle(.green)
                    } else {
                        Text(verbatim: "\(index + 1)").font(MacFont.mono).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(memo.displayKey(at: index))
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if justCopied == index {
                        Text(NSLocalizedString("Copied — press ⌘V to paste", comment: "Quick paste panel: shown on a row right after copying it"))
                            .font(MacFont.body.weight(.medium))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    } else {
                        Text(memo.isSecure ? "••••••••" : (value.isEmpty ? "-" : value))
                            .font(MacFont.body)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.sm)
            .background(
                justCopied == index ? Color.green.opacity(0.18)
                    : isCurrent ? MacColor.selection : MacColor.surface,
                in: RoundedRectangle(cornerRadius: MacRadius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacRadius.sm)
                    .stroke(isCurrent ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(value.isEmpty)
        .help(memo.isSecure ? memo.displayKey(at: index) : value)
    }

    private func copy(_ index: Int) {
        guard values.indices.contains(index) else { return }
        // 칸 값을 담은 메모로 넘긴다 - 잠긴 스택의 인증·복호화와 자동 채움 값 치환을
        // 일반 단축어와 같은 길로 처리한다.
        var item = memo
        item.value = values[index]
        MacSecureAccess.resolveForPaste(item) { resolved in
            guard let resolved else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                done.insert(index)
                justCopied = index
                current = min(index + 1, values.count - 1)
            }
            onCopied(StackProgress(current: index + 1, done: done))
        }
    }
}
