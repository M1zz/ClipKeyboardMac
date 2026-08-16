//
//  DefaultsKey.swift
//  ClipKeyboard
//
//  자동 생성 가능 - 정적 UserDefaults 키 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

enum DefaultsKey {
    static let autoBackupEnabled = "autoBackupEnabled"
    static let categoryBadgeNudgeDismissed = "categoryBadgeNudgeDismissed"
    static let categoryFeatureEnabledV1 = "category.feature.enabled.v1"
    static let comboModelUnifyMigratedV1 = "comboModelUnifyMigrated_v1"
    /// 날인·편철·봉인 등 delight 연출과 햅틱의 마스터 스위치. 값이 없으면 켜짐(기본).
    /// App Group - 키보드 익스텐션도 같은 값을 읽어 입력 햅틱을 끈다.
    static let delightEffectsEnabled = "delight.effects.enabled.v1"
    /// 카드가 2초쯤 머물면 제목 아래에 내용이 살며시 맺혔다 사라지는 연출(App Group).
    /// ⚠️ 기본값은 **꺼짐**이다. 목록을 훑는 동안 카드마다 글이 맺혔다 흩어지면 눈이 쉴 곳이
    ///    없다. 보고 싶은 사람은 설정 > 화면과 표시에서 켠다.
    static let contentHintEnabled = "contentHintEnabled"
    static let didRemoveAds = "didRemoveAds"
    /// 칸 추가 상품으로 얻은 추가 단축어 칸수 (App Group, Int).
    /// ⚠️ 키보드 익스텐션은 StoreKit 을 못 보므로 앱이 결제 권한을 여기에 미러링한다.
    static let purchasedExtraSlots = "purchased.extraSlots"
    /// 단축어가 무료 한도 한 칸 앞(9개)에 **처음** 닿은 시각 (App Group, epoch 초).
    /// 반값 제안은 이 시각에서 일주일이 지난 뒤에 뜬다 - 닿자마자 들이밀면 한도를
    /// 미끼로 쓴 것처럼 보이고, 아직 이 앱이 자기에게 필요한지도 모르는 때다.
    static let discountOfferReachedLimitEdgeAt = "discount.offer.reachedLimitEdgeAt"
    /// 반값 제안을 이미 띄운 **기회들**(App Group, `DiscountOfferManager.Occasion.rawValue` 배열).
    /// 기회는 둘뿐이고(설치 직후·한도 한 칸 앞), 각각 한 번씩만 뜬다.
    static let discountOfferShownOccasions = "discount.offer.shownOccasions"
    static let enabledBuiltInCategoriesV1 = "enabledBuiltInCategories_v1"
    /// 앱을 처음 연 날 (standard UD, Date). 리뷰 요청·붙여넣기 안내·반값 제안이 모두 이 값을 본다.
    /// ⚠️ 읽기만 하는 자리에서 값을 쓰지 말 것 - 남의 초기화를 조용히 되돌린다.
    static let appInstallDate = "app_install_date"
    static let appLaunchCount = "appLaunchCount"
    static let entries = "entries"
    static let fontSize = "fontSize"
    /// What's-New(새 기능) 시트를 마지막으로 보여준 기능 버전. 다르면 업데이트 유저에게 1회 노출.
    static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
    static let hiddenCategoryTabsV1 = "hiddenCategoryTabs_v1"
    static let kbBeaconLastUse = "kb.beacon.lastUse"
    static let kbBeaconPendingCount = "kb.beacon.pendingCount"
    /// 키보드 비콘 누적 사용 횟수 (App Group) - flush 때마다 pendingCount를 더한다. 사용 통계 지표용.
    static let kbBeaconTotalCount = "kb.beacon.totalCount"
    /// 앱 **밖에서** `memos.data` 를 고친 시각 (App Group, epoch 초).
    /// ⚠️ 지금은 공유 익스텐션이 찍는다. `memos.data` 는 메인 앱이 통째로 덮어쓰는 파일이라,
    ///    앱이 낡은 목록을 들고 있다가 저장하면 밖에서 넣은 단축어가 **사라진다.**
    ///    앱은 돌아올 때 이 값을 보고 다시 읽는다(`ClipKeyboardListViewModel.onSceneResume`).
    static let memosExternalChangeAt = "memos.externalChangeAt"
    /// 앱이 마지막으로 위 변경을 반영한 시각 (standard UD) - 같은 변경을 두 번 읽지 않기 위한 표식.
    static let memosExternalChangeSeenAt = "memos.externalChangeSeenAt"

    /// 키보드를 쓴 **날짜별** 횟수 (App Group, `"yyyy-MM-dd"` → Int).
    /// ⚠️ pendingCount와 역할이 다르다 - 저쪽엔 "언제"가 없어서, 앱을 2주 만에 열면
    ///    그 2주가 통째로 '앱을 연 날 하루'로 뭉친다. 키보드만 쓰는 사람의 활동일을
    ///    소급해서 복원하려고 날짜를 따로 남긴다. 자세한 건 `KeyboardDayLedger`.
    static let kbBeaconDayCounts = "kb.beacon.dayCounts"
    static let keyboardExtensionDidLoad = "keyboard_extension_did_load"
    static let keyboardKoreanEnabled = "keyboardKoreanEnabled"
    /// 생활 레이어 프리셋(LivingSkin rawValue) - 카드 위에 사는 것. 값이 없으면 `.none`.
    /// ⚠️ 앱 전용이다. 키보드 익스텐션은 메모리 상한 때문에 이 레이어를 그리지 않는다.
    static let livingSkin = "livingSkin.v1"
    /// 단축어 탭이 무엇을 보여주는가 - `SnippetsTabStyle` rawValue("list" / "keyboard").
    /// ⚠️ 기존 사용자는 값이 없으면 **목록**이다. 쓰던 사람의 첫 화면이 업데이트로 바뀌면 안 된다.
    ///    새 설치에만 첫 실행에서 `keyboard`를 뿌린다(ClipKeyboardApp.seedSnippetsTabStyle).
    static let snippetsTabStyle = "snippetsTabStyle.v1"
    /// 키보드 화면을 한 번 권했는가(기존 사용자 1회 제안). 다시 묻지 않기 위한 표식.
    static let keyboardStageOffered = "keyboardStageOffered.v1"
    /// '단축어를 템플릿으로' 장을 목록에서 시작해야 한다는 예약 표식.
    /// ⚠️ 알림으로만 알리면 **목록이 아직 안 떠 있어 아무도 못 받는다** - 그 장이 통째로 사라진다.
    ///    화면이 뜬 뒤 스스로 확인할 수 있게 표식으로 남긴다.
    static let pendingMakeTemplateTutorial = "pendingMakeTemplateTutorial.v1"
    /// 튜토리얼에서 **만든** 단축어 id 목록(쉼표 구분). 끝난 뒤 "지울까요?"에 쓴다.
    static let tutorialCreatedMemoIds = "tutorialCreatedMemoIds.v1"
    /// 그 물음을 이미 했는가 - 한 번만 묻는다.
    static let tutorialCleanupAsked = "tutorialCleanupAsked.v1"
    /// 배우는 장(템플릿·템플릿으로 만들기·콤보)을 다 지났는가.
    /// ⚠️ 개별 완료 표식만으로는 판단하지 않는다 - 조건이 안 되어 조용히 건너뛴 장이 있으면
    ///    영영 안 끝난 것으로 남는다. 목록의 챕터 기계가 "더 없다"고 알려줄 때 켠다.
    static let tutorialChaptersDone = "tutorialChaptersDone.v1"
    /// 튜토리얼에서 방금 만든 단축어 id(UUID 문자열). 무대에서 이 키가 빛나고,
    /// **그걸 눌러야** 첫 걸음이 끝난다. 누르면 비운다.
    static let tutorialFirstUseMemoId = "tutorialFirstUseMemoId.v1"
    /// 첫 흐름에서 **키보드 켜기 안내까지** 지나왔는가(끝냈든 건너뛰었든).
    /// 없으면 첫 단축어를 만든 직후 키보드 설치 안내가 곧바로 이어진다.
    static let keyboardSetupTutorialDone = "keyboardSetupTutorialDone.v1"
    /// 키캡 물성 프리셋(KeyboardSkin rawValue). 값이 없으면 `.standard`.
    /// App Group - 익스텐션이 렌더에 쓴다. 색은 건드리지 않는다(테마·커스텀 색이 담당).
    static let keyboardSkin = "keyboardSkin.v1"
    /// 키 이름이 길 때 접는 방식(KeyLabelTruncation rawValue). 값이 없으면 `.middle`.
    /// App Group - 익스텐션이 렌더에 쓴다.
    static let keyLabelTruncation = "keyLabelTruncation.v1"
    static let keyboardPasteCount = "keyboard_paste_count"
    static let keyboardSecurePinHash = "keyboard_secure_pin_hash"
    static let keyboardTypingLang = "keyboardTypingLang"
    static let koreanEnabledMigratedV1 = "koreanEnabledMigrated_v1"
    static let lastBackupDate = "lastBackupDate"
    static let memoCopyCount = "memoCopyCount"
    /// '순서 바꾸기'로 지정한 수동 순서(메모 id 문자열 배열). App Group - 키보드 익스텐션도 이 순서를 따른다.
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

    // MARK: - Pro / 그랜드파더링 / 템플릿 (iOS·macOS 공유 - 이전엔 타겟별 중복 정의)
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

    /// 마스터(개발자) 모드 - 설정 > 앱 정보의 버전 행 7번 탭으로 토글 (standard UD)
    static let masterModeEnabled = "masterModeEnabled"

    // MARK: - 익명 사용 통계 (FeedbackHub 전송, 항상 켜짐)
    /// 이벤트 이름별 마지막 전송 시각 키 접두사 - `usage.event.lastSent.<이름>` (standard UD)
    static let usageEventLastSentPrefix = "usage.event.lastSent."

    // MARK: - 피드백 넛지
    /// 피드백 넛지 "다시 보지 않기" - 구버전 영구 옵트아웃 Bool(마이그레이션용으로만 읽음, standard UD)
    static let feedbackNudgeOptOut = "feedbackNudgeOptOut"
    /// 피드백 넛지 "다시 보지 않기"를 누른 시각(timeIntervalSince1970) - 6개월 유예 후 재노출 (standard UD)
    static let feedbackNudgeOptOutDate = "feedbackNudgeOptOutDate"
    /// 피드백 넛지를 마지막으로 보여준 실행 횟수 (standard UD)
    static let feedbackNudgeLastShownLaunch = "feedbackNudgeLastShownLaunch"

    // MARK: - Apple Intelligence (온디바이스 AI, iOS 26+)
    /// AI 클립보드 재분류 토글 (App Group, 기본 ON - 지원 기기에서만 동작)
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
    /// 마지막으로 원격 변경을 이 기기에 적용한 시각과 건수 (App Group) - 동기화 상태 화면 표시용
    static let syncLastPullAt = "sync.lastPullAt"
    static let syncLastPullCount = "sync.lastPullCount"
    /// 마지막으로 이 기기 변경을 올린 시각과 건수 (App Group)
    static let syncLastPushAt = "sync.lastPushAt"
    static let syncLastPushCount = "sync.lastPushCount"
    /// 마지막으로 원격 확인(fetch)을 마친 시각 - 받을 게 없어도 갱신된다 (App Group)
    static let syncLastCheckAt = "sync.lastCheckAt"
    /// 마지막 동기화 오류 메시지와 시각 (App Group)
    static let syncLastError = "sync.lastError"
    static let syncLastErrorAt = "sync.lastErrorAt"
    /// 동기화 사용 권한 - iOS가 `ProFeatureManager.hasFullAccess`(결제·그랜드파더·체험 전부)를
    /// 이 키에 미러링한다. 공유 엔진은 iOS 전용 타입에 의존할 수 없어 이 키로 판단한다.
    static let syncEntitled = "clipkeyboard_sync_entitled"

    // MARK: - 리스트 배경 이미지
    /// 선택된 배경 이미지 에셋 이름 (빈 문자열 = 배경 없음, App Group) - 모든 탭 기본값
    static let listBackgroundImageV1 = "listBackgroundImage_v1"
    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름] ("" = 이 탭만 배경 없음, App Group)
    static let listBackgroundPerTabV1 = "listBackgroundPerTab_v1"
    /// "새 배경 써보시겠어요?" 1회 제안을 이미 답했는지 (App Group)
    static let backgroundOfferResolvedV1 = "backgroundOfferResolved_v1"

    // MARK: - 첫 단축어 온보딩
    /// 첫 단축어 만들기를 끝냈거나 건너뛰었는지. 안 끝났으면 빈 목록 자리에 광부가 선다.
    static let firstShortcutDone = "firstShortcut.done.v1"
    /// 4.4.4 기본 스킨 씨앗을 이미 뿌렸는지(1회). 두 번 뿌리면 사용자가 바꾼 걸 되돌린다.
    static let skinSeededV444 = "skinSeeded.v444"
    /// 이 기기가 4.4.4 에서 **처음** 시작했는지. 금고 스킨 기본값과 샘플 생략이
    /// 같은 판단을 근거로 움직이게 하는 표식이다.
    static let startedFreshV444 = "startedFresh.v444"
    /// 콤보 튜토리얼을 끝냈거나 거절했는지. 거절도 답이라 다시 묻지 않는다.
    static let tutorialComboDone = "tutorial.combo.done.v1"
    /// 템플릿 튜토리얼을 끝냈거나 거절했는지.
    static let tutorialTemplateDone = "tutorial.template.done.v1"
    /// "있는 단축어를 템플릿으로 바꾸기" 튜토리얼을 끝냈거나 거절했는지.
    static let tutorialMakeTemplateDone = "tutorial.makeTemplate.done.v1"

    // MARK: - 런치 안전장치 (LaunchGuard)
    /// 지금 진행 중인 런치 단계 `"<tier>:<stage>"`. 런치를 끝내면 지운다 (App Group).
    /// 다음 런치에 이 값이 남아 있으면 **직전 런치가 그 자리에서 죽었다**는 뜻이다.
    static let launchStageInFlight = "launch.stage.inFlight"
    /// 마지막으로 런치를 못 끝낸 단계 이름 - 같은 자리에서 되풀이하는지 판정한다 (App Group).
    static let launchLastStalledStage = "launch.stage.lastStalled"
    /// 연속으로 런치를 못 끝낸 횟수. 끝까지 가면 0으로 돌아간다 (App Group).
    static let launchFailStreak = "launch.failStreak"
    /// 되풀이해 멈춘 탓에 이번 빌드에서는 시작하지 않는 단계 이름들 (App Group).
    static let launchQuarantinedStages = "launch.quarantinedStages"
    /// 격리 목록을 기록한 앱 버전. 버전이 바뀌면 목록을 비우고 다시 시도한다 (App Group).
    static let launchQuarantineVersion = "launch.quarantineVersion"

    // MARK: - 데모 데이터
    /// 데모(샘플 페르소나) 데이터가 켜져 있는지 (App Group - 키보드도 같은 데이터를 본다).
    /// 켤 때 원본을 demo.backup.data로 백업하고, 끄면 복원한다. DemoDataService 참고.
    static let demoDataActive = "demoDataActive_v1"
}
