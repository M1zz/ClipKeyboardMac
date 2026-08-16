//
//  MacCategoryTabs.swift
//  ClipKeyboard.tap
//
//  카테고리 탭 구성 — **아이폰 앱과 똑같은 목록·순서**를 맥에서 재현한다.
//
//  ⚠️ 아래 `BuiltInCategory` · `CategoryTab` 두 블록은 iOS
//     `ClipKeyboard/Presentation/ClipKeyboardList/ClipKeyboardListViewModel.swift` 에서
//     **글자 그대로 옮겨온 것**이다. iOS 원본이 큰 파일 안에 있어 파일 단위로는 공유할 수
//     없으므로, drift-guard 의 EMBEDDED_MAP 이 이 블록만 뽑아 비교한다.
//     → 고칠 일이 있으면 **iOS 를 먼저 고치고 여기로 옮긴다.** 여기서만 고치면 드리프트로 뜬다.
//
//  탭 구성 규칙(iOS `allCategoryTabs` 와 동일):
//    기본 → 즐겨찾기(숨기지 않았으면) → 켜 둔 기본 제공 카테고리(allCases 순서) → 사용자 카테고리(숨기지 않은 것)
//  ⚠️ "전체" 탭은 없다. iOS 가 없앤 탭이라 맥에만 두면 같은 앱이 기기마다 다르게 보인다.
//  ⚠️ 메모가 없는 카테고리도 탭으로 보인다 — 막 만든 카테고리가 그 모습이고, 그건 그냥 빈 페이지다.
//

import SwiftUI

// MARK: - iOS 원본 블록 (EMBEDDED_MAP 감시 대상 — 손대지 말 것)

enum BuiltInCategory: String, CaseIterable, Hashable {
    case templates   // 템플릿만
    case textMemos   // 메모+템플릿 (이미지·콤보 제외)
    case images      // 이미지 메모만
    case combos      // 콤보만

    var displayName: String {
        switch self {
        case .templates: return NSLocalizedString("템플릿", comment: "Built-in category: templates only")
        case .textMemos: return NSLocalizedString("단축어+템플릿", comment: "Built-in category: text memos and templates")
        case .images:    return NSLocalizedString("이미지 단축어", comment: "Built-in category: image memos only")
        case .combos:    return NSLocalizedString("콤보", comment: "Built-in category: combos only")
        }
    }

    var icon: String {
        switch self {
        case .templates: return "wand.and.stars"
        case .textMemos: return "doc.text.fill"
        case .images:    return "photo.fill"
        case .combos:    return "square.stack.3d.up.fill"
        }
    }

    /// 탭 배경·인디케이터 색 (선택 칩은 공통 파랑, 이 색은 은은한 배경 틴트로만 사용).
    var tint: Color {
        switch self {
        case .templates: return .purple
        case .textMemos: return .indigo
        case .images:    return .green
        case .combos:    return .orange
        }
    }

    /// 이 카테고리에 메모가 속하는지 - 타입 기준 판정.
    func matches(_ memo: Memo) -> Bool {
        switch self {
        case .templates: return memo.isTemplate
        case .textMemos: return !memo.isCombo
                              && memo.contentType != .image
                              && memo.contentType != .mixed
        case .images:    return memo.contentType == .image || memo.contentType == .mixed
        case .combos:    return memo.isCombo
        }
    }
}

enum CategoryTab: Hashable, Equatable {
    /// "전체" 탭 제거 후 기본 홈 탭 - 어떤 사용자 카테고리에도 속하지 않은(기본/미분류) 메모 모음.
    case basic
    /// 카테고리 기능이 꺼져 있을 때의 단일 "모든 메모" 페이지 전용. 탭 바에는 노출되지 않음.
    case all
    case favorites
    case builtIn(BuiltInCategory)
    case custom(String)

    var displayName: String {
        switch self {
        case .basic:     return NSLocalizedString("기본", comment: "Category tab: default/basic")
        case .all:       return NSLocalizedString("전체", comment: "Category tab: all")
        case .favorites: return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites")
        case .builtIn(let b): return b.displayName
        case .custom(let name): return name
        }
    }

    /// UserDefaults 저장용 안정 키 (마지막 본 탭 복원).
    var storageKey: String {
        switch self {
        case .basic:            return "__basic__"
        case .all:              return "__all__"
        case .favorites:        return "__favorites__"
        case .builtIn(let b):   return "builtin:" + b.rawValue
        case .custom(let name): return "custom:" + name
        }
    }

    init?(storageKey: String) {
        switch storageKey {
        case "__basic__":     self = .basic
        case "__all__":       self = .all
        case "__favorites__": self = .favorites
        default:
            let builtInPrefix = "builtin:"
            if storageKey.hasPrefix(builtInPrefix),
               let b = BuiltInCategory(rawValue: String(storageKey.dropFirst(builtInPrefix.count))) {
                self = .builtIn(b)
                return
            }
            let prefix = "custom:"
            guard storageKey.hasPrefix(prefix) else { return nil }
            let name = String(storageKey.dropFirst(prefix.count))
            guard !name.isEmpty else { return nil }
            self = .custom(name)
        }
    }

    var icon: String {
        switch self {
        case .basic:     return "tray.full.fill"
        case .all:       return "square.grid.2x2"
        case .favorites: return "heart.fill"
        case .builtIn(let b): return b.icon
        case .custom:    return "folder.fill"
        }
    }

    /// 칩에 삭제(x) 버튼을 숨길지 - 사용자 정의(custom)만 칩에서 삭제 가능.
    /// 기본 제공 카테고리는 카테고리 관리 화면의 토글로 끈다.
    var isBuiltIn: Bool {
        if case .custom = self { return false }
        return true
    }
}

// MARK: - 맥 전용 조립부 (iOS ViewModel 의 allCategoryTabs / memos(for:) 를 맥 데이터로 옮긴 것)

enum MacCategoryTabs {

    /// 아이폰에서 설정한 카테고리 구성 그대로 탭 목록을 만든다.
    ///
    /// - Returns: 카테고리 기능이 꺼져 있으면 **빈 배열** — 탭 없이 전체 목록 한 장을 보여준다
    ///   (iOS 에서 기능이 꺼졌을 때의 `.all` 단일 페이지와 같은 상태).
    static func tabs(from snapshot: CategorySnapshot) -> [CategoryTab] {
        guard snapshot.featureEnabled else { return [] }

        var tabs: [CategoryTab] = [.basic]
        let hidden = Set(snapshot.hiddenTabs)

        // 즐겨찾기는 기본 제공 — 메모 유무와 무관하게 항상(숨기지 않는 한) 노출.
        if !hidden.contains(CategoryBucketRule.favoritesTabKey) {
            tabs.append(.favorites)
        }
        // 기본 제공 카테고리는 켠 것만, allCases 순서를 유지해 탭 순서가 항상 일정하게.
        let enabled = Set(snapshot.enabledBuiltIns)
        tabs += BuiltInCategory.allCases
            .filter { enabled.contains($0.rawValue) }
            .map { CategoryTab.builtIn($0) }
        // 사용자 카테고리는 아이폰이 정한 순서 그대로, 숨기지 않은 것만.
        tabs += snapshot.categories
            .filter { !hidden.contains($0) }
            .map { CategoryTab.custom($0) }

        return tabs
    }

    /// 해당 탭에 속하는 단축어만 고른다 (iOS `memos(for:)` 와 같은 판정).
    static func memos(_ memos: [Memo], for tab: CategoryTab, in snapshot: CategorySnapshot) -> [Memo] {
        switch tab {
        case .all:
            return memos
        case .basic:
            // ⚠️ 기준은 "만들어 둔 카테고리"가 아니라 **지금 탭이 서 있는 카테고리**다.
            //    숨긴 카테고리의 단축어까지 기본 칸이 받아야 어느 탭에도 없는 단축어가 안 생긴다.
            let hidden = Set(snapshot.hiddenTabs)
            let visible = CategoryBucketRule.visibleCategories(all: snapshot.categories, hidden: hidden)
            let favoritesVisible = !hidden.contains(CategoryBucketRule.favoritesTabKey)
            return memos.filter {
                CategoryBucketRule.belongsToBasicBucket(category: $0.category,
                                                        isFavorite: $0.isFavorite,
                                                        visibleCustomCategories: visible,
                                                        favoritesTabVisible: favoritesVisible)
            }
        case .favorites:
            return memos.filter { $0.isFavorite }
        case .builtIn(let builtIn):
            return memos.filter { builtIn.matches($0) }
        case .custom(let name):
            return memos.filter { $0.category == name }
        }
    }
}
