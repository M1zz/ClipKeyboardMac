//
//  CategoryBucketRule.swift
//  ClipKeyboard
//
//  "이 단축어는 **기본** 칸에 모이는가"를 정하는 **단 하나의 규칙.**
//  메인앱(`ClipKeyboardListViewModel.basicBucketMemos`)과 키보드(`KeyboardView.filteredMemos`)가
//  같은 함수를 부른다.
//
//  왜 파일까지 만들어 한 곳에 두는가: 이 규칙은 원래 두 벌로 복사돼 있었고, 둘 다 같은 실수를
//  했다. **탭이 숨겨진 카테고리**를 기본 칸에서도 빼 버린 것이다. 그 카테고리는 페이지가
//  만들어지지 않으므로, 결과적으로 그 안의 단축어는 앱에서도 키보드에서도 **어느 페이지에도
//  나타나지 않았다.** 목록은 페이지 기준으로 자르니 검색으로도 못 찾는다. 사용자에게는
//  단축어가 사라진 것으로 보인다.
//
//  ⚠️ 지켜야 할 약속은 하나다: **갈 수 있는 페이지가 없는 단축어는 전부 기본 칸이 받는다.**
//     (숨긴 카테고리 · 지워진 카테고리의 고아 · 카테고리 없음)
//     빈 카테고리는 사고가 아니다 - 막 만든 카테고리가 그 모습이고, 그건 그냥 빈 페이지다.
//

import Foundation

enum CategoryBucketRule {

    /// 이 단축어가 "기본" 칸에 모이는가.
    ///
    /// - Parameters:
    ///   - category: 단축어의 카테고리 이름.
    ///   - isFavorite: 즐겨찾기 여부 - 즐겨찾기도 하나의 칸이라 기본에서 빠진다.
    ///   - visibleCustomCategories: 지금 **탭/페이지가 서 있는** 사용자 카테고리.
    ///     ⚠️ 만들어 둔 카테고리 전부가 아니다. 숨긴 것을 여기 넣으면 위에 적은 그 사고가 그대로 난다.
    /// - Parameter favoritesTabVisible: 즐겨찾기 탭이 지금 서 있는가.
    ///   ⚠️ 즐겨찾기도 **숨길 수 있는 탭**이다("__favorites__" 가 같은 숨김 집합에 들어간다).
    ///   이걸 무시하고 "즐겨찾기면 무조건 빠짐"으로 두면, 즐겨찾기 탭을 숨긴 사람의
    ///   즐겨찾기 단축어는 갈 탭이 없어 또 사라진다 - 이 파일이 막으려던 바로 그 사고다.
    static func belongsToBasicBucket(category: String,
                                     isFavorite: Bool,
                                     visibleCustomCategories: Set<String>,
                                     favoritesTabVisible: Bool = true) -> Bool {
        if isFavorite, favoritesTabVisible { return false }
        return !visibleCustomCategories.contains(category)
    }

    /// 즐겨찾기 탭을 숨길 때 쓰는 키 - 사용자 카테고리 이름과 같은 집합에 들어간다.
    static let favoritesTabKey = "__favorites__"


    /// 만들어 둔 카테고리 목록에서 **갈 수 있는 것만** 걸러낸다.
    static func visibleCategories(all: [String], hidden: Set<String>) -> Set<String> {
        Set(all.filter { !hidden.contains($0) })
    }
}
