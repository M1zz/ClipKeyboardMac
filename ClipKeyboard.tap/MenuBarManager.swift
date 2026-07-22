//
//  MenuBarManager.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//
//  v4.1: NSMenu → NSPopover with SwiftUI. 검색·키보드 네비·⌘1-9·
//  ⌥Enter 바로 붙여넣기로 Maccy/Paste 수준의 table-stakes UX.
//

import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            print("❌ [MenuBar] 버튼 생성 실패")
            return
        }

        // SF Symbol 아이콘 (라이트/다크 자동).
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipKeyboard") {
            icon.isTemplate = true
            button.image = icon
        } else {
            button.title = "🛶"
        }

        // 클릭 이벤트 — 팝오버 토글 vs 우클릭 컨텍스트 메뉴.
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setupPopover()
        installClickOutsideMonitor()

        print("✅ [MenuBar] NSPopover 기반 메뉴바 설정 완료")
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = makePopoverContentController()
        self.popover = popover
    }

    /// 팝오버 콘텐츠(SwiftUI)를 새로 만들어 반환한다.
    ///
    /// NSPopover는 `contentViewController`를 재사용하므로, 한 번 만든 호스팅 컨트롤러를
    /// 그대로 다시 `show()` 하면 SwiftUI `.onAppear`가 재호출되지 않는다. 그 결과
    /// `PopoverViewModel`이 최초 로드(앱 시작 직후) 시점의 stale 메모를 계속 보여주고,
    /// 그 뒤 추가·편집한 메모가 메뉴바 리스트에 나타나지 않았다.
    /// → openPopover()에서 매 표시 직전 이 컨트롤러를 새로 주입해 항상 fresh reload되게 한다.
    private func makePopoverContentController() -> NSViewController {
        // 루트에 weak self로 dismiss 주입 — 선택/취소 시 팝오버 닫기.
        let rootView = MenuBarPopoverView(dismiss: { [weak self] in
            self?.closePopover()
        })
        return NSHostingController(rootView: rootView)
    }

    /// 팝오버 밖 클릭 감지 → 자동 닫기 (behavior .transient로도 처리되지만 보조).
    private func installClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    // MARK: - Actions

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        // 우클릭 / Control+클릭 → 보조 컨텍스트 메뉴 (빠른 액션만)
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let popover, let button = statusItem?.button else { return }
        // 매 표시마다 콘텐츠를 새로 주입 → SwiftUI .onAppear 재호출 → 최신 메모 reload.
        // (NSPopover의 contentViewController 재사용으로 인한 stale 리스트 문제 해결)
        popover.contentViewController = makePopoverContentController()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 팝오버 윈도우를 key window로 만들어 TextField가 바로 입력 받도록.
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover?.performClose(nil)
    }

    /// 우클릭 시 표시되는 경량 메뉴 (팝오버 대신 간단 액션만 노출).
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("New Memo", comment: "Menu: new memo"),
                     action: #selector(newMemoAction), keyEquivalent: "n")
        menu.addItem(withTitle: NSLocalizedString("Clipboard History", comment: "Menu: clipboard history"),
                     action: #selector(clipboardHistoryAction), keyEquivalent: "h")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("iCloud Backup", comment: "Menu: iCloud backup"),
                     action: #selector(cloudBackupAction), keyEquivalent: "b")
        menu.addItem(withTitle: NSLocalizedString("Preferences…", comment: "Menu: preferences"),
                     action: #selector(settingsAction), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Show Onboarding", comment: "Menu: show onboarding"),
                     action: #selector(onboardingAction), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit ClipKeyboard", comment: "Menu: quit"),
                     action: #selector(quitAction), keyEquivalent: "q")
        for item in menu.items { item.target = self }

        // popUpMenu 호출 — 버튼 아래에 표시.
        if let button = statusItem?.button {
            menu.popUp(positioning: nil,
                      at: NSPoint(x: 0, y: button.bounds.height + 4),
                      in: button)
        }
    }

    @objc private func newMemoAction() {
        NotificationCenter.default.post(name: .showNewMemo, object: nil)
        activateApp()
    }

    @objc private func clipboardHistoryAction() {
        NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
        activateApp()
    }

    @objc private func cloudBackupAction() {
        NotificationCenter.default.post(name: .showCloudBackup, object: nil)
        activateApp()
    }

    @objc private func settingsAction() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
        activateApp()
    }

    @objc private func onboardingAction() {
        WindowManager.shared.openOnboardingWindow()
        activateApp()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 전역 단축키(⌃⌥⇧V)로 플로팅 패널을 연다. v4.2부터는 popover 대신
    /// non-activating NSPanel을 사용해 전경 앱 포커스를 뺏지 않는다.
    func showFloatingPanelFromHotkey() {
        MemoFloatingPanelController.shared.toggle()
    }
}
