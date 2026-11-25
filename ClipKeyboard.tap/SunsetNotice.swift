//
//  SunsetNotice.swift
//  ClipKeyboard.tap
//
//  **이 맥 앱(com.ysoup.TokenMemo-tap)은 곧 App Store 에서 내려간다.**
//
//  켤 때마다 맨 먼저 알리고, 앞으로 쓸 곳(클립키보드)과 결제한 사람이 연락할 곳을 함께 적는다.
//  닫으면 평소대로 쓸 수 있다, 옮겨 가기 전까지 쓰던 것을 잃지 않게.
//

import SwiftUI
import AppKit
import ServiceManagement

enum SunsetNotice {
    static let contactEmail = "leeo@kakao.com"
    /// 앞으로 쓸 앱, 클립키보드 (iPhone · Mac 같은 레코드).
    static let clipKeyboardURL = URL(string: "macappstore://apps.apple.com/app/id1543660502")!

    private static var window: NSWindow?
    private static var launchObserver: NSObjectProtocol?

    // MARK: - 클립키보드가 켜지면 물러난다

    /// 두 앱이 함께 뜨면 메뉴 막대 아이콘이 둘, 같은 전역 단축키(⌃⇧V)를 서로 잡는다.
    /// 클립키보드가 이미 떠 있으면 바로, 나중에 뜨면 그때 물러난다. 쓰던 설정과 산 사람 표시는
    /// 물러나기 전에 넘긴다(`MacHandoff`).
    @MainActor
    static func watchForClipKeyboard() {
        if MacHandoff.isNewAppRunning { retire(); return }
        guard launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == MacHandoff.newBundleID else { return }
            Task { @MainActor in retire() }
        }
    }

    /// 넘겨주고, 로그인 때 다시 뜨지 않게 하고, 끈다.
    @MainActor
    static func retire() {
        MacHandoff.write(paid: MacPlan.shared.isPaidDownloadOwner)
        try? SMAppService.mainApp.unregister()
        print("👋 [SunsetNotice] 클립키보드가 떠 있어 물러난다")
        NSApp.terminate(nil)
    }

    /// 클립키보드가 깔려 있으면 열고(그러면 이 앱은 물러난다), 없으면 App Store 를 연다.
    static func openClipKeyboard() {
        if let url = MacHandoff.newAppURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(clipKeyboardURL)
        }
    }

    /// 켤 때마다 맨 앞에 띄운다. 이미 떠 있으면 앞으로만 가져온다.
    @MainActor
    static func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = NSLocalizedString("클립키보드로 옮겨 주세요", comment: "Sunset notice window title")
        window.contentViewController = NSHostingController(rootView: SunsetNoticeView { window.close() })
        window.level = .floating
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SunsetNoticeView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("이 앱은 곧 App Store 에서 삭제됩니다")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("앞으로는 클립키보드 맥 앱을 이용해 주세요.")
                .multilineTextAlignment(.center)
            Text("쓰던 단축어와 설정, 구매하신 기능이 클립키보드로 그대로 이어져요.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(MacHandoff.newAppURL == nil ? String(localized: "클립키보드 받기") : String(localized: "클립키보드 열기")) {
                SunsetNotice.openClipKeyboard()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

            Divider().padding(.vertical, 4)

            Text("문제가 있으면 아래 메일로 연락해 주세요.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(verbatim: SunsetNotice.contactEmail)
                .font(.body.monospaced())
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button("메일 보내기") {
                    if let url = URL(string: "mailto:\(SunsetNotice.contactEmail)") { NSWorkspace.shared.open(url) }
                }
                Button("확인", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(32)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
