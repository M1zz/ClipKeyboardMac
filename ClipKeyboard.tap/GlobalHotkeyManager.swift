//
//  GlobalHotkeyManager.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import AppKit
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func registerGlobalHotkey() {
        // Carbon RegisterEventHotKey 는 손쉬운 사용 권한 없이 동작한다.
        // (권한이 필요한 건 다른 앱에 키 이벤트를 '주입'할 때뿐이고,
        //  이 앱은 그런 동작을 하지 않는다.)

        // v4.2: ⌃⇧V (3-key 조합). Mac에서 Control+Shift 계열은 표준
        // 단축키가 거의 없어 BetterTouchTool/Raycast/Maccy/Alfred 등과
        // 충돌 가능성이 낮음. V는 "Value"/"Variable"을 연상.
        let keyCode: UInt32 = 9 // V key
        let modifiers: UInt32 = UInt32(controlKey | shiftKey)
        let hotKeyID = buildHotKeyID()

        guard installHotKeyHandler() else { return }
        registerHotKey(id: hotKeyID, keyCode: keyCode, modifiers: modifiers)
    }

    private func buildHotKeyID() -> EventHotKeyID {
        var id = EventHotKeyID()
        id.signature = OSType(("T" as Character).asciiValue! << 24 |
                              ("M" as Character).asciiValue! << 16 |
                              ("H" as Character).asciiValue! << 8 |
                              ("K" as Character).asciiValue!)
        id.id = 1
        return id
    }

    private func installHotKeyHandler() -> Bool {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        let handler: EventHandlerUPP = { (_, _, _) -> OSStatus in
            print("🔥 [Global Hotkey] ⌃⇧V 감지!")
            DispatchQueue.main.async {
                GlobalHotkeyManager.shared.activateApp()
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)

        if status == noErr {
            self.eventHandler = handlerRef
            print("✅ [Global Hotkey] 이벤트 핸들러 등록 성공")
            return true
        } else {
            print("❌ [Global Hotkey] 이벤트 핸들러 등록 실패: \(status)")
            return false
        }
    }

    private func registerHotKey(id: EventHotKeyID, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRefVar: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRefVar)

        if status == noErr {
            self.hotKeyRef = hotKeyRefVar
            print("✅ [Global Hotkey] 전역 단축키 등록 성공 (⌃⇧V)")
            print("💡 [Global Hotkey] 이제 어디서나 ⌃⇧V로 메모 패널을 띄울 수 있습니다.")
        } else {
            print("❌ [Global Hotkey] 전역 단축키 등록 실패: \(status)")
        }
    }

    func unregisterGlobalHotkey() {
        // 핫키를 먼저 해제
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                print("🔓 [Global Hotkey] 전역 단축키 해제 성공")
            } else {
                print("⚠️ [Global Hotkey] 전역 단축키 해제 실패: \(status)")
            }
            self.hotKeyRef = nil
        }

        // 이벤트 핸들러 해제
        if let eventHandler = eventHandler {
            let status = RemoveEventHandler(eventHandler)
            if status == noErr {
                print("🔓 [Global Hotkey] 이벤트 핸들러 해제 성공")
            } else {
                print("⚠️ [Global Hotkey] 이벤트 핸들러 해제 실패: \(status)")
            }
            self.eventHandler = nil
        }
    }

    private func activateApp() {
        // v4.2: non-activating 플로팅 패널로 띄워 포커스를 뺏지 않음.
        // 사용자가 다른 앱에서 텍스트 입력 중이더라도 커서·포커스 유지 —
        // 메모를 고르면 클립보드에 담기고, 커서가 그대로이므로 ⌘V로 바로 붙여넣는다.
        DispatchQueue.main.async {
            MemoFloatingPanelController.shared.toggle()
        }
        print("✅ [Global Hotkey] 플로팅 메모 패널 오픈")
    }

    deinit {
        unregisterGlobalHotkey()
    }
}
