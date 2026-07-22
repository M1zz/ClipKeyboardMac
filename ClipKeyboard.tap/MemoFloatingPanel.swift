//
//  MemoFloatingPanel.swift
//  ClipKeyboard.tap
//
//  전역 단축키 ⌃⌥⇧V로 띄우는 non-activating 플로팅 패널.
//  macOS의 Character Viewer (⌃⌘Space) 와 비슷한 UX — 사용자가
//  다른 앱 TextField에 커서를 둔 상태 그대로, 패널을 클릭해
//  메모를 선택하면 원래 앱에 자동 붙여넣기.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Panel

/// canBecomeKey = false로 포커스 탈취를 아예 차단.
/// non-activating panel이더라도 기본적으로 NSPanel은 key window가 될
/// 수 있어 SwiftUI TextField가 들어가면 focus를 가져가 버린다. 이를
/// 막기 위해 서브클래싱.
final class MemoFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Controller

@MainActor
final class MemoFloatingPanelController: NSObject {
    static let shared = MemoFloatingPanelController()

    private var panel: MemoFloatingPanel?

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            panel = buildPanel()
        }
        guard let panel else { return }

        // 매 표시마다 콘텐츠를 새로 주입 → SwiftUI .onAppear 재호출 → 최신 메모 reload.
        // (패널은 1회 생성 후 orderFront로 재사용되므로, 콘텐츠를 갈아끼우지 않으면
        //  첫 표시 시점의 stale 메모가 그대로 남는다 — 메뉴바 팝오버와 동일한 이슈.)
        panel.contentViewController = makeContentViewController()

        // 활성 스크린 중앙 상단 가까이에 배치.
        if let screen = NSScreen.main {
            let panelSize = panel.frame.size
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2 + 80 // 약간 위쪽
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 포커스를 뺏지 않고 보이게 하기: orderFrontRegardless()
        // makeKeyAndOrderFront()나 NSApp.activate()는 호출하지 않음.
        panel.orderFrontRegardless()
        print("🪟 [FloatingPanel] 표시")
    }

    func close() {
        panel?.orderOut(nil)
        print("🪟 [FloatingPanel] 닫음")
    }

    private func buildPanel() -> MemoFloatingPanel {
        let panel = MemoFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        // 콘텐츠는 show()에서 매번 새로 주입한다 (fresh reload 보장).
        panel.contentViewController = makeContentViewController()
        return panel
    }

    /// 패널 콘텐츠(SwiftUI)를 새로 만들어 반환한다. show()에서 매 표시마다 호출해
    /// `.onAppear` → `reload()`가 항상 다시 돌도록 한다.
    private func makeContentViewController() -> NSViewController {
        let contentView = MemoFloatingPanelView(
            onSelect: { [weak self] memo in
                self?.handleSelect(memo)
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        return NSHostingController(rootView: contentView)
    }

    private func handleSelect(_ memo: Memo) {
        // 보안 메모면 Touch ID 인증 + 복호화 후 복사.
        MacSecureAccess.resolveForPaste(memo) { resolved in
            guard let resolved else { return }
            // 1) 클립보드에 텍스트 기록
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            print("📋 [FloatingPanel] 메모 복사: \(memo.title)")
            self.finishInsert()
        }
    }

    private func finishInsert() {
        // 2) 패널 닫기 (원래 전경 앱은 포커스 잃은 적 없음)
        close()

        // 3) CGEvent로 ⌘V 주입 — 전경 앱의 현재 커서에 바로 붙여넣기.
        //    약간의 지연으로 panel close 후 이벤트 큐 정리 시간 확보.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            DirectPasteHelper.pasteToFrontmostApp()
        }
    }
}

// MARK: - Panel Content View

struct MemoFloatingPanelView: View {
    let onSelect: (Memo) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = PanelListViewModel()
    @State private var highlightedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .background(
            // 반투명 재질 — Character Viewer 느낌.
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: MacRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MacRadius.md)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .frame(minWidth: 340, minHeight: 380)
        .onAppear {
            viewModel.reload()
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.docOnClipboardFill)
                .foregroundColor(.accentColor)
                .font(.system(.subheadline).weight(.semibold))
            Text(NSLocalizedString("ClipKeyboard", comment: "App menu name"))
                .font(.system(.subheadline).weight(.semibold))
                .foregroundColor(.primary)
            Spacer()
            Text(NSLocalizedString("Click to paste", comment: "Panel hint"))
                .font(.caption2)
                .foregroundColor(.secondary)
            Button {
                onDismiss()
            } label: {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.memos.isEmpty {
            emptyState
        } else {
            memoList
        }
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.memos.enumerated()), id: \.element.id) { index, memo in
                    FloatingMemoRow(memo: memo, index: index) {
                        onSelect(memo)
                    }
                    .contextMenu {
                        Button(NSLocalizedString("Copy", comment: "Context: copy")) {
                            MacSecureAccess.resolveForPaste(memo) { resolved in
                                guard let resolved else { return }
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(resolved, forType: .string)
                                onDismiss()
                            }
                        }
                        Button(NSLocalizedString("Copy and Paste", comment: "Popover context: copy + paste")) {
                            onSelect(memo)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: AppSymbol.docOnClipboard)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("No memos yet", comment: "Popover empty state"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Row

private struct FloatingMemoRow: View {
    let memo: Memo
    let index: Int
    let onTap: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if memo.isFavorite {
                    Image(systemName: AppSymbol.heartFill)
                        .foregroundColor(.pink)
                        .font(.system(.caption))
                        .frame(width: 16, height: 16)
                } else if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                } else {
                    Spacer().frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(memo.title)
                        .font(.system(.subheadline).weight(.medium))
                        .lineLimit(1)
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
                isHovering
                    ? Color.accentColor.opacity(0.18)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }
}

// MARK: - VM

@MainActor
final class PanelListViewModel: ObservableObject {
    @Published var memos: [Memo] = []

    func reload() {
        do {
            let loaded = try MemoStore.shared.load(type: .memo)
            // 사용자가 지정한 수동 순서(있으면) → 없으면 즐겨찾기 먼저, 최근순. iOS와 순서 공유.
            memos = MacMemoOrder.sorted(loaded)
        } catch {
            print("⚠️ [Panel] 메모 로드 실패: \(error)")
        }
    }
}

// MARK: - Visual Effect Background

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
