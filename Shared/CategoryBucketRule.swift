//
//  CategoryBucketRule.swift
//  ClipKeyboard
//
//  "이 단축어는 **기본** 칸에 모이는가" 와 "그 칸을 탭 바에 세울 것인가" 를 정하는 **단 하나의 규칙.**
//  메인앱(`ClipKeyboardListViewModel`)과 키보드(`KeyboardView`)가 같은 함수를 부른다.
//
//  왜 파일까지 만들어 한 곳에 두는가: 이 규칙은 원래 두 벌로 복사돼 있었고, 둘 다 같은 실수를
//  했다. **탭이 숨겨진 카테고리**를 기본 칸에서도 빼 버린 것이다. 그 카테고리는 페이지가
//  만들어지지 않으므로, 결과적으로 그 안의 단축어는 앱에서도 키보드에서도 **어느 페이지에도
//  나타나지 않았다.** 목록은 페이지 기준으로 자르니 검색으로도 못 찾는다. 사용자에게는
//  단축어가 사라진 것으로 보인다.
//
//  ⚠️ 지켜야 할 약속은 하나다: **갈 수 있는 페이지가 없는 단축어는 전부 기본 칸이 받는다.**
//     (숨긴 카테고리 · 지워진 카테고리의 고아 · 카테고리 없음)
//

import Foundation

enum CategoryBucketRule {

    /// 즐겨찾기 탭을 숨길 때 쓰는 키 - 사용자 카테고리 이름과 같은 집합에 들어간다.
    static let favoritesTabKey = "__favorites__"

    // MARK: - 어느 칸이 받는가

    /// 이 단축어가 "기본" 칸에 모이는가.
    ///
    /// - Parameters:
    ///   - category: 단축어의 카테고리 이름.
    ///   - visibleCustomCategories: 지금 **탭/페이지가 서 있는** 사용자 카테고리.
    ///     ⚠️ 만들어 둔 카테고리 전부가 아니다. 숨긴 것을 여기 넣으면 위에 적은 그 사고가 그대로 난다.
    ///
    /// ⚠️ **즐겨찾기는 보지 않는다.** 즐겨찾기는 자리가 아니라 겹쳐 보기다.
    ///
    ///    예전에는 즐겨찾기면 기본 칸에서 빼냈다. 한 번 보이게 하려는 뜻이었는데, 정작
    ///    '업무' 안의 즐겨찾기는 업무에도 즐겨찾기에도 그대로 나왔다. 그래서 같은 별표가
    ///    **어디에 있느냐에 따라 옮기기도 하고 겹쳐 보이기도 하는** 두 가지 뜻을 가졌다.
    ///    기본 칸에서 별을 누르면 그 단축어가 눈앞에서 사라졌고, 카테고리를 안 쓰는 사람은
    ///    별을 누를수록 첫 화면이 비어 갔다.
    ///
    ///    지금은 한 가지 뜻이다. 별표는 단축어를 **옮기지 않는다.** 제자리에 그대로 두고
    ///    즐겨찾기 탭에서 한 번 더 보여 줄 뿐이다.
    static func belongsToBasicBucket(category: String,
                                     visibleCustomCategories: Set<String>) -> Bool {
        !visibleCustomCategories.contains(category)
    }

    /// 만들어 둔 카테고리 목록에서 **갈 수 있는 것만** 걸러낸다.
    static func visibleCategories(all: [String], hidden: Set<String>) -> Set<String> {
        Set(all.filter { !hidden.contains($0) })
    }

    // MARK: - 그 칸을 세울 것인가

    /// 즐겨찾기 탭을 세울까.
    ///
    /// 별을 하나도 안 단 사람에게 즐겨찾기 탭은 **영영 빈 페이지**다. 탭 바 한 자리를
    /// 차지하고, 옆으로 넘기다 보면 아무것도 없는 화면이 한 장 끼어 있다.
    /// 첫 별이 달리면 저절로 선다.
    ///
    /// - Parameter favoriteCount: 즐겨찾기 수. **검색·필터를 거치지 않은** 전체 기준이어야 한다.
    ///   거른 수를 넣으면 검색어를 치는 동안 탭이 사라졌다 나타난다.
    static func showsFavoritesTab(favoriteCount: Int, hidden: Set<String>) -> Bool {
        guard !hidden.contains(favoritesTabKey) else { return false }
        return favoriteCount > 0
    }

    /// 기본 탭을 세울까.
    ///
    /// 단축어를 전부 카테고리로 옮기면 기본 칸은 빈다. 그때까지 첫 자리를 지키고 서서
    /// 빈 화면을 보여 줄 이유가 없다. 카테고리 없는 단축어가 다시 생기면 저절로 선다.
    ///
    /// ⚠️ **다른 탭이 하나도 없으면 비어 있어도 선다.** 기본은 마지막 안전망이라,
    ///    여기까지 접으면 탭이 0개가 되고 화면이 통째로 사라진다.
    ///
    /// - Parameter basicCount: 기본 칸이 받은 수. 이것도 **거르지 않은** 전체 기준이어야 한다.
    /// - Parameter otherTabCount: 기본 말고 지금 서 있는 탭 수.
    static func showsBasicTab(basicCount: Int, otherTabCount: Int) -> Bool {
        basicCount > 0 || otherTabCount == 0
    }
}
