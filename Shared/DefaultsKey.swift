//
//  DefaultsKey.swift
//  ClipKeyboard
//
//  자동 생성 가능 — 정적 UserDefaults 키 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

enum DefaultsKey {
    static let autoBackupEnabled = "autoBackupEnabled"
    static let categoryBadgeNudgeDismissed = "categoryBadgeNudgeDismissed"
    static let categoryBadgeVisible = "categoryBadgeVisible"
    static let categoryFeatureEnabledV1 = "category.feature.enabled.v1"
    static let comboModelUnifyMigratedV1 = "comboModelUnifyMigrated_v1"
    static let didRemoveAds = "didRemoveAds"
    static let enabledBuiltInCategoriesV1 = "enabledBuiltInCategories_v1"
    static let appLaunchCount = "appLaunchCount"
    static let entries = "entries"
    static let fontSize = "fontSize"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// What's-New(새 기능) 시트를 마지막으로 보여준 기능 버전. 다르면 업데이트 유저에게 1회 노출.
    static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
    static let hiddenCategoryTabsV1 = "hiddenCategoryTabs_v1"
    static let kbBeaconLastUse = "kb.beacon.lastUse"
    static let kbBeaconPendingCount = "kb.beacon.pendingCount"
    static let keyboardExtensionDidLoad = "keyboard_extension_did_load"
    static let keyboardKoreanEnabled = "keyboardKoreanEnabled"
    static let keyboardPasteCount = "keyboard_paste_count"
    static let keyboardSecurePinHash = "keyboard_secure_pin_hash"
    static let keyboardTypingLang = "keyboardTypingLang"
    static let koreanEnabledMigratedV1 = "koreanEnabledMigrated_v1"
    static let lastBackupDate = "lastBackupDate"
    static let memoCopyCount = "memoCopyCount"
    /// '순서 바꾸기'로 지정한 수동 순서(메모 id 문자열 배열). App Group — 키보드 익스텐션도 이 순서를 따른다.
    static let memoManualOrderV1 = "memoManualOrder_v1"
    /// 수동 순서 활성 여부. true면 즐겨찾기 상단 고정 대신 저장된 순서 그대로 정렬.
    static let memoManualOrderActiveV1 = "memoManualOrderActive_v1"
    static let onboarding = "onboarding"
    static let pasteTipDismissed = "pasteTipDismissed"
    /// 클립보드 화면 첫 진입 시 붙여넣기 허용 안내 알림을 한 번 띄웠는지 여부.
    static let pastePermissionPromptShownV1 = "pastePermissionPromptShown_v1"
    /// Siri/단축어 OpenQuickNoteInboxIntent가 켠 "보관함 열기" 보류 플래그(앱 활성화/onAppear 시 소비).
    static let pendingOpenQuickNoteInbox = "pendingOpenQuickNoteInbox"
    /// Control Center 빠른 메모 컨트롤·quicknote 딥링크가 켠 "빠른 메모 입력 시트 열기" 보류 플래그.
    /// 위젯 타겟은 같은 문자열 리터럴 사용(QuickNoteControl.swift).
    static let pendingQuickNoteAdd = "pendingQuickNoteAdd"
    static let proValueNudgeDismissedV1 = "proValueNudgeDismissed_v1"
    static let recentEmojis = "recentEmojis"
    static let recentlyUsedCategories = "recentlyUsedCategories"
    static let reviewBannerDismissed = "review_banner_dismissed"
    static let reviewBannerLaterDate = "review_banner_later_date"
    static let sampleTemplateFlagsMigratedV1 = "sampleTemplateFlagsMigrated_v1"
    static let secureMemoEncryptionMigratedV1 = "secureMemoEncryptionMigrated_v1"
    static let showVisualCues = "showVisualCues"
    static let useCaseSelection = "useCaseSelection"
    static let userCategoryColorsV1 = "userCategoryColors_v1"
    static let userCategoryIconsV1 = "userCategoryIcons_v1"
    static let userDefinedCategoriesV1 = "userDefinedCategories_v1"
    static let visualCuesMigratedV1 = "visualCuesMigrated_v1"
    /// v4.3.6 "메모 심볼 기본 숨김" 1회 리셋 플래그 (standard UD)
    static let visualCuesDefaultOffV436 = "visualCuesDefaultOff_v436"

    // MARK: - Pro / 그랜드파더링 / 템플릿 (iOS·macOS 공유 — 이전엔 타겟별 중복 정의)
    static let proStatus = "clipkeyboard_is_pro"
    static let wasProAtV3 = "clipkeyboard_was_pro_at_v3"
    static let existingFreeUser = "clipkeyboard_existing_free_user"
    static let v4GraceMemos = "clipkeyboard_v4_grace_memos"
    static let v4GraceBannerDismissed = "clipkeyboard_v4_grace_banner_dismissed"
    static let v4GrandfatherBootstrapDone = "clipkeyboard_v4_grandfather_bootstrap_done"
    static let trialStartedAt = "clipkeyboard_trial_started_at"
    static let trialLastSeen = "clipkeyboard_trial_last_seen"
    static let userTimezone = "clipkeyboard_user_timezone"
    static let userCurrency = "clipkeyboard_user_currency"

    /// 마스터(개발자) 모드 — 설정 > 앱 정보의 버전 행 7번 탭으로 토글 (standard UD)
    static let masterModeEnabled = "masterModeEnabled"

    // MARK: - 피드백 넛지
    /// 피드백 넛지 "다시 보지 않기" — 구버전 영구 옵트아웃 Bool(마이그레이션용으로만 읽음, standard UD)
    static let feedbackNudgeOptOut = "feedbackNudgeOptOut"
    /// 피드백 넛지 "다시 보지 않기"를 누른 시각(timeIntervalSince1970) — 6개월 유예 후 재노출 (standard UD)
    static let feedbackNudgeOptOutDate = "feedbackNudgeOptOutDate"
    /// 피드백 넛지를 마지막으로 보여준 실행 횟수 (standard UD)
    static let feedbackNudgeLastShownLaunch = "feedbackNudgeLastShownLaunch"

    // MARK: - Apple Intelligence (온디바이스 AI, iOS 26+)
    /// AI 클립보드 재분류 토글 (App Group, 기본 ON — 지원 기기에서만 동작)
    static let aiClassificationEnabled = "aiClassificationEnabled"
    /// 붙여넣을 앱 예측 → 단축 액션 제안 토글 (App Group, 기본 ON)
    static let aiActionSuggestionsEnabled = "aiActionSuggestionsEnabled"
    /// 기본 번역 대상 언어 (AITranslationLanguage rawValue, App Group)
    static let aiTranslationTargetLang = "aiTranslationTargetLang"

    // MARK: - 메모 실시간 동기화 (CKSyncEngine)
    static let memoSyncEnabled = "memoSyncEnabled"
    static let syncEngineState = "sync.engine.state"
    static let syncShadow = "sync.shadow"
    static let syncTombstones = "sync.tombstones"

    // MARK: - 리스트 배경 이미지
    /// 선택된 배경 이미지 에셋 이름 (빈 문자열 = 배경 없음, App Group) — 모든 탭 기본값
    static let listBackgroundImageV1 = "listBackgroundImage_v1"
    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름] ("" = 이 탭만 배경 없음, App Group)
    static let listBackgroundPerTabV1 = "listBackgroundPerTab_v1"
    /// "새 배경 써보시겠어요?" 1회 제안을 이미 답했는지 (App Group)
    static let backgroundOfferResolvedV1 = "backgroundOfferResolved_v1"
}
