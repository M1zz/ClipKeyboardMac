//
//  SunsetNotice.swift
//  ClipKeyboard.tap
//
//  **이 맥 앱(com.ysoup.TokenMemo-tap)은 곧 App Store 에서 내려간다.**
//
//  켤 때마다 맨 먼저 알리고, 앞으로 쓸 곳(클립키보드)과 결제한 사람이 연락할 곳을 함께 적는다.
//  닫으면 평소대로 쓸 수 있다 — 옮겨 가기 전까지 쓰던 것을 잃지 않게.
//

import SwiftUI
import AppKit

enum SunsetNotice {
    static let contactEmail = "leeo@kakao.com"
    /// 앞으로 쓸 앱 — 클립키보드 (iPhone · Mac 같은 레코드).
    static let clipKeyboardURL = URL(string: "macappstore://apps.apple.com/app/id1543660502")!

    private static var window: NSWindow?

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

            Button("클립키보드 받기") {
                NSWorkspace.shared.open(SunsetNotice.clipKeyboardURL)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

            Divider().padding(.vertical, 4)

            Text("유료로 결제하신 분은 아래 메일로 연락해 주세요.")
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
