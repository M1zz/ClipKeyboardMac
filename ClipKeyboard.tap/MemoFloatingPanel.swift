//
//  MemoFloatingPanel.swift
//  ClipKeyboard.tap
//
//  전역 단축키 ⌃⇧V로 띄우는 non-activating 플로팅 패널.
//  macOS의 Character Viewer (⌃⌘Space) 와 비슷한 UX — 사용자가
//  다른 앱 TextField에 커서를 둔 상태 그대로, 패널을 클릭해
//  메모를 고르면 클립보드에 담기고 패널이 닫힌다. 포커스를 뺏지 않으므로
//  그 자리에서 ⌘V로 바로 붙여넣을 수 있다.
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
    /// 패널을 열 때마다 +1 - 복사 뒤 늦게 닫는 동작이 새로 연 패널을 닫지 않게 한다.
    private var showGeneration = 0

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
        showGeneration += 1

        // 이 패널은 앱을 활성화하지 않는다 - `applicationDidBecomeActive` 의 동기화가 돌지 않아
        // 아이폰에서 지운 단축어가 그대로 보였다. 열 때마다 직접 받아온다.
        MemoSyncEngine.shared.startIfEnabled()
        MemoSyncEngine.shared.syncNow()

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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            // ⚠️ `.titled` 를 넣지 않는다. 투명하게 숨겨도 제목줄 자리(28pt)가 남아
            //    내용 위에 가로줄이 그어지고, 그 띠가 머리 부분 클릭을 가로챘다.
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

        // 콘텐츠는 show()에서 매번 새로 주입한다 (fresh reload 보장).
        panel.contentViewController = makeContentViewController()
        return panel
    }

    /// 패널 콘텐츠(SwiftUI)를 새로 만들어 반환한다. show()에서 매 표시마다 호출해
    /// `.onAppear` → `reload()`가 항상 다시 돌도록 한다.
    private func makeContentViewController() -> NSViewController {
        let contentView = MemoFloatingPanelView(
            onSelect: { [weak self] memo, didCopy in
                self?.handleSelect(memo, didCopy: didCopy)
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        return NSHostingController(rootView: contentView)
    }

    /// "복사됨 · ⌘V로 붙여넣으세요" 를 보여 줄 시간. 읽을 수 있을 만큼만 - 길면 붙여넣기가 늦어진다.
    private static let copiedFeedbackDuration: TimeInterval = 0.9

    private func handleSelect(_ memo: Memo, didCopy: @escaping () -> Void) {
        // 템플릿(채울 칸)·스택은 한 번에 복사할 수 없다 - 입력 창으로 넘기고 이 패널은 닫는다.
        print("📋 [FloatingPanel] 선택: \(memo.title) stack=\(memo.isStack) items=\(memo.stackItems.count) template=\(memo.hasCustomPlaceholders)")
        if MacPasteFlow.needsInput(memo) {
            close()
            MacPasteFlow.open(memo)
            return
        }
        // 보안 메모면 Touch ID 인증 + 복호화 후 복사.
        MacSecureAccess.resolveForPaste(memo) { resolved in
            guard let resolved else { return }
            // 1) 클립보드에 텍스트 기록
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            print("📋 [FloatingPanel] 메모 복사: \(memo.title)")
            // 2) 행 앞에 체크를 띄우고 ⌘V 로 붙여넣으라고 알린다.
            //    ⚠️ 직접 붙여넣어 주지 않는다. 다른 앱에 ⌘V 를 누르는 것(CGEvent)은 5.0.5(18)이
            //       Guideline 2.4.5 로 거절된 이유다 (docs/RELEASE_NOTES_5.0.5_macOS.md).
            didCopy()
            // 3) 잠깐 보여 준 뒤 패널 닫기. 이 패널은 non-activating이라 전경 앱이 포커스를
            //    잃은 적이 없으므로, 닫는 즉시 원래 커서 자리에서 ⌘V로 붙여넣을 수 있다.
            //    ⚠️ 그 사이 사용자가 패널을 닫았다 다시 열었으면 새로 연 패널은 닫지 않는다.
            let generation = self.showGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedFeedbackDuration) {
                guard self.showGeneration == generation else { return }
                self.close()
            }
        }
    }
}

// MARK: - Panel Content View

/// 빠르게 골라 붙여넣는 화면 - 제목줄을 없애고 한 줄짜리 행으로 한 화면에 최대한 많이 보인다.
/// 카테고리 칩은 메뉴바 팝오버와 같은 것(`MacCategoryChipBar`)을 쓴다.
///
/// ⚠️ 이 패널은 키 윈도가 될 수 없다(`canBecomeKey = false`) - 포커스를 뺏지 않아야
///    닫자마자 원래 자리에서 ⌘V 가 되기 때문이다. 그래서 검색창은 둘 수 없다(입력을 못 받는다).
struct MemoFloatingPanelView: View {
    /// 두 번째 인자는 클립보드에 실제로 담긴 뒤 부른다(보안 메모는 인증을 통과한 뒤).
    let onSelect: (Memo, @escaping () -> Void) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = PopoverViewModel()
    /// 방금 복사한 단축어 - 그 행 앞에 체크가 뜬다.
    @State private var copiedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            topBar
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
                .stroke(MacColor.border, lineWidth: 0.5)
        )
        .frame(minWidth: 320, minHeight: 240)
        .onAppear {
            viewModel.reload()
        }
    }

    // MARK: Parts

    /// 카테고리 칩 + 닫기. 제목·안내 문구는 뺐다 - 무엇을 하는 창인지는 행이 말해 준다.
    private var topBar: some View {
        HStack(spacing: 0) {
            MacCategoryChipBar(tabs: viewModel.tabs, selected: viewModel.selectedTab) { tab in
                viewModel.selectedTab = tab
            }
            .padding(.leading, -MacSpacing.sm)
            Spacer(minLength: MacSpacing.sm)
            Button {
                onDismiss()
            } label: {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MacSpacing.sm)
        .padding(.vertical, MacSpacing.sm)
        // 제목줄이 없으니 이 줄의 빈 곳을 끌어 창을 옮긴다.
        .background(Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.filtered.isEmpty {
            emptyState
        } else {
            memoList
        }
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filtered.enumerated()), id: \.element.id) { index, memo in
                    FloatingMemoRow(memo: memo, isCopied: copiedID == memo.id) {
                        copy(memo)
                    }
                    .contextMenu {
                        Button(NSLocalizedString("Copy", comment: "Context: copy")) {
                            copy(memo)
                        }
                    }
                }
            }
            .padding(.vertical, MacSpacing.xs)
        }
    }

    private func copy(_ memo: Memo) {
        onSelect(memo) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                copiedID = memo.id
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: MacSpacing.md) {
            Image(systemName: AppSymbol.docOnClipboard)
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tertiary)
            Text(NSLocalizedString("No memos yet", comment: "Popover empty state"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, MacSpacing.xl)
    }
}

// MARK: - Row

/// 한 줄 행 - 제목 뒤에 내용 미리보기를 이어 붙인다. 글자 크기는 줄이지 않고(MacFont 규칙)
/// 두 줄을 한 줄로 합쳐 행 높이를 절반 가까이 줄였다.
/// 템플릿·스택은 누르면 입력 창이 뜬다(`MacPasteFlow`) - 오른쪽 › 가 그 표시다.
private struct FloatingMemoRow: View {
    let memo: Memo
    let isCopied: Bool
    let onTap: () -> Void

    @State private var isHovering: Bool = false

    private var stackValues: [String] { memo.pasteStackValues }
    private var isStack: Bool { !stackValues.isEmpty }
    private var isMultiline: Bool { !isStack && !isCopied && memo.listPreviewLineLimit > 1 }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: isMultiline ? .top : .center, spacing: MacSpacing.sm) {
                leading
                    .frame(width: 18, alignment: .center)

                if isMultiline {
                    // 템플릿 - 한 줄에 제목과 이어 붙이면 뒤쪽 칸이 잘린다. 내용을 제목 아래로 내린다.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(memo.title)
                            .font(MacFont.rowTitle)
                            .lineLimit(1)
                        detail
                    }
                } else {
                    Text(memo.title)
                        .font(MacFont.rowTitle)
                        .lineLimit(1)
                        .layoutPriority(1)

                    detail
                }
                Spacer(minLength: 0)

                if MacPasteFlow.needsInput(memo) {
                    Image(systemName: AppSymbol.chevronRight)
                        .font(MacFont.body)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.xs + 1)
            .background(
                isCopied ? Color.green.opacity(0.18)
                    : isHovering ? MacColor.selection : Color.clear,
                in: RoundedRectangle(cornerRadius: MacRadius.xs)
            )
            .padding(.horizontal, MacSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(memo.isSecure ? memo.title : memo.value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }

    /// 제목 뒤 회색 글 - 복사한 직후엔 붙여넣기 안내, 스택은 칸 이름들, 그 밖엔 내용 미리보기.
    @ViewBuilder
    private var detail: some View {
        if isCopied {
            Text(NSLocalizedString("Copied — press ⌘V to paste", comment: "Quick paste panel: shown on a row right after copying it"))
                .font(MacFont.secondary.weight(.medium))
                .foregroundStyle(.green)
                .lineLimit(1)
                .transition(.opacity)
        } else if isStack {
            Text(stackValues.indices.map { memo.displayKey(at: $0) }.joined(separator: " → "))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            let preview = memo.listPreviewText
            if !preview.isEmpty && preview != memo.title {
                Text(memo.isSecure ? AttributedString(preview) : preview.templateChipAttributed())
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(memo.listPreviewLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        if isCopied {
            Image(systemName: AppSymbol.checkmarkCircleFill)
                .foregroundStyle(.green)
                .font(MacFont.body.weight(.semibold))
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        } else if memo.isFavorite {
            Image(systemName: AppSymbol.heartFill)
                .foregroundStyle(.pink)
                .font(MacFont.body)
        } else if memo.isSecure {
            Image(systemName: AppSymbol.lockFill)
                .foregroundStyle(.secondary)
                .font(MacFont.body)
        } else if isStack {
            Image(systemName: AppSymbol.squareStack3dUpFill)
                .foregroundStyle(.secondary)
                .font(MacFont.body)
        } else {
            Color.clear
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
