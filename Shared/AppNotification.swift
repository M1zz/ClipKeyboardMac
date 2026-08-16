//
//  AppNotification.swift
//  ClipKeyboard
//
//  자동 생성 가능 - 정적 Notification 이름 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

extension Notification.Name {
    static let addTextEntry = Notification.Name("addTextEntry")
    /// 이미지 단축어를 눌렀다 - **앱 안(무대)에서만** 쓴다.
    /// object = 이미지 파일 이름(String), userInfo["memoId"] = UUID.
    /// (익스텐션에는 이미지를 넣을 자리가 없어 클립보드 복사로 끝난다. 앱 무대에는
    ///  입력창이 우리 것이라 붙여넣은 모습까지 보여줄 수 있다)
    static let addImageEntry = Notification.Name("addImageEntry")
    static let comboCompleted = Notification.Name("comboCompleted")
    static let comboItemExecuted = Notification.Name("comboItemExecuted")
    /// iCloud에서 데이터를 복원(자동/수동)한 뒤 열려 있는 화면을 새로고침.
    static let dataRestored = Notification.Name("dataRestored")
    /// 기존 사용자가 데모 샘플 체험을 수락해 샘플이 삽입됨 → 리스트 리로드 트리거
    static let demoSamplesInserted = Notification.Name("demoSamplesInserted")
    static let draftsChanged = Notification.Name("draftsChanged")
    static let filterChanged = Notification.Name("filterChanged")
    static let memoDataChanged = Notification.Name("MemoDataChanged")
    /// 키보드에서 "전체 접근 허용"이 필요한 동작을 시도했으나 꺼져 있음 → 안내 토스트.
    /// (클립보드 읽기·쓰기는 iOS가 전체 접근 없이는 막는다. 안내가 없으면 조용히 실패한다.)
    static let needsFullAccess = Notification.Name("needsFullAccess")
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
    /// '템플릿으로 만들기' 장이 끝났다 - 무대가 다음 장으로 이어 간다.
    /// ⚠️ 목록은 처음 배우는 중에 스스로 다음 장을 권하지 않기로 되어 있다.
    ///    이 알림이 없으면 그 장에서 흐름이 **그대로 멎는다**.
    static let makeTemplateTutorialFinished = Notification.Name("makeTemplateTutorialFinished")
    /// '템플릿으로 만들기' 장을 목록 화면에서 시작한다 - 그 장만은 고치는 일이라 목록에서 한다.
    static let startMakeTemplateTutorial = Notification.Name("startMakeTemplateTutorial")
    static let showTemplateInput = Notification.Name("showTemplateInput")
    static let templateInputComplete = Notification.Name("templateInputComplete")
}
