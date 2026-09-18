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
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
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
