//
//  DirectPasteHelper.swift
//  ClipKeyboard.tap
//
//  Simulates ⌘V to paste the current clipboard into the frontmost app.
//  Requires Accessibility permission (handled separately via AXIsProcessTrustedWithOptions).
//

import AppKit
import Carbon.HIToolbox

enum DirectPasteHelper {

    /// 세션당 권한 안내 알림을 1회만 띄우기 위한 플래그 (매 붙여넣기 실패마다 나가지 않도록).
    private static var didPromptForPermissionThisSession = false

    /// 전경 앱으로 ⌘V keystroke를 발사한다.
    /// - Returns: 권한이 있어 실제로 ⌘V를 전송했으면 true, 권한이 없어 건너뛰었으면 false.
    /// - Note: 권한이 없으면 조용히 실패하지 않고, 세션당 1회 권한 안내를 표시한다.
    ///   (메모는 이미 클립보드에 복사된 상태라 사용자가 수동 ⌘V로도 붙여넣을 수 있다.)
    @discardableResult
    static func pasteToFrontmostApp() -> Bool {
        guard hasAccessibilityPermission() else {
            print("⚠️ [Paste] Accessibility 권한 없음 — 자동 붙여넣기 생략, 권한 안내 표시")
            promptForAccessibilityPermissionOnce()
            return false
        }

        // ⌘V down/up
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)

        print("📋 [Paste] ⌘V 전송 완료")
        return true
    }

    /// 자동 붙여넣기에 필요한 손쉬운 사용 권한이 없을 때, 세션당 1회 안내 알림을 띄우고
    /// 시스템 설정의 "손쉬운 사용" 패널을 연다.
    private static func promptForAccessibilityPermissionOnce() {
        guard !didPromptForPermissionThisSession else { return }
        didPromptForPermissionThisSession = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("접근성 권한 필요", comment: "macOS alert title: accessibility permission required")
            alert.informativeText = NSLocalizedString("단축어를 탭하면 즉시 붙여넣으려면 손쉬운 사용 권한이 필요합니다.\n\n시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용에서 ClipKeyboard를 켜 주세요.", comment: "macOS alert body: accessibility permission needed for tap-to-paste")
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("시스템 설정 열기", comment: "Button: open system settings"))
            alert.addButton(withTitle: NSLocalizedString("나중에", comment: "Later button"))

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    static func hasAccessibilityPermission() -> Bool {
        // prompt=false: 권한 확인만 하고 시스템 prompt는 띄우지 않음
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 권한 요청 시스템 대화상자를 띄운다 (Preferences에서 "Grant Access" 버튼 눌렀을 때).
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
