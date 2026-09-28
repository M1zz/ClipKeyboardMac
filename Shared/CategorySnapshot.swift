//
//  CategorySnapshot.swift
//  ClipKeyboard
//
//  카테고리 설정을 **백업·동기화에 실을 수 있는 한 덩이**로 묶는다.
//
//  왜 필요한가: 메모 내용은 `memos.data` 파일에 들어가 백업·동기화를 타지만,
//  카테고리 목록·아이콘·숨김 설정은 **App Group UserDefaults 에만** 있었다.
//  그래서 새 기기에서 앱 백업으로 복원하면 메모는 다 살아나는데 카테고리 탭이
//  하나도 없고, 각 메모의 `category` 값만 쓸모없이 남아 있었다.
//
//  ⚠️ 여기 담기는 건 **설정**이지 사용자 콘텐츠가 아니다. 이름·아이콘·순서·숨김뿐이고
//     메모 내용은 들어가지 않는다.
//  ⚠️ 필드를 추가할 땐 전부 옵셔널/기본값으로 - 구버전이 만든 스냅샷을 신버전이,
//     신버전이 만든 걸 구버전이 읽어도 깨지지 않아야 한다(다운그레이드 대비).
//

import Foundation
import CryptoKit

struct CategorySnapshot: Codable, Equatable {

    /// 사용자 정의 카테고리 - **순서가 곧 탭 순서**라 배열로 둔다.
    var categories: [String] = []
    /// [카테고리명: SF Symbol 이름]
    var icons: [String: String] = [:]
    /// [카테고리명: 색 hex] - 사용자가 직접 고른 색만. 미지정 카테고리는 팔레트가 정한다.
    var colors: [String: String] = [:]
    /// 사용자가 숨긴 탭 이름.
    var hiddenTabs: [String] = []
    /// 켜 둔 기본 제공 카테고리(BuiltInCategory.rawValue).
    var enabledBuiltIns: [String] = []
    /// 카테고리 기능 자체를 켰는지.
    var featureEnabled: Bool = false
    /// 이 스냅샷을 만든 시각 - 동기화 충돌 시 최신 우선 판단에 쓴다.
    var updatedAt: Date = Date()
    /// 카테고리 동기화 항목(id·수정 시각·삭제 표시). **백업에만** 싣는다.
    /// 복원하면 id 가 그대로 살아나, 다른 기기와 같은 카테고리로 이어진다.
    /// 옛 `category-settings` 동기화 레코드에는 싣지 않는다(`syncable` 에서 뺀다).
    var items: [CategoryItem]?

    var isEmpty: Bool {
        categories.isEmpty && icons.isEmpty && colors.isEmpty
            && hiddenTabs.isEmpty && enabledBuiltIns.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case categories, icons, colors, hiddenTabs, enabledBuiltIns, featureEnabled, updatedAt, items
    }

    init(categories: [String] = [], icons: [String: String] = [:], colors: [String: String] = [:],
         hiddenTabs: [String] = [], enabledBuiltIns: [String] = [],
         featureEnabled: Bool = false, updatedAt: Date = Date(), items: [CategoryItem]? = nil) {
        self.categories = categories
        self.icons = icons
        self.colors = colors
        self.hiddenTabs = hiddenTabs
        self.enabledBuiltIns = enabledBuiltIns
        self.featureEnabled = featureEnabled
        self.updatedAt = updatedAt
        self.items = items
    }

    /// 관용 디코더 - 누락 키를 전부 기본값으로 허용한다(하위·상위 호환).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        self.icons = try c.decodeIfPresent([String: String].self, forKey: .icons) ?? [:]
        self.colors = try c.decodeIfPresent([String: String].self, forKey: .colors) ?? [:]
        self.hiddenTabs = try c.decodeIfPresent([String].self, forKey: .hiddenTabs) ?? []
        self.enabledBuiltIns = try c.decodeIfPresent([String].self, forKey: .enabledBuiltIns) ?? []
        self.featureEnabled = try c.decodeIfPresent(Bool.self, forKey: .featureEnabled) ?? false
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.items = try c.decodeIfPresent([CategoryItem].self, forKey: .items)
    }
}

// MARK: - App Group UserDefaults ↔ 스냅샷

enum CategorySnapshotStore {

    // ⚠️ 키 이름은 CategoryStore/CategoryIconSettings 와 **정확히 같아야 한다**.
    //    한 글자만 달라도 조용히 빈 값이 되어 "복원했는데 카테고리가 없다"가 반복된다.
    static let categoriesKey = "userDefinedCategories_v1"
    static let iconsKey = "userCategoryIcons_v1"
    static let colorsKey = "userCategoryColors_v1"
    static let hiddenTabsKey = "hiddenCategoryTabs_v1"
    static let enabledBuiltInsKey = "enabledBuiltInCategories_v1"
    static let featureEnabledKey = "category.feature.enabled.v1"

    /// `Memo.category` 의 기본값이자 아이폰·맥이 주고받는 **저장 센티널**.
    /// 사용자 정의 카테고리 목록에는 절대 들어가지 않는다(들어가면 기본 탭과 겹친다).
    /// ⚠️ 번역 금지 - 화면에 뿌릴 때만 현지화한다.
    static let basicCategoryName = "기본"

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 기기 간 **동기화용** 스냅샷 - 실제로 쓰이는 카테고리만 담는다.
    ///
    /// ⚠️ 왜 거르나: 첫 실행 온보딩에서 고른 페르소나에 따라 카테고리가 자동으로 심기는데,
    ///    **그 이름이 기기 언어별로 다르다**(회사 이메일 / Work Email / Email Kantor).
    ///    거르지 않고 합치면 폰 2대를 쓸 때 같은 뜻의 카테고리가 언어별로 중복되고,
    ///    서로 다른 페르소나를 골랐다면 양쪽 세트가 통째로 합쳐진다.
    ///
    /// 기준: **비샘플 메모가 하나라도 붙어 있는 카테고리**만 동기화한다.
    /// 사용자가 실제로 쓰기 시작한 것만 다른 기기로 넘어간다.
    /// (백업은 `current()` 로 전부 담는다 - 백업은 "이 기기 상태를 그대로 되살리기"라
    ///  아직 안 쓴 카테고리도 남아 있어야 한다.)
    static func syncable(memos: [Memo], sampleIDs: Set<UUID>) -> CategorySnapshot {
        var snapshot = current()
        snapshot.items = nil   // 항목은 자기 레코드로 간다 - 옛 덩어리에 실으면 두 곳에서 다른 값을 들게 된다
        let usedNames = Set(
            memos.filter { !sampleIDs.contains($0.id) }
                 .map(\.category)
                 .filter { !$0.isEmpty && $0 != basicCategoryName }
        )
        snapshot.categories = snapshot.categories.filter { usedNames.contains($0) }

        // ⛔️ 여기서 `memo.category` 에 있는 이름을 목록에 **더하지 않는다.**
        //
        //    한때 그렇게 했다. "목록에는 없는데 단축어는 이미 그 카테고리에 들어 있는" 경우를
        //    받아 주려던 것이었는데, 카테고리가 걷잡을 수 없이 불어났다. 고리는 이렇다.
        //
        //      올릴 때는 payload 를 **교체**하고, 받을 때는 `.merge` 로 **더하기만** 한다.
        //      그래서 memo.category 문자열이 한 번 목록에 들어가면 다시는 빠지지 않는다.
        //      기기를 오갈 때마다 쌓이기만 하는 래칫이 된다.
        //
        //    들어오는 이름이 사용자가 만든 카테고리라는 보장도 없다. 지운 카테고리를 아직
        //    달고 있는 단축어, 다른 언어로 심긴 페르소나 이름, 가져오기로 들어온 임의의
        //    문자열이 전부 **사용자가 만든 카테고리**로 승격됐다. 한 기기에서도 동기화가
        //    한 바퀴 돌면 그대로 불어난다.
        //
        //    ⚠️ 카테고리는 **사용자가 만들 때만** 늘어난다. 앱이 알아서 늘리지 않는다.
        //       목록이 빈약한 기기가 공용 레코드를 덮어쓰는 문제는 이 자리가 아니라
        //       올리는 자리에서 풀어야 한다(MemoSyncEngine.makeCategoryRecord).

        snapshot.icons = snapshot.icons.filter { usedNames.contains($0.key) }
        snapshot.colors = snapshot.colors.filter { usedNames.contains($0.key) }
        // ⚠️ 즐겨찾기 숨김은 카테고리 이름이 아니라 센티널이라 `usedNames` 에 절대 걸리지 않는다.
        //    그냥 거르면 "즐겨찾기 탭을 숨김" 설정이 기기 간에 영영 넘어가지 않는다.
        snapshot.hiddenTabs = snapshot.hiddenTabs.filter {
            $0 == CategoryBucketRule.favoritesTabKey || usedNames.contains($0)
        }
        return snapshot
    }

    /// 올릴 스냅샷을 **원격에 이미 있는 것 위에 얹는다.**
    ///
    /// 왜: 올리는 쪽은 payload 를 통째로 **교체**한다. 그래서 목록이 빈약한 기기가 한 번
    /// 올리면 공용 레코드가 그만큼 깎인다. 받는 쪽은 `.merge` 라 더하기만 하므로 **원본
    /// 기기는 멀쩡해 보이고**, 새로 붙는 기기만 빈약한 목록을 받아 고착된다.
    /// 실제로 맥에서 단축어 37개가 카테고리 12개를 쓰는데 탭은 2개만 서던 사고가 이것이었다.
    ///
    /// ⚠️ 여기서 **카테고리를 새로 만들지 않는다.** 원격에 이미 있는 것을 지우지 않을 뿐이다.
    ///    한때 `syncable` 이 `memo.category` 문자열을 목록으로 승격시켜 카테고리가 걷잡을 수
    ///    없이 불어난 적이 있다. 늘리는 것은 사용자뿐이다.
    ///
    /// ⚠️ `hiddenTabs` 는 합치지 **않는다.** 그건 "사용자가 치운 것" 목록이라, 합치면
    ///    한 기기에서 숨긴 탭을 다른 기기에서 영영 못 되살린다. 더하기만 하는 목록에
    ///    "숨김"을 넣으면 한 방향으로만 굳는다.
    static func union(local: CategorySnapshot, remote: CategorySnapshot) -> CategorySnapshot {
        var merged = local

        var seen = Set(local.categories)
        for name in remote.categories where seen.insert(name).inserted {
            merged.categories.append(name)
        }

        // 아이콘·색은 이 기기 것이 이긴다. 원격에만 있는 것은 그대로 데려온다.
        merged.icons = remote.icons.merging(local.icons) { _, mine in mine }
        merged.colors = remote.colors.merging(local.colors) { _, mine in mine }

        // ⚠️ `enabledBuiltIns` 도 합치지 **않는다.** 숨김과 같은 성격이라 - 켠 것만 넘어가고
        //    끈 것은 안 넘어가면 기본 제공 탭이 기기를 오갈수록 늘기만 한다.
        //    (`merged` 가 `local` 에서 시작하므로 이 기기 값이 그대로 올라간다)

        merged.featureEnabled = local.featureEnabled || remote.featureEnabled
        return merged
    }

    /// 현재 기기의 카테고리 설정을 읽어 스냅샷으로 만든다. (백업용 - 전부 담는다)
    static func current() -> CategorySnapshot {
        guard let d = defaults else { return CategorySnapshot() }
        return CategorySnapshot(
            categories: d.stringArray(forKey: categoriesKey) ?? [],
            icons: (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:],
            colors: (d.dictionary(forKey: colorsKey) as? [String: String]) ?? [:],
            hiddenTabs: d.stringArray(forKey: hiddenTabsKey) ?? [],
            enabledBuiltIns: d.stringArray(forKey: enabledBuiltInsKey) ?? [],
            featureEnabled: d.bool(forKey: featureEnabledKey),
            items: {
                let items = CategoryItemStore.load()
                return items.isEmpty ? nil : items.values.sorted { $0.id.uuidString < $1.id.uuidString }
            }()
        )
    }

    /// 스냅샷을 기기에 적용한다.
    ///
    /// ⚠️ **비어 있는 스냅샷으로 기존 설정을 지우지 않는다.** 복원 데이터에 카테고리가
    ///    없다고 해서 이미 잘 쓰고 있던 카테고리를 날리면 그게 더 큰 사고다.
    ///
    /// - `.replace` (백업 복원): **그 시점 상태로 되돌린다.** 목록·아이콘·색·숨김·기본 제공까지
    ///   스냅샷이 결정한다. 백업에 숨긴 탭이 없었으면 지금도 없어야 한다. 합집합으로 두면
    ///   "되돌렸는데 지운 카테고리가 되살아나 있다"가 되어 복원이 아니게 된다.
    /// - `.merge` (동기화 기본값): **더하기만 한다.** 이 기기에만 있는 것을 다른 기기가
    ///   지우면 안 되기 때문이다.
    static func apply(_ snapshot: CategorySnapshot, strategy: MergeStrategy = .merge) {
        guard let d = defaults, !snapshot.isEmpty else { return }

        switch strategy {
        case .replace:
            // 백업에 항목이 있으면 그대로 되살린다 - 이름이 같은 카테고리가 다른 기기와 같은 id 로 이어진다.
            // 없으면(옛 백업) 다음 동기화가 목록에서 새로 만든다.
            if let items = snapshot.items, !items.isEmpty {
                CategoryItemStore.save(Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }))
                CategoryItemStore.markMigrated()
            }
            d.set(snapshot.categories, forKey: categoriesKey)
            d.set(snapshot.icons, forKey: iconsKey)
            d.set(snapshot.colors, forKey: colorsKey)
            d.set(snapshot.hiddenTabs, forKey: hiddenTabsKey)
            d.set(snapshot.enabledBuiltIns, forKey: enabledBuiltInsKey)

        case .merge, .sync:
            var merged = d.stringArray(forKey: categoriesKey) ?? []
            for name in snapshot.categories where !merged.contains(name) {
                merged.append(name)
            }
            d.set(merged, forKey: categoriesKey)

            // 아이콘·색은 합집합 - 한쪽에만 있는 설정이 사라지지 않게.
            var icons = (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:]
            for (name, symbol) in snapshot.icons where icons[name] == nil { icons[name] = symbol }
            if !icons.isEmpty { d.set(icons, forKey: iconsKey) }

            var colors = (d.dictionary(forKey: colorsKey) as? [String: String]) ?? [:]
            for (name, hex) in snapshot.colors where colors[name] == nil { colors[name] = hex }
            if !colors.isEmpty { d.set(colors, forKey: colorsKey) }

            if strategy == .sync {
                // 숨김·기본 제공은 **재고가 아니라 상태**다 - "지금 이 사람이 원하는 화면 구성".
                // 그래서 받는 쪽도 그대로 비춘다(거울). 합집합으로 두면 켠 것·숨긴 것만
                // 넘어가고 **끈 것·되살린 것은 영영 안 넘어가서**, 기기를 오갈수록 설정이
                // 쌓이기만 하는 래칫이 된다(아이폰에서 탭을 꺼도 맥에는 계속 남았다).
                // 올리는 쪽이 이미 이 두 필드를 합치지 않으므로(CategorySnapshotStore.union),
                // 원격 레코드는 "마지막에 동기화한 기기의 구성"이고 모두가 그리로 수렴한다.
                d.set(snapshot.hiddenTabs, forKey: hiddenTabsKey)
                d.set(snapshot.enabledBuiltIns, forKey: enabledBuiltInsKey)
            } else {
                // 가져오기(.merge)는 "합친다"는 뜻이라 이 기기 설정을 파일이 지우면 안 된다.
                if !snapshot.hiddenTabs.isEmpty {
                    let hidden = Set(d.stringArray(forKey: hiddenTabsKey) ?? []).union(snapshot.hiddenTabs)
                    d.set(Array(hidden), forKey: hiddenTabsKey)
                }
                if !snapshot.enabledBuiltIns.isEmpty {
                    let builtIns = Set(d.stringArray(forKey: enabledBuiltInsKey) ?? []).union(snapshot.enabledBuiltIns)
                    d.set(Array(builtIns), forKey: enabledBuiltInsKey)
                }
            }
        }

        // 카테고리가 하나라도 생기면 기능은 켜 준다 - 복원했는데 기능이 꺼져 있어
        // 탭이 안 보이면 사용자는 "복원 실패"로 받아들인다.
        if snapshot.featureEnabled || !snapshot.categories.isEmpty {
            d.set(true, forKey: featureEnabledKey)
        }

        AppLog.info(.store, "🗂 [CategorySnapshot.apply] 카테고리 \(snapshot.categories.count)개 · 아이콘 \(snapshot.icons.count) · 색 \(snapshot.colors.count) 적용(\(strategy))")
    }

    /// 동기화로 받은 카테고리 항목을 열쇠에 쓴다(`CategorySyncCore.project` 의 결과).
    /// 목록·아이콘·색·숨김만 쓴다. 기본 제공 카테고리 설정은 건드리지 않는다.
    static func writeItemFields(_ snapshot: CategorySnapshot) {
        guard let d = defaults else { return }
        d.set(snapshot.categories, forKey: categoriesKey)
        d.set(snapshot.icons, forKey: iconsKey)
        d.set(snapshot.colors, forKey: colorsKey)
        d.set(snapshot.hiddenTabs, forKey: hiddenTabsKey)
        if snapshot.featureEnabled { d.set(true, forKey: featureEnabledKey) }
    }

    /// 옛 `category-settings` 덩어리에서 **화면 구성만** 비춘다: 기본 제공 카테고리, 즐겨찾기 숨김, 기능 켬.
    /// 카테고리 목록·숨김은 카테고리 항목이 옮기므로 여기서 건드리지 않는다.
    static func applyLayout(_ snapshot: CategorySnapshot) {
        guard let d = defaults else { return }
        d.set(snapshot.enabledBuiltIns, forKey: enabledBuiltInsKey)
        let favorites = CategoryBucketRule.favoritesTabKey
        var hidden = (d.stringArray(forKey: hiddenTabsKey) ?? []).filter { $0 != favorites }
        if snapshot.hiddenTabs.contains(favorites) { hidden.append(favorites) }
        d.set(hidden, forKey: hiddenTabsKey)
        if snapshot.featureEnabled { d.set(true, forKey: featureEnabledKey) }
    }

    enum MergeStrategy: CustomStringConvertible {
        case replace, merge, sync
        var description: String {
            switch self {
            case .replace: return "replace"
            case .merge:   return "merge"
            case .sync:    return "sync"
            }
        }
    }

    // MARK: - 메모에서 역산 (구버전 백업 구제)

    /// 카테고리 메타가 없는 **옛 백업**을 복원했을 때, 메모들의 `category` 값에서
    /// 카테고리 목록을 되살린다.
    ///
    /// ⚠️ 이름만 복구된다 - 아이콘·숨김·순서는 원래 스냅샷에만 있으므로 알 수 없다.
    ///    그래도 탭이 통째로 사라지는 것보다는 낫다.
    /// - Returns: 새로 추가된 카테고리 이름들.
    @discardableResult
    static func rebuildFromMemos(_ memos: [Memo]) -> [String] {
        guard let d = defaults else { return [] }

        let existing = d.stringArray(forKey: categoriesKey) ?? []
        // "기본"은 시스템 기본값이라 사용자 정의 목록에 넣지 않는다.
        let derived = memos
            .map(\.category)
            .filter { !$0.isEmpty && $0 != basicCategoryName }
        // 등장 순서를 유지하면서 중복 제거 - 사용자가 많이 쓴 순서에 가깝다.
        var seen = Set(existing)
        var added: [String] = []
        for name in derived where !seen.contains(name) {
            seen.insert(name)
            added.append(name)
        }
        guard !added.isEmpty else { return [] }

        d.set(existing + added, forKey: categoriesKey)
        d.set(true, forKey: featureEnabledKey)
        AppLog.info(.store, "🗂 [CategorySnapshot.rebuildFromMemos] 메모에서 카테고리 \(added.count)개 복구")
        return added
    }
}

// MARK: - 카테고리 항목 동기화 (카테고리 하나에 레코드 하나)
//
// 위의 스냅샷은 목록 전체를 한 덩어리로 옮긴다. 그래서 "목록에 없다"가 지운 것인지
// 그 기기가 아직 모르는 것인지 가를 수 없어, 동기화는 더하기만 하게 됐다. 지운 카테고리가
// 되살아나고, 이름을 바꾸면 옛 이름이 다른 기기에 남았다.
//
// → 카테고리마다 id, 수정 시각, 삭제 표시를 둔다. 단축어 동기화와 같은 방식이다.
//
// ⚠️ **원본은 여전히 위의 App Group 열쇠들이다.** 그 열쇠에 쓰는 곳이 앱·키보드·맥에 여럿이라
//    한꺼번에 바꾸면 하나만 놓쳐도 설정이 되돌아간다. 대신 단축어가 `memos.data` 를 원본으로
//    두고 섀도와 비교해 바뀐 것만 올리듯, 여기서도 열쇠를 읽어 항목을 갱신하고(`refresh`),
//    받은 항목은 열쇠에 다시 쓴다(`project`). 어디서 바꾸든 다음 동기화에 잡힌다.
//
// 설계: docs/engineering/CATEGORY_SYNC_UNIFICATION.md (iOS 저장소)

struct CategoryItem: Codable, Equatable {
    /// 만들 때 정하고 바뀌지 않는다. 이름을 바꿔도 그대로.
    let id: UUID
    var name: String
    /// 탭 순서. 목록에서의 자리.
    var order: Double
    var icon: String?
    var colorHex: String?
    var isHidden: Bool
    /// 이름이 겹칠 때 누구를 남길지 정하는 기준.
    var createdAt: Date
    /// 이 카테고리의 마지막 수정. 기기 간 병합의 기준.
    var lastEdited: Date
    /// 지웠으면 그 시각. 항목은 남겨 두어야 다른 기기의 사본을 이길 수 있다.
    var deletedAt: Date?

    var isDeleted: Bool { deletedAt != nil }

    init(id: UUID, name: String, order: Double, icon: String?, colorHex: String?, isHidden: Bool,
         createdAt: Date, lastEdited: Date, deletedAt: Date?) {
        self.id = id
        self.name = name
        self.order = order
        self.icon = icon
        self.colorHex = colorHex
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.lastEdited = lastEdited
        self.deletedAt = deletedAt
    }

    /// 관용 디코더 - 다른 버전이 만든 항목을 읽는다.
    /// id·이름만 있으면 나머지는 기본값으로 채운다. 모르는 필드는 무시한다.
    /// ⚠️ 필드를 더할 땐 **선택형으로만** 더한다. 이 버전은 모르는 필드를 읽지 못하고, 다시 올릴 때
    ///    그 필드는 빠진다. 없어도 뜻이 통하는 필드여야 한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        order = try c.decodeIfPresent(Double.self, forKey: .order) ?? 0
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        lastEdited = try c.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date(timeIntervalSince1970: 0)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? lastEdited
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, order, icon, colorHex, isHidden, createdAt, lastEdited, deletedAt
    }

    /// 시각을 뺀 내용이 같은지 - 열쇠에서 다시 읽었을 때 "바뀌었나"를 가른다.
    func hasSameContent(as other: CategoryItem) -> Bool {
        name == other.name && order == other.order && icon == other.icon
            && colorHex == other.colorHex && isHidden == other.isHidden && isDeleted == other.isDeleted
    }
}

enum CategorySyncCore {

    /// 레코드 이름 앞머리. 옛 버전은 UUID 가 아닌 이름을 단축어로 읽지 않고 건너뛴다.
    /// 레코드 종류는 `CategorySettings` 다(`MemoSyncEngine.makeCategoryItemRecord` 의 이유 참고).
    static let recordPrefix = "categoryitem."
    /// 개발 빌드가 한때 `Memo` 종류로 올린 이름. 같은 이름은 종류를 바꿀 수 없어 앞머리를 새로 잡았다.
    /// 받으면 항목으로 읽기만 하고(잃지 않게), 새 빌드가 처음 뜰 때 지운다(`MemoSyncEngine.cleanUpLegacyCategoryRecords`).
    static let legacyRecordPrefix = "category."

    static func recordName(_ id: UUID) -> String { recordPrefix + id.uuidString }
    static func legacyRecordName(_ id: UUID) -> String { legacyRecordPrefix + id.uuidString }

    /// 새 이름과 옛 이름 모두에서 id 를 읽는다.
    static func id(fromRecordName name: String) -> UUID? {
        for prefix in [recordPrefix, legacyRecordPrefix] where name.hasPrefix(prefix) {
            return UUID(uuidString: String(name.dropFirst(prefix.count)))
        }
        return nil
    }

    /// 사용자 카테고리가 아닌 이름 - 전용 탭이 따로 있어 항목으로 만들지 않는다.
    static let protectedNames: Set<String> = ["기본", "텍스트", "이미지"]

    /// 이름에서 정해지는 id. **처음 옮길 때만** 쓴다.
    /// 두 기기가 동시에 옮겨도 같은 이름은 같은 id 가 되어 둘로 갈라지지 않는다.
    /// ⚠️ 옮긴 뒤 새로 만드는 카테고리에는 쓰지 않는다. "A 를 B 로 바꾼 뒤 A 를 새로 만들기"가
    ///    같은 id 로 부딪힌다.
    static func nameBasedID(_ name: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(("category:" + name).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // 이름 기반(v5) 표시
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// 올린 것과 비교하는 지문(시각까지 포함).
    static func fingerprint(_ item: CategoryItem) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(item)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 열쇠(스냅샷)를 읽어 항목을 갱신한다.
    ///
    /// - 목록에 있는 이름: 항목이 있으면 내용을 맞추고, 달라졌으면 수정 시각을 `now` 로.
    ///   없으면 `eligible` 한 이름만 새 항목으로 만든다.
    /// - 살아 있던 항목인데 목록에서 사라졌으면 지운 것으로 표시한다.
    /// - Parameters:
    ///   - eligible: 새 항목으로 만들 이름인지. 페르소나로 자동으로 심긴 빈 카테고리를 거른다.
    ///   - migrating: 처음 옮기는 중인지. 그러면 이름 기반 id 에 **가장 옛날 시각**을 준다 -
    ///     이미 있던 상태를 옮기는 것이지 새 편집이 아니므로, 다른 기기에 기록이 있으면 그쪽이 이긴다
    ///     (다른 기기에서 이미 지운 카테고리를 옮기다가 되살리지 않게).
    static func refresh(items: [UUID: CategoryItem], from snapshot: CategorySnapshot,
                        eligible: (String) -> Bool, migrating: Bool, now: Date) -> [UUID: CategoryItem] {
        var result = items
        var aliveByName: [String: UUID] = [:]
        for item in items.values where !item.isDeleted { aliveByName[item.name] = item.id }

        let hidden = Set(snapshot.hiddenTabs)
        var listed = Set<String>()
        for (index, name) in snapshot.categories.enumerated() where !protectedNames.contains(name) {
            listed.insert(name)
            let order = Double(index)
            let icon = snapshot.icons[name]
            let color = snapshot.colors[name]
            let isHidden = hidden.contains(name)

            if let id = aliveByName[name], var item = result[id] {
                var updated = item
                updated.order = order
                updated.icon = icon
                updated.colorHex = color
                updated.isHidden = isHidden
                if !updated.hasSameContent(as: item) {
                    updated.lastEdited = now
                    item = updated
                    result[id] = item
                }
                continue
            }
            guard eligible(name) else { continue }
            let stamp = migrating ? Date(timeIntervalSince1970: 0) : now
            let id = migrating ? nameBasedID(name) : UUID()
            // 이름 기반 id 가 이미 지운 항목으로 있으면 되살리지 않는다(다른 기기가 지운 것).
            if let existing = result[id], existing.isDeleted, migrating { continue }
            result[id] = CategoryItem(id: id, name: name, order: order, icon: icon, colorHex: color,
                                      isHidden: isHidden, createdAt: stamp, lastEdited: stamp, deletedAt: nil)
            aliveByName[name] = id
        }

        for (id, item) in result where !item.isDeleted && !listed.contains(item.name) {
            var deleted = item
            deleted.deletedAt = now
            deleted.lastEdited = now
            result[id] = deleted
        }
        return result
    }

    /// 최신 우선 비교 - 시각이 같으면 지문 사전순(어느 기기에서 계산해도 같은 승자).
    static func isNewer(_ lhs: CategoryItem, than rhs: CategoryItem) -> Bool {
        if lhs.lastEdited != rhs.lastEdited { return lhs.lastEdited > rhs.lastEdited }
        return fingerprint(lhs) > fingerprint(rhs)
    }

    struct MergeResult: Equatable {
        var items: [UUID: CategoryItem]
        /// 로컬이 이겨서 다시 올려야 하는 항목.
        var toReupload: Set<UUID>
    }

    /// 받은 항목을 합친다. 항목마다 최신 우선. 로컬이 이기면 다시 올린다(안 올리면 상대가 제 것을 계속 든다).
    static func merge(local: [UUID: CategoryItem], remote: [CategoryItem]) -> MergeResult {
        var items = local
        var reupload = Set<UUID>()
        for r in remote {
            guard let l = items[r.id] else { items[r.id] = r; continue }
            if isNewer(r, than: l) {
                items[r.id] = r
            } else if isNewer(l, than: r) {
                reupload.insert(r.id)
            }
        }
        return MergeResult(items: items, toReupload: reupload)
    }

    /// 이름이 같은 살아 있는 항목을 하나로 줄인다. 먼저 만든 것(같으면 id 사전순)을 남긴다.
    /// 끊긴 두 기기가 같은 이름을 따로 만들었거나, 한쪽이 다른 카테고리를 그 이름으로 바꾼 경우다.
    /// - Returns: 정리한 항목과, 바뀌어서 올려야 하는 id.
    static func dedupe(_ items: [UUID: CategoryItem], now: Date) -> (items: [UUID: CategoryItem], changed: Set<UUID>) {
        var result = items
        var changed = Set<UUID>()
        let groups = Dictionary(grouping: items.values.filter { !$0.isDeleted }, by: \.name)
        for (_, group) in groups where group.count > 1 {
            let sorted = group.sorted {
                $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString
            }
            var keeper = sorted[0]
            for loser in sorted.dropFirst() {
                if keeper.icon == nil, let icon = loser.icon { keeper.icon = icon }
                if keeper.colorHex == nil, let color = loser.colorHex { keeper.colorHex = color }
                var gone = loser
                gone.deletedAt = now
                gone.lastEdited = now
                result[loser.id] = gone
                changed.insert(loser.id)
            }
            if keeper != sorted[0] {
                keeper.lastEdited = now
                result[keeper.id] = keeper
                changed.insert(keeper.id)
            }
        }
        return (result, changed)
    }

    /// 항목을 열쇠(스냅샷)에 되쓴다.
    ///
    /// 항목이 아는 이름(살았든 지웠든)만 손댄다. 항목이 모르는 이름(페르소나로 심긴 빈 카테고리 등)과
    /// 즐겨찾기 숨김 같은 표시, 기본 제공 카테고리 설정은 그대로 둔다.
    /// - Parameter formerNames: 받기 **전** 항목들의 이름. 이름 변경을 받으면 옛 이름은 어느 항목에도
    ///   없어서 "모르는 이름"으로 남는데, 남기면 다음 갱신이 그것을 새 카테고리로 되살린다.
    static func project(_ items: [UUID: CategoryItem], onto current: CategorySnapshot,
                        formerNames: Set<String> = []) -> CategorySnapshot {
        var snapshot = current
        let alive = items.values.filter { !$0.isDeleted }.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let known = Set(items.values.map(\.name)).union(formerNames)
        let aliveNames = Set(alive.map(\.name))

        snapshot.categories = alive.map(\.name)
            + current.categories.filter { !known.contains($0) && !aliveNames.contains($0) }

        var icons = current.icons.filter { !known.contains($0.key) }
        var colors = current.colors.filter { !known.contains($0.key) }
        var hidden = current.hiddenTabs.filter { !known.contains($0) }
        for item in alive {
            if let icon = item.icon { icons[item.name] = icon }
            if let color = item.colorHex { colors[item.name] = color }
            if item.isHidden { hidden.append(item.name) }
        }
        snapshot.icons = icons
        snapshot.colors = colors
        snapshot.hiddenTabs = hidden
        if !alive.isEmpty { snapshot.featureEnabled = true }
        return snapshot
    }
}

extension Notification.Name {
    /// 카테고리 열쇠(목록·아이콘·색·숨김)가 바뀌었다 - 동기화 엔진만 듣는다.
    /// `.memoDataChanged` 에 얹지 않는 이유: 그 알림은 목록 새로고침·검색 색인 등 여럿이 들어서
    /// 카테고리 하나 숨길 때마다 전부 다시 돈다.
    static let categoryDataChanged = Notification.Name("CategoryDataChanged")
}

extension CategorySnapshotStore {
    /// 카테고리 열쇠에 쓴 뒤 부른다. 엔진이 곧바로 항목을 갱신해 올린다.
    static func notifyChanged() {
        NotificationCenter.default.post(name: .categoryDataChanged, object: nil)
    }
}

/// 항목과 "올린 것" 섀도를 App Group 에 둔다.
enum CategoryItemStore {
    static let itemsKey = "category.sync.items"
    static let shadowKey = "category.sync.shadow"
    /// 처음 옮기기를 마쳤는지 - 그 뒤로 새로 보는 이름은 무작위 id 로 만든다.
    static let migratedKey = "category.sync.migrated"

    private static var defaults: UserDefaults? { AppGroup.defaults }

    static func load() -> [UUID: CategoryItem] {
        guard let data = defaults?.data(forKey: itemsKey),
              let list = try? JSONDecoder().decode([CategoryItem].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func save(_ items: [UUID: CategoryItem]) {
        let list = items.values.sorted { $0.id.uuidString < $1.id.uuidString }
        defaults?.set(try? JSONEncoder().encode(list), forKey: itemsKey)
    }

    static func loadShadow() -> [UUID: String] {
        guard let data = defaults?.data(forKey: shadowKey),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }

    static func saveShadow(_ shadow: [UUID: String]) {
        let raw = Dictionary(uniqueKeysWithValues: shadow.map { ($0.key.uuidString, $0.value) })
        defaults?.set(try? JSONEncoder().encode(raw), forKey: shadowKey)
    }

    static var isMigrated: Bool { defaults?.bool(forKey: migratedKey) == true }
    static func markMigrated() { defaults?.set(true, forKey: migratedKey) }

    /// 이름 바꾸기를 항목에 옮긴다 - id 를 지켜야 다른 기기에서 "지우고 새로 만들기"가 되지 않는다.
    static func rename(from oldName: String, to newName: String, now: Date = Date()) {
        var items = load()
        guard let item = items.values.first(where: { $0.name == oldName && !$0.isDeleted }) else { return }
        var renamed = item
        renamed.name = newName
        renamed.lastEdited = now
        items[item.id] = renamed
        save(items)
    }

    /// 모든 데이터 삭제용. 남기면 지운 카테고리가 "삭제"로 모든 기기에 퍼진다.
    static let allKeys = [itemsKey, shadowKey, migratedKey]
}
