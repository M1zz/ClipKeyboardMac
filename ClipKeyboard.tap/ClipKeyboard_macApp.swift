//
//  ClipKeyboard_macApp.swift
//  ClipKeyboard.tap
//
//  Created by hyunho lee on 11/28/25.
//

import SwiftUI
import CoreSpotlight
import LeeoKit

@main
struct ClipKeyboard_macApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // 클립키보드 전용 메뉴
            // v4.2: 모든 단축키를 ⌃⇧ (Control+Shift) + 영문자 3-key 조합으로
            // 통일. Mac에서 Control+Shift 계열은 거의 표준 바인딩이 없어
            // 타 유틸(Raycast/Maccy/Alfred 등)과 충돌 가능성이 낮음.
            CommandMenu(NSLocalizedString("ClipKeyboard", comment: "App menu name")) {
                Button(NSLocalizedString("Quick Paste Panel", comment: "Menu: floating panel")) {
                    MemoFloatingPanelController.shared.toggle()
                }
                .keyboardShortcut("v", modifiers: [.control, .shift])

                Button(NSLocalizedString("Memo List", comment: "Menu: memo list")) {
                    NotificationCenter.default.post(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.control, .shift])

                Button(NSLocalizedString("New Memo", comment: "Menu: new memo")) {
                    NotificationCenter.default.post(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.control, .shift])

                Divider()

                Button(NSLocalizedString("Clipboard History", comment: "Menu: clipboard history")) {
                    NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.control, .shift])

                Divider()

                Button(NSLocalizedString("iCloud Backup", comment: "Menu: iCloud backup")) {
                    NotificationCenter.default.post(name: .showCloudBackup, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.control, .shift])

                Button(NSLocalizedString("Preferences…", comment: "Menu: preferences")) {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("Show Onboarding", comment: "Menu: show onboarding")) {
                    WindowManager.shared.openOnboardingWindow()
                }

                Button(NSLocalizedString("ClipKeyboard Help", comment: "Menu: help")) {
                    if let url = URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

// App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // 스토어 스크린샷 촬영 — iCloud·통계·클립보드 감시를 하나도 세우지 않고 화면 하나만 연다.
        if MacShotMode.isOn {
            MacShotMode.launch()
            return
        }
        #endif
        print("🚀 [APP] ClipKeyboard 시작")

        // ⚠️ 무엇보다 먼저. 동기화 엔진도, 백업 자동 복원도 서기 전에 비워야 한다
        //    (엔진이 서면 옛 기억이 되살아난다 - MacSyncReset 주석).
        let didReset = MacSyncReset.applyPendingResetIfNeeded()
        AppLog.info(.launch, "시작 (reset 적용=\(didReset))")

        // LeeoKit 사용량 트래커 — 리뷰 요청 게이팅에 쓰인다.
        _ = LeeoEngagement.shared.registerLaunch()

        // 기본 창 숨기기 (메뉴바 앱으로 동작)
        NSApp.setActivationPolicy(.accessory)

        // 메뉴바 아이콘 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MenuBarManager.shared.setupMenuBar()
        }

        // 전역 핫키 등록
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            GlobalHotkeyManager.shared.registerGlobalHotkey()
        }

        // WindowManager 초기화 (알림 리스너 등록)
        _ = WindowManager.shared

        // 클립보드 모니터링 시작
        ClipboardMonitorService.shared.startMonitoring()

        // Spotlight 에서 어느 나라 이름으로 검색해도 앱이 나오게 한다 (MacSpotlightIndexer 주석 참고)
        MacSpotlightIndexer.indexAppNames()

        // 아이폰의 변경 알림(푸시)을 받는다.
        // ⚠️ 이게 없으면 맥은 **실행할 때와 앱이 활성화될 때만** 받아온다. 메뉴바 앱이라
        //    ⌃⇧V 패널만 쓰면 앱이 활성화되지 않아, 아이폰에서 지운 단축어가 계속 남아 보였다.
        //    사용자에게 묻는 권한이 아니다(알림을 띄우지 않는 조용한 푸시 — CloudKit 전용).
        NSApp.registerForRemoteNotifications()

        // 원격 킬스위치 갱신 — 플래그 캐시는 **기기별**(App Group)이라 맥도 직접 받아와야 한다.
        // 안 부르면 맥은 영원히 기본값(전부 켬)이라, 아이폰만 꺼지고 맥은 계속 올린다.
        // 실패해도 조용히 넘어가고 캐시로 계속 동작한다(가용성 우선).
        Task { @MainActor in RemoteFlagsService.shared.refreshInBackground() }

        // 익명 사용 통계 - FeedbackHub 로 설치 스냅샷 · 오늘의 활동을 보낸다(MacUsageReporting 주석).
        MacUsageReporting.reportLaunch()

        // iCloud 자동 복원: 로컬이 비어있으면 아이폰 백업을 시작 시 가져온다.
        // (덮어쓸 로컬 데이터가 없을 때만 동작 — 사용자 데이터 보호)
        // 복원이 끝난 뒤에도 여전히 비어있으면(맥 단독 신규 유저) 더미를 시드한다.
        Task {
            // 방금 비운 실행에서는 백업 자동 복원·예시 심기를 건너뛴다. 비운 자리는
            // 동기화가 채워야 하고, 여기서 백업을 덮어쓰면 무엇이 들어왔는지 알 수 없다.
            if !didReset {
                await CloudKitBackupService.shared.autoRestoreIfLocalEmpty()
                await MainActor.run { MacSampleSeeder.seedIfNeeded() }
            }
            // 첫 부팅 부트스트랩(autoRestore) 이후에는 실시간 동기화 엔진이 인계한다.
            await MainActor.run { MemoSyncEngine.shared.startIfEnabled() }

            // iCloud 안에 무엇이 들어 있는지 시작할 때 한 번 시스템 로그에 남긴다.
            // ⚠️ 화면(환경설정 ▸ 동기화)에도 같은 것이 있지만, 이쪽은 **다시 켜진 뒤**를 볼 수 있다.
            //    Xcode 로 실행 중이면 앱이 다시 켜지는 순간 콘솔이 끊겨 아무것도 남지 않는다.
            let report = await MacSyncDiagnostics.inspect()
            AppLog.info(.diagnostics, "iCloud 살펴보기\n" + report)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        #if DEBUG
        if MacShotMode.isOn { return }
        #endif
        // 맥앱이 다시 활성화되면 즉시 동기화 — 아이폰의 최신 변경을 바로 반영.
        // (다른 기기에서 토글이 켜져 KV로 전파된 경우 여기서 비로소 시작될 수 있어 start 먼저 호출.)
        MemoSyncEngine.shared.startIfEnabled()
        MemoSyncEngine.shared.syncNow()
    }

    func application(_ application: NSApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📡 [APP] 푸시 등록 완료 (\(deviceToken.count) bytes)")
    }

    func application(_ application: NSApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        // 실패해도 앱은 그대로 돈다 - 활성화될 때와 패널을 열 때 받아오는 길이 남아 있다.
        print("⚠️ [APP] 푸시 등록 실패: \(error.localizedDescription)")
    }

    func application(_ application: NSApplication,
                     didReceiveRemoteNotification userInfo: [String: Any]) {
        MemoSyncEngine.shared.startIfEnabled()
        MemoSyncEngine.shared.syncNow()
    }

    /// Spotlight 에서 앱 이름 항목을 누르면 여기로 온다 - 메뉴바 앱이라 창이 없으니 단축어 목록을 연다.
    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType else { return false }
        NotificationCenter.default.post(name: .showMemoList, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 [APP] 앱 종료 중...")

        // 클립보드 모니터링 중지
        ClipboardMonitorService.shared.stopMonitoring()

        // 메인 스레드에서 동기적으로 핫키 해제
        if Thread.isMainThread {
            GlobalHotkeyManager.shared.unregisterGlobalHotkey()
        } else {
            DispatchQueue.main.sync {
                GlobalHotkeyManager.shared.unregisterGlobalHotkey()
            }
        }

        print("✅ [APP] 정리 작업 완료")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 창을 닫아도 앱은 계속 실행 (메뉴바 앱처럼 동작)
        return false
    }
}

#if DEBUG
/// 앱스토어 스크린샷 촬영 모드 (Debug 빌드에만 있다).
///
///     ClipKeyboard.tap -ClipShotScreen panel|popover|list|clipboard|prefs|backup [-ClipShotSize 460x530]
///                      -ClipShotDemoMemos '<json>' -ClipShotDemoClips '<json>' …
///
/// 단축어·클립보드 기록은 실행 인자(`-ClipShotDemoMemos` · `-ClipShotDemoClips`)로 받은 데모를 보여 주고
/// 디스크에는 쓰지 않는다. 카테고리 구성도 실행 인자(인자 도메인)로 덮어 읽는다 — `scripts/shoot_mac.py`.
/// 이 모드는 **iCloud 를 건드리는 길을 하나도 세우지 않는다** — 동기화 엔진·백업 자동 복원·
///    자동 백업 타이머·푸시 등록·사용 통계·클립보드 감시·예시 심기 전부 건너뛴다.
///    메뉴바 앱이라 창을 열려면 아이콘을 눌러야 하는데, 그 대신 인자로 받은 화면을 곧바로 연다.
enum MacShotMode {
    static var screen: String? { UserDefaults.standard.string(forKey: "ClipShotScreen") }
    static var isOn: Bool { screen != nil }
    /// 실행 인자로 받은 데모 데이터(base64 JSON — memos.data / clipboard.history.data 와 같은 형식).
    /// 촬영은 실제 App Group 의 파일을 읽지도 쓰지도 않는다 (`MemoStore` 의 촬영 모드 분기).
    /// 인자 도메인은 값을 plist 로 읽으려 들어 JSON 을 그대로 못 넘긴다 — base64 로 받는다.
    static func demoData(_ key: String) -> Data? {
        UserDefaults.standard.string(forKey: key).flatMap { Data(base64Encoded: $0) }
    }

    /// 환경설정 창을 열 때 처음 보일 탭 (prefs 화면은 단축키 탭).
    static var initialPrefsTab: Int { screen == "prefs" ? 2 : 0 }

    @MainActor
    static func launch() {
        NSApp.setActivationPolicy(.accessory)
        MenuBarManager.shared.setupMenuBar()
        _ = WindowManager.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            switch screen {
            case "panel": MemoFloatingPanelController.shared.show()
            case "popover": MenuBarManager.shared.debugOpenPopover()
            case "list": WindowManager.shared.openMemoListWindow()
            case "clipboard": WindowManager.shared.openClipboardHistoryWindow()
            case "prefs": WindowManager.shared.openSettingsWindow()
            case "backup": WindowManager.shared.openCloudBackupWindow()
            default: break
            }
            NSApp.activate(ignoringOtherApps: true)
            if let size = UserDefaults.standard.string(forKey: "ClipShotSize")?
                .split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
                        window.setContentSize(NSSize(width: size[0], height: size[1]))
                        window.center()
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { captureAndQuit() }
        }
    }

    /// 자기 창을 그려 표준 출력으로 내보내고 끝낸다 — `CLIPSHOT:<base64 PNG>` 한 줄.
    /// 파일로 쓰지 않는 것은 샌드박스라서다.
    @MainActor
    private static func captureAndQuit() {
        let target = NSApp.windows
            .filter { $0.isVisible && $0.frame.height > 60 && $0.className != "NSStatusBarWindow" }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        if let target, let png = windowPNG(target) {
            FileHandle.standardOutput.write(("CLIPSHOT:" + png.base64EncodedString() + "\n").data(using: .utf8)!)
        } else {
            FileHandle.standardOutput.write("CLIPSHOT:FAIL\n".data(using: .utf8)!)
        }
        exit(0)
    }

    /// 창을 앱 안에서 그려 PNG 로 만든다. 화면을 찍는 게 아니라서 화면 기록 권한이 필요 없다
    /// (권한 없이 `CGWindowListCreateImage` 로 찍으면 내용이 빈 칸으로 나온다).
    /// 제목 막대·신호등까지 나오도록 contentView 의 부모(창 테두리 뷰)를 그린다.
    @MainActor
    private static func windowPNG(_ window: NSWindow) -> Data? {
        guard let content = window.contentView else { return nil }
        // 제목 막대가 있는 창은 테두리 뷰까지, 팝오버·패널은 내용만 (유리 테두리가 제대로 안 그려진다).
        // 환경설정은 선택된 탭의 유리 캡슐이 글자를 덮어 그려져 내용만 그린다.
        let framed = window.styleMask.contains(.titled) && !(window is MemoFloatingPanel)
            && screen != "prefs"
        let view = framed ? (content.superview ?? content) : content
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
