//
//  WindowManager.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

class WindowManager {
    static let shared = WindowManager()

    // 윈도우 참조를 유지하여 메모리 해제 문제 방지
    private var windows: [String: NSWindow] = [:]
    private var delegates: [String: WindowDelegate] = [:]

    private init() {
        setupNotifications()
        // 자동 온보딩 표시 제거 — 앱 시작 시 바로 메모(더미데이터)를 만난다.
        // 온보딩은 Help 메뉴 "Show Onboarding"에서 수동으로만 열 수 있다.
    }

    // MARK: - Onboarding

    func openOnboardingWindow() {
        print("👋 [WindowManager] 온보딩 윈도우 열기")

        let windowKey = "onboarding"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
        }

        let contentView = OnboardingView {
            // 온보딩 완료 후
            print("✅ [WindowManager] 온보딩 완료")

            // 온보딩 윈도우 닫기
            if let window = self.windows[windowKey] {
                window.close()
            }
        }
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 520, height: 620)

        window.center()
        window.contentViewController = hostingController
        window.title = NSLocalizedString("Welcome to ClipKeyboard", comment: "Onboarding window title")
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 온보딩 윈도우 생성 완료")
    }

    private func setupNotifications() {
        observe(.openMemoListWindow) { $0.openMemoListWindow() }
        observe(.showMemoList) { $0.openMemoListWindow() }
        observe(.showNewMemo) { $0.openNewMemoWindow() }
        observe(.showClipboardHistory) { $0.openClipboardHistoryWindow() }
        observe(.showSettings) { $0.openSettingsWindow() }
        observe(.showCloudBackup) { $0.openCloudBackupWindow() }
    }

    private func observe(_ name: NSNotification.Name, handler: @escaping (WindowManager) -> Void) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            handler(self)
        }
    }

    func openMemoListWindow() {
        openWindow(
            key: "memo-list",
            title: NSLocalizedString("Memo List", comment: "Menu: memo list"),
            size: NSSize(width: 420, height: 560),
            minSize: NSSize(width: 360, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            autosaveName: "MemoListWindow",
            content: MemoListView()
        )
    }

    // MARK: - Common Window Factory

    /// 윈도우 생성 공통 헬퍼 — 기존 윈도우가 있으면 포커스, 없으면 새로 생성.
    /// - Note: v4.1부터 기본 styleMask에 .resizable 포함. 이전엔 고정 크기 창이
    ///   콘텐츠 intrinsic size보다 작으면 아래쪽이 잘리던 문제 있었음.
    private func openWindow<Content: View>(
        key: String,
        title: String,
        size: NSSize,
        minSize: NSSize? = nil,
        styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable],
        autosaveName: String? = nil,
        content: Content
    ) {
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스: \(key)")
            return
        }

        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.center()
        if let autosaveName { window.setFrameAutosaveName(autosaveName) }
        window.contentViewController = hostingController
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier(key)
        window.level = .floating

        // 최소 크기 — 사용자가 너무 작게 줄여 콘텐츠가 잘리지 않도록.
        if let minSize {
            window.minSize = minSize
        }

        let delegate = WindowDelegate(windowKey: key, manager: self)
        window.delegate = delegate
        windows[key] = window
        delegates[key] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ [WindowManager] 새 윈도우 생성 완료: \(key) (size=\(Int(size.width))x\(Int(size.height)))")
    }

    // 윈도우가 닫힐 때 호출
    fileprivate func removeWindow(key: String) {
        print("🗑️ [WindowManager] removeWindow - 참조 제거 시작: \(key)")

        // 안전하게 참조 제거 (이미 해제된 객체에 접근하지 않음)
        let hadWindow = windows[key] != nil
        let hadDelegate = delegates[key] != nil

        print("   └─ 윈도우 존재: \(hadWindow)")
        print("   └─ 델리게이트 존재: \(hadDelegate)")

        windows.removeValue(forKey: key)
        print("   └─ windows에서 제거 완료")

        delegates.removeValue(forKey: key)
        print("   └─ delegates에서 제거 완료")

        print("✅ [WindowManager] removeWindow - 완료: \(key)")
        print("   └─ 남은 윈도우 수: \(windows.count)")
    }

    func openNewMemoWindow() {
        openWindow(
            key: "new-memo",
            title: NSLocalizedString("New Memo", comment: "Menu: new memo"),
            size: NSSize(width: 560, height: 700),
            minSize: NSSize(width: 480, height: 560),
            content: MemoAddView()
        )
    }

    func openClipboardHistoryWindow() {
        openWindow(
            key: "clipboard-history",
            title: NSLocalizedString("Clipboard History", comment: "Menu: clipboard history"),
            size: NSSize(width: 620, height: 560),
            minSize: NSSize(width: 480, height: 420),
            content: ClipboardHistoryView()
        )
    }

    func openSettingsWindow() {
        openWindow(
            key: "settings",
            title: NSLocalizedString("Preferences", comment: "Settings window title"),
            size: NSSize(width: 560, height: 480),
            minSize: NSSize(width: 520, height: 400),
            content: MacPreferencesView()
        )
    }

    func openCloudBackupWindow() {
        openWindow(
            key: "cloud-backup",
            title: NSLocalizedString("iCloud Backup", comment: "Menu: iCloud backup"),
            size: NSSize(width: 600, height: 680),
            minSize: NSSize(width: 520, height: 560),
            content: CloudBackupView()
        )
    }
}

// MARK: - Window Delegate

class WindowDelegate: NSObject, NSWindowDelegate {
    let windowKey: String
    weak var manager: WindowManager?

    init(windowKey: String, manager: WindowManager) {
        self.windowKey = windowKey
        self.manager = manager
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🔒 [WindowDelegate] windowShouldClose - 윈도우 닫기 요청: \(windowKey)")

        // 윈도우를 즉시 닫지 않고, 뷰를 안전하게 정리한 후 숨김
        DispatchQueue.main.async {
            print("   └─ contentViewController 정리 시작")

            // contentViewController를 먼저 정리
            if let viewController = sender.contentViewController {
                viewController.view.removeFromSuperview()
                sender.contentViewController = nil
                print("      └─ contentViewController 제거 완료")
            }

            // 짧은 지연 후 참조 제거 및 윈도우 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                print("   └─ 딕셔너리에서 참조 제거")
                self?.manager?.removeWindow(key: self?.windowKey ?? "")

                // delegate를 nil로 설정하여 순환 참조 방지
                print("   └─ delegate 제거")
                sender.delegate = nil

                // 윈도우 숨기기 (close 대신 orderOut 사용)
                sender.orderOut(nil)
                print("✅ [WindowDelegate] 윈도우 숨김 완료")
            }
        }

        print("⏸️ [WindowDelegate] windowShouldClose - 닫기 보류 (비동기 처리)")
        return false  // 일단 닫지 않고, 나중에 orderOut으로 숨김
    }

    func windowWillClose(_ notification: Notification) {
        print("🗑️ [WindowDelegate] windowWillClose - 윈도우 닫힘 시작: \(windowKey)")
        print("✅ [WindowDelegate] windowWillClose - 완료 (참조는 이미 제거됨)")
    }
}
