//
//  PopoverViewModel.swift
//  ClipKeyboard.tap
//
//  메뉴바 팝오버의 찾기 · 고르기 · 키보드로 오르내리기를 쥔 뷰모델.
//  `MenuBarPopoverView.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import AppKit
import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var memos: [Memo] = []
    @Published var selectedIndex: Int = 0
    /// 선택된 카테고리 탭. 첫 탭은 구성에 따라 다르다(아이폰 구성=기본 / 예전 구성=전체).
    @Published var selectedTab: CategoryTab = .all
    /// '최근' 탭을 보고 있는가(`MacRecentClips`). 카테고리 칩을 누르면 꺼진다.
    @Published var showingRecent = false
    /// 이 맥에서 복사해 담긴 것. '최근' 탭을 보는 동안 가끔 다시 읽는다.
    @Published var clips: [ClipboardHistory] = []

    var filteredClips: [ClipboardHistory] {
        MacRecentClips.filtered(clips, query: searchText)
    }

    /// 지금 보이는 목록의 길이(화살표로 고를 범위).
    var visibleCount: Int { showingRecent ? filteredClips.count : filtered.count }

    func reloadClips() {
        let fresh = MacRecentClips.load()
        // 같으면 건드리지 않는다. 그대로 덮으면 목록이 1.5초마다 다시 그려진다.
        guard fresh.map(\.id) != clips.map(\.id) else { return }
        clips = fresh
        if showingRecent, selectedIndex >= filteredClips.count { selectedIndex = max(0, filteredClips.count - 1) }
    }

    /// 아이폰에서 넘어온 카테고리 설정(순서·아이콘·숨김·기본제공) — 메모 목록 창과 같은 구성을 쓴다.
    private(set) var categorySettings: CategorySnapshot = CategorySnapshotStore.current()

    /// 표시할 탭 목록 — 아이폰 구성을 따르기로 했으면 아이폰 그대로, 아니면 4.4.6 까지의 구성.
    var tabs: [CategoryTab] {
        MacCategoryTabs.tabs(memos: memos,
                             snapshot: categorySettings,
                             followsPhone: MacCategoryTabPreference.shared.followsPhone)
    }

    var filtered: [Memo] {
        var result = memos

        // 1) 카테고리 탭 — 탭이 없으면 필터도 없다.
        if !tabs.isEmpty {
            result = MacCategoryTabs.memos(result, for: selectedTab, in: categorySettings)
        }

        // 2) 검색어
        guard !searchText.isEmpty else { return result }
        let q = searchText.lowercased()
        return result.filter { memo in
            if memo.title.lowercased().contains(q) { return true }
            // 보안 메모는 값(암호문)으로 검색하지 않음 — 제목으로만 매칭.
            if memo.isSecure { return false }
            if memo.value.lowercased().contains(q) { return true }
            // Fuzzy: check char sequence (usr lcl → /usr/local 같은 매칭)
            return fuzzyMatch(needle: q, haystack: (memo.title + " " + memo.value).lowercased())
        }
    }

    func reload() {
        do {
            // 메모와 카테고리 설정은 같은 동기화로 함께 갱신된다 — 따로 읽으면
            // 새 탭의 메모는 왔는데 탭 순서·아이콘은 옛것인 상태가 생긴다.
            categorySettings = CategorySnapshotStore.current()
            let loaded = try MemoStore.shared.load(type: .memo)
            // 사용자가 지정한 수동 순서(있으면) → 없으면 즐겨찾기 먼저, 최근순. iOS와 순서 공유.
            memos = MacMemoOrder.sorted(loaded)
            // 기존 사용자에게 "아이폰 구성으로 맞출까요?"를 물어봐야 하는 상황인지 판단한다.
            MacCategoryTabPreference.shared.evaluate(memos: memos, snapshot: categorySettings)
            // 구성이 바뀌거나 아이폰에서 카테고리를 숨기면 보고 있던 탭이 사라진다 —
            // 그 자리에 서 있는 첫 탭으로 되돌린다.
            let available = tabs
            if !available.isEmpty && !available.contains(selectedTab) { selectedTab = available[0] }
            if selectedIndex >= filtered.count { selectedIndex = max(0, filtered.count - 1) }
        } catch {
            print("⚠️ [Popover] 메모 로드 실패: \(error)")
        }
    }

    /// 간이 fuzzy — 순서대로 문자가 등장하면 매치 (공백은 무시).
    private func fuzzyMatch(needle: String, haystack: String) -> Bool {
        let chars = Array(needle.filter { !$0.isWhitespace })
        guard !chars.isEmpty else { return true }
        var i = 0
        for c in haystack {
            if c == chars[i] {
                i += 1
                if i == chars.count { return true }
            }
        }
        return false
    }
}
