//
//  MacTopEdgeTrigger.swift
//  ClipKeyboard.tap
//
//  화면 위 가운데(맥북은 노치)에 마우스를 잠깐 올리면 빠른 붙여넣기 패널을 그 바로 아래로 내린다.
//  ⌃⇧V 를 몰라도 패널을 찾을 수 있게 하는 두 번째 입구다.
//
//  ⚠️ 투명 창을 깔지 않고 마우스 움직임만 지켜본다(`NSEvent` 모니터). 창을 깔면 아이맥 메뉴바
//     가운데의 클릭을 가로챈다. 마우스 이벤트 모니터는 손쉬운 사용 권한이 필요 없다
//     (권한이 필요한 건 키 이벤트뿐이다).
//

import AppKit

@MainActor
final class MacTopEdgeTrigger {
    static let shared = MacTopEdgeTrigger()

    /// 설정 키 - 환경설정 ▸ 단축키의 스위치와 같은 값. 기본은 켬(찾게 하려고 만든 입구다).
    static let defaultsKey = "macTopEdgeTrigger"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    /// 이만큼 머물러야 연다 - 메뉴바로 지나가는 마우스에 열리지 않게.
    private static let dwell: TimeInterval = 0.25
    /// 패널에서 이만큼 벗어나 있으면 닫는다 - 잘못 열었을 때 X 를 누르지 않아도 되게.
    private static let leaveDelay: TimeInterval = 0.4
    /// 노치가 없는 화면에서 지켜볼 메뉴바 가운데 폭.
    private static let plainZoneWidth: CGFloat = 200

    private var monitors: [Any] = []
    private var pendingOpen: DispatchWorkItem?
    private var pendingClose: DispatchWorkItem?
    /// 이 입구로 연 패널만 마우스가 떠나면 닫는다. ⌃⇧V 로 연 패널은 건드리지 않는다.
    private var openedByHover = false

    /// 설정에 맞춰 지켜보기를 켜거나 끈다. 시작할 때와 스위치를 바꿀 때 부른다.
    func refresh() {
        stop()
        guard Self.isEnabled else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
        // 다른 앱 위에서는 전역 모니터, 이 앱의 창(패널) 위에서는 로컬 모니터가 받는다.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        pendingOpen?.cancel()
        pendingClose?.cancel()
        pendingOpen = nil
        pendingClose = nil
    }

    private func mouseMoved() {
        let point = NSEvent.mouseLocation
        let inZone = Self.zone(at: point)?.contains(point) ?? false

        if let panelFrame = MemoFloatingPanelController.shared.visibleFrame {
            pendingOpen?.cancel()
            pendingOpen = nil
            guard openedByHover else { return }
            let near = inZone || panelFrame.insetBy(dx: -24, dy: -24).contains(point)
            if near {
                pendingClose?.cancel()
                pendingClose = nil
            } else if pendingClose == nil {
                pendingClose = Self.after(Self.leaveDelay) { [weak self] in
                    self?.pendingClose = nil
                    MemoFloatingPanelController.shared.close()
                }
            }
            return
        }

        openedByHover = false
        pendingClose = nil
        if inZone {
            guard pendingOpen == nil else { return }
            pendingOpen = Self.after(Self.dwell) { [weak self] in
                self?.pendingOpen = nil
                let point = NSEvent.mouseLocation
                guard let self, let zone = Self.zone(at: point), zone.contains(point) else { return }
                self.openedByHover = true
                MemoFloatingPanelController.shared.show(below: zone)
            }
        } else {
            pendingOpen?.cancel()
            pendingOpen = nil
        }
    }

    private static func after(_ delay: TimeInterval, _ work: @escaping () -> Void) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }

    /// 마우스가 있는 화면의 입구 - 노치가 있으면 노치 자리, 없으면 메뉴바 가운데.
    private static func zone(at point: NSPoint) -> NSRect? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return nil }
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let height = screen.safeAreaInsets.top
            return NSRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        }
        // 메뉴바를 자동으로 숨겨도 맨 윗줄은 지켜본다.
        let height = max(frame.maxY - screen.visibleFrame.maxY, 4)
        return NSRect(x: frame.midX - plainZoneWidth / 2, y: frame.maxY - height,
                      width: plainZoneWidth, height: height)
    }
}
