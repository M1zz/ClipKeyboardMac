//
//  MacMemoOrder.swift
//  ClipKeyboard.tap
//
//  손으로 정한 단축어 순서. 아이폰 · 키보드와 App Group 으로 나눠 쓴다.
//  `Models.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import Foundation
import Combine
import AppKit

// MARK: - 무료 · Plus · Pro

/// 이 맥 앱의 칸과 한도는 `MacPlan` 한 곳에 있다(무료 한도 · 클립보드 기록 개수 · 동기화 · 백업 · 보안 단축어).
/// 이 앱이 스스로 파는 상품(StoreKit 2)만 권한이 된다.
///
/// ⚠️ 5.0.5(20) 까지는 `MacProManager` 가 아이폰의 결제 키를 iCloud KV 로 받아 맥을 잠갔고,
///    Guideline 2.1(b)("Pro 를 참조하는데 해당 IAP 가 제출되지 않았다")로 거절됐다.
///    아이폰 구매를 비추는 방식으로 되돌리지 않는다.

// MARK: - MacMemoOrder

/// 사용자가 지정한 수동 순서(단축어 순서 바꾸기)를 App Group을 통해 iOS·키보드 익스텐션과 공유한다.
/// iOS `ClipKeyboardListViewModel`의 `sortMemos`/`commitReorder`와 **동일한 규칙**으로 동작해야
/// 아이폰에서 바꾼 순서가 맥에 그대로 나타나고, 맥에서 바꾼 순서도 아이폰·키보드에 반영된다.
enum MacMemoOrder {
    private static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    /// 사용자가 수동 순서를 한 번이라도 지정했는지. true면 즐겨찾기 고정을 풀고 지정 순서를 그대로 따른다.
    static var isActive: Bool {
        groupDefaults?.bool(forKey: DefaultsKey.memoManualOrderActiveV1) ?? false
    }

    /// 저장된 수동 순서(메모 id 배열).
    private static var order: [UUID] {
        let raw = groupDefaults?.stringArray(forKey: DefaultsKey.memoManualOrderV1) ?? []
        return raw.compactMap { UUID(uuidString: $0) }
    }

    /// 표시 정렬 — 수동 순서가 있으면 그 순서대로(미등록 새 메모는 맨 위), 없으면 즐겨찾기 먼저 → 최근 편집순.
    /// iOS `sortMemos`와 규칙이 동일하다.
    static func sorted(_ memos: [Memo]) -> [Memo] {
        if isActive {
            let ranks = Dictionary(
                order.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            return memos.sorted { a, b in
                switch (ranks[a.id], ranks[b.id]) {
                case let (ra?, rb?): return ra < rb
                case (nil, _?):      return true   // 순서 미등록(새 메모)은 위로
                case (_?, nil):      return false
                case (nil, nil):     return a.lastEdited > b.lastEdited
                }
            }
        }
        return memos.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite && !b.isFavorite }
            return a.lastEdited > b.lastEdited
        }
    }

    /// 재정렬된 부분집합(`reordered`)을 전체 순서에 병합해 App Group에 영구 저장한다.
    /// 현재 탭/카테고리의 메모만 재정렬한 경우, 전체 순서에서 그 메모들이 차지하던 슬롯만 새 순서로
    /// 치환한다 — 다른 메모의 상대 순서는 유지. iOS `commitReorder`와 동일한 규칙.
    /// - Parameters:
    ///   - reordered: 사용자가 드래그로 새로 정렬한 (부분)목록.
    ///   - allMemos: 디스크에서 로드한 전체 메모(정렬 전 원본이어도 됨 — 내부에서 표시 순서로 정렬해 병합).
    static func commit(reordered: [Memo], within allMemos: [Memo]) {
        guard !reordered.isEmpty else { return }
        let base = sorted(allMemos)   // 현재 표시 순서 기준으로 슬롯 치환
        let subsetIds = Set(reordered.map(\.id))
        var iterator = reordered.makeIterator()
        var merged: [Memo] = []
        merged.reserveCapacity(base.count)
        for memo in base {
            if subsetIds.contains(memo.id) {
                if let next = iterator.next() { merged.append(next) }
            } else {
                merged.append(memo)
            }
        }
        // 방어: base에 없던 재정렬 항목이 남으면 뒤에 덧붙인다(유실 방지).
        while let leftover = iterator.next() { merged.append(leftover) }

        groupDefaults?.set(merged.map { $0.id.uuidString }, forKey: DefaultsKey.memoManualOrderV1)
        groupDefaults?.set(true, forKey: DefaultsKey.memoManualOrderActiveV1)
        print("✅ [MacMemoOrder.commit] 수동 순서 저장 — 재정렬 \(reordered.count)개 / 전체 \(merged.count)개")
    }
}
