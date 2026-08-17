//
//  MacMemoActions.swift
//  ClipKeyboard.tap
//
//  맥에서 단축어를 고치고 지우는 **단일 통로**.
//
//  왜 한 곳에 모으는가: 저장소를 건드리는 곳이 흩어지면 (1) 이미지 파일이 고아로 남고
//  (2) 시드 샘플 표식이 어긋나고 (3) 화면 새로고침을 빠뜨리기 쉽다. 특히 삭제는
//  동기화에 **툼스톤**으로 전파돼 아이폰에서도 사라지는 동작이라, 저장 신호를
//  한 경로로만 내보내야 한다(MemoStore.save → .memoDataChanged → MemoSyncEngine).
//

import AppKit
import Foundation

enum MacMemoActions {

    // MARK: - 수정

    /// 단축어 하나를 통째로 교체한다(id 기준). 없으면 아무것도 하지 않고 false.
    /// - Note: `lastEdited` 는 호출자가 이미 갱신해 둔 값을 그대로 쓴다 —
    ///   동기화 충돌 해결이 이 값을 기준으로 최신본을 고르기 때문이다.
    @discardableResult
    static func update(_ memo: Memo) -> Bool {
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            guard let index = memos.firstIndex(where: { $0.id == memo.id }) else {
                print("⚠️ [MacMemoActions] 수정 대상 없음: \(memo.id)")
                return false
            }
            memos[index] = memo
            try MemoStore.shared.save(memos: memos, type: .memo)
            unmarkSample(ids: [memo.id])   // 사용자가 고친 순간 '예시'가 아니라 사용자 데이터다
            notifyChanged()
            print("✅ [MacMemoActions] 수정 완료: \(memo.title)")
            return true
        } catch {
            print("❌ [MacMemoActions] 수정 실패: \(error)")
            return false
        }
    }

    /// 즐겨찾기만 토글한다(수정 시트를 열 필요 없는 한 번 누르기 동작).
    static func toggleFavorite(_ memo: Memo) {
        var updated = memo
        updated.isFavorite.toggle()
        updated.lastEdited = Date()
        update(updated)
    }

    // MARK: - 삭제

    /// 단축어들을 지운다. 지운 개수를 돌려준다.
    ///
    /// ⚠️ 이미지는 **남은 단축어가 참조하지 않을 때만** 지운다. 같은 파일을 두 단축어가
    ///    가리키는 경우(복제·중복 정리 후)가 있어, 무조건 지우면 살아있는 쪽이 깨진다.
    @discardableResult
    static func delete(ids: Set<UUID>) -> Int {
        guard !ids.isEmpty else { return 0 }
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            let removed = memos.filter { ids.contains($0.id) }
            guard !removed.isEmpty else { return 0 }
            let remaining = memos.filter { !ids.contains($0.id) }

            try MemoStore.shared.save(memos: remaining, type: .memo)

            deleteOrphanImages(of: removed, keeping: remaining)
            unmarkSample(ids: ids)
            notifyChanged()
            print("🗑️ [MacMemoActions] \(removed.count)개 삭제 완료 (남은 \(remaining.count)개)")
            return removed.count
        } catch {
            print("❌ [MacMemoActions] 삭제 실패: \(error)")
            return 0
        }
    }

    @discardableResult
    static func delete(_ memo: Memo) -> Bool {
        delete(ids: [memo.id]) == 1
    }

    // MARK: - 중복 정리

    /// 제목·내용·이미지가 똑같은 단축어 묶음(2개 이상)만 골라 돌려준다.
    /// 동기화가 어긋나 같은 단축어가 여러 벌 쌓였을 때 몇 개를 지울 수 있는지 미리 보여주기 위한 것.
    static func duplicateGroups(in memos: [Memo]) -> [[Memo]] {
        var buckets: [String: [Memo]] = [:]
        for memo in memos {
            buckets[duplicateKey(memo), default: []].append(memo)
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { $0.sorted(by: keepFirst) }
            .sorted { ($0.first?.title ?? "") < ($1.first?.title ?? "") }
    }

    /// 중복 묶음마다 한 개만 남기고 나머지를 지운다. 지운 개수를 돌려준다.
    @discardableResult
    static func removeDuplicates() -> Int {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let groups = duplicateGroups(in: memos)
        guard !groups.isEmpty else { return 0 }
        // 각 묶음의 첫 번째(= 남길 것)를 빼고 전부 삭제 대상.
        let victims = Set(groups.flatMap { $0.dropFirst() }.map(\.id))
        return delete(ids: victims)
    }

    /// 중복 판정 기준 — 눈에 보이는 내용이 같으면 같은 것으로 본다.
    /// 공백만 다른 경우도 중복으로 묶되, 이미지 구성이 다르면 다른 단축어다.
    private static func duplicateKey(_ memo: Memo) -> String {
        let title = memo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = memo.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = imageNames(of: memo).sorted().joined(separator: ",")
        return "\(title)\u{1F}\(value)\u{1F}\(images)"
    }

    /// 중복 묶음에서 **남길 순서**. 즐겨찾기 → 많이 쓴 것 → 먼저 만든 것(오래된 lastEdited).
    /// 사용 기록이 붙어 있는 쪽을 남겨야 사용자가 "쓰던 것"을 잃지 않는다.
    private static func keepFirst(_ lhs: Memo, _ rhs: Memo) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        if lhs.clipCount != rhs.clipCount { return lhs.clipCount > rhs.clipCount }
        if lhs.lastEdited != rhs.lastEdited { return lhs.lastEdited < rhs.lastEdited }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    // MARK: - 내부

    private static func imageNames(of memo: Memo) -> [String] {
        var names = memo.imageFileNames
        if let single = memo.imageFileName, !single.isEmpty, !names.contains(single) {
            names.append(single)
        }
        return names
    }

    /// 지운 단축어의 이미지 중 아무도 참조하지 않는 파일만 정리한다.
    private static func deleteOrphanImages(of removed: [Memo], keeping remaining: [Memo]) {
        let stillUsed = Set(remaining.flatMap(imageNames))
        for name in Set(removed.flatMap(imageNames)) where !stillUsed.contains(name) {
            try? MemoStore.shared.deleteImage(fileName: name)
        }
    }

    /// 시드 샘플 표식에서 빼 준다.
    ///
    /// ⚠️ 표식이 남아 있으면 동기화가 그 id 를 "올리지 않을 것"으로 계속 분류해,
    ///    사용자가 고친 내용이 아이폰으로 가지 않는다(`MemoSyncEngine.syncableMemos`).
    private static func unmarkSample(ids: Set<UUID>) {
        let current = SampleMemoStorage.load()
        let next = current.subtracting(ids)
        guard next.count != current.count else { return }
        if next.isEmpty {
            SampleMemoStorage.clear()
        } else {
            SampleMemoStorage.save(ids: Array(next))
        }
    }

    /// 열려 있는 모든 화면(목록·순서 탭·메뉴바 팝오버)을 새로고침한다.
    /// 클라우드 업로드는 `MemoStore.save` 가 보내는 `.memoDataChanged` 가 맡는다.
    private static func notifyChanged() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .dataRestored, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dataRestored, object: nil)
            }
        }
    }
}
