//
//  AppNotification.swift
//  ClipKeyboard
//
//  자동 생성 가능 — 정적 Notification 이름 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

extension Notification.Name {
    static let addTextEntry = Notification.Name("addTextEntry")
    static let comboCompleted = Notification.Name("comboCompleted")
    static let comboItemExecuted = Notification.Name("comboItemExecuted")
    /// iCloud에서 데이터를 복원(자동/수동)한 뒤 열려 있는 화면을 새로고침.
    static let dataRestored = Notification.Name("dataRestored")
    /// 기존 사용자가 데모 샘플 체험을 수락해 샘플이 삽입됨 → 리스트 리로드 트리거
    static let demoSamplesInserted = Notification.Name("demoSamplesInserted")
    static let draftsChanged = Notification.Name("draftsChanged")
    static let filterChanged = Notification.Name("filterChanged")
    static let memoDataChanged = Notification.Name("MemoDataChanged")
    static let openMainAppPaywall = Notification.Name("openMainAppPaywall")
    /// 빠른 메모(Inbox) 보관함이 변경됨(추가/삭제/승격) → 열려 있는 화면·배지 새로고침.
    static let quickNotesChanged = Notification.Name("quickNotesChanged")
    static let openMemoListWindow = Notification.Name("openMemoListWindow")
    /// 빠른 메모(Inbox) 보관함 화면을 연다(App Intent·Control Center·딥링크에서 트리거).
    static let openQuickNoteInbox = Notification.Name("openQuickNoteInbox")
    /// 빠른 메모 입력 시트를 연다(Control Center 컨트롤의 clipkeyboard://quicknote 딥링크).
    static let openQuickNoteAdd = Notification.Name("openQuickNoteAdd")
    static let reviewTriggerClipSaved = Notification.Name("reviewTriggerClipSaved")
    static let reviewTriggerComboCompleted = Notification.Name("reviewTriggerComboCompleted")
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
    static let showCloudBackup = Notification.Name("showCloudBackup")
    static let showMemoList = Notification.Name("showMemoList")
    static let showNewMemo = Notification.Name("showNewMemo")
    static let showPaywall = Notification.Name("showPaywall")
    static let showSettings = Notification.Name("showSettings")
    static let showTemplateInput = Notification.Name("showTemplateInput")
    static let templateInputComplete = Notification.Name("templateInputComplete")
}
