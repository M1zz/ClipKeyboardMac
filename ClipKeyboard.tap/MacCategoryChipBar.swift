//
//  MacCategoryChipBar.swift
//  ClipKeyboard.tap
//
//  카테고리 칩 줄. 메뉴바 팝오버와 빠른 붙여넣기 패널이 같이 쓴다.
//  `MenuBarPopoverView.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Category chips

/// 카테고리 칩 줄 — 메뉴바 팝오버와 ⌃⇧V 빠른 붙여넣기 패널이 같은 모양을 쓴다.
/// 탭이 하나 이하면 아무것도 그리지 않는다.
///
/// ⚠️ 가로 스크롤은 트랙패드·매직마우스로만 된다. 일반 마우스는 휠이 세로라, Shift 를 모르면
///    넘친 칩에 닿을 길이 없었다. 그래서 이 줄 위에 커서가 있을 때는 세로 휠을 가로로 돌린다.
///    눌러 고른 칩은 가운데로 끌어온다.
struct MacCategoryChipBar: View {
    let tabs: [CategoryTab]
    let selected: CategoryTab
    /// '최근' 칩을 보고 있는가. 보고 있으면 카테고리 칩은 하나도 눌려 있지 않다.
    var recentSelected: Bool = false
    /// 있으면 맨 앞에 '최근' 칩을 세운다(`MacRecentClips`).
    var onSelectRecent: (() -> Void)? = nil
    let onSelect: (CategoryTab) -> Void

    @State private var position = ScrollPosition(edge: .leading)
    @State private var offsetX: CGFloat = 0
    @State private var maxOffsetX: CGFloat = 0
    @State private var isHovering = false
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        if tabs.count + (onSelectRecent == nil ? 0 : 1) > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MacSpacing.sm) {
                    if let onSelectRecent {
                        recentChip(onSelectRecent).id(-1)
                    }
                    // 스크롤 목표는 자리 번호로 잡는다 - `scrollTo(id:)` 는 Sendable 한 id 를 요구한다.
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        chip(tab, index: index).id(index)
                    }
                }
                .padding(.horizontal, MacSpacing.lg)
                .scrollTargetLayout()
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(width: geometry.contentOffset.x,
                       height: max(0, geometry.contentSize.width - geometry.containerSize.width))
            } action: { _, value in
                offsetX = value.width
                maxOffsetX = value.height
            }
            .onHover { isHovering = $0 }
            .background(VerticalWheelToHorizontal(isActive: isHovering && maxOffsetX > 0) { delta in
                let target = min(max(offsetX - delta, 0), maxOffsetX)
                position.scrollTo(x: target)
            })
        }
    }

    /// '최근' 칩. 아이폰 키보드처럼 늘 파란색이라 다른 칩과 헷갈리지 않는다.
    private func recentChip(_ action: @escaping () -> Void) -> some View {
        Button {
            action()
            macWithAnimation(.easeOut(duration: 0.2)) { position.scrollTo(edge: .leading) }
        } label: {
            HStack(spacing: MacSpacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                Text(NSLocalizedString("최근", comment: "Recent"))
                    .lineLimit(1)
            }
            .font(MacFont.body)
            .foregroundStyle(recentSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(MacRecentClips.tint))
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.xs)
            .background(recentSelected ? MacRecentClips.tint : MacRecentClips.tint.opacity(0.12), in: Capsule())
            .overlay(selectedOutline(recentSelected))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(recentSelected ? .isSelected : [])
    }

    private func chip(_ tab: CategoryTab, index: Int) -> some View {
        let isSelected = selected == tab && !recentSelected
        return Button {
            onSelect(tab)
            macWithAnimation(.easeOut(duration: 0.2)) { position.scrollTo(id: index, anchor: .center) }
        } label: {
            HStack(spacing: MacSpacing.xs) {
                Image(systemName: tab.icon)
                Text(MacCategoryName.display(tab.displayName))
                    .lineLimit(1)
            }
            .font(MacFont.body)
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.xs)
            .background(isSelected ? MacColor.selection : MacColor.surface, in: Capsule())
            .overlay(selectedOutline(isSelected))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 고른 칩은 색으로만 다르다 - '색상 없이 구별' 을 켜면 테두리를 더해 모양으로도 구별한다.
    @ViewBuilder
    private func selectedOutline(_ isSelected: Bool) -> some View {
        if isSelected && differentiateWithoutColor {
            Capsule().strokeBorder(Color.primary, lineWidth: 1.5)
        }
    }
}

/// 커서가 올라가 있는 동안 **세로로만 굴린** 휠을 가로 이동량으로 넘긴다.
/// 가로 성분이 있는 스크롤(트랙패드·매직마우스·Shift+휠)은 건드리지 않고 원래대로 흘려보낸다.
/// 떠 있는 패널은 키 창이 아니어도 휠 이벤트는 커서 아래 창으로 오므로 로컬 모니터로 잡힌다.
private struct VerticalWheelToHorizontal: NSViewRepresentable {
    let isActive: Bool
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.update(isActive: isActive, onScroll: onScroll)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isActive: isActive, onScroll: onScroll)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        weak var view: NSView?
        private var monitor: Any?
        private var isActive = false
        private var onScroll: ((CGFloat) -> Void)?

        func update(isActive: Bool, onScroll: @escaping (CGFloat) -> Void) {
            self.isActive = isActive
            self.onScroll = onScroll
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.isActive,
                      event.window != nil, event.window === self.view?.window,
                      event.scrollingDeltaX == 0, event.scrollingDeltaY != 0
                else { return event }
                // 일반 휠은 한 칸이 1 안팎이라 칩 한 개쯤 움직이게 키운다.
                let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 24
                self.onScroll?(event.scrollingDeltaY * scale)
                return nil
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { stop() }
    }
}
