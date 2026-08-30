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

struct CategorySnapshot: Codable, Equatable {

    /// 사용자 정의 카테고리 - **순서가 곧 탭 순서**라 배열로 둔다.
    var categories: [String] = []
    /// [카테고리명: SF Symbol 이름]
    var icons: [String: String] = [:]
    /// 사용자가 숨긴 탭 이름.
    var hiddenTabs: [String] = []
    /// 켜 둔 기본 제공 카테고리(BuiltInCategory.rawValue).
    var enabledBuiltIns: [String] = []
    /// 카테고리 기능 자체를 켰는지.
    var featureEnabled: Bool = false
    /// 이 스냅샷을 만든 시각 - 동기화 충돌 시 최신 우선 판단에 쓴다.
    var updatedAt: Date = Date()

    var isEmpty: Bool {
        categories.isEmpty && icons.isEmpty && hiddenTabs.isEmpty && enabledBuiltIns.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case categories, icons, hiddenTabs, enabledBuiltIns, featureEnabled, updatedAt
    }

    init(categories: [String] = [], icons: [String: String] = [:], hiddenTabs: [String] = [],
         enabledBuiltIns: [String] = [], featureEnabled: Bool = false, updatedAt: Date = Date()) {
        self.categories = categories
        self.icons = icons
        self.hiddenTabs = hiddenTabs
        self.enabledBuiltIns = enabledBuiltIns
        self.featureEnabled = featureEnabled
        self.updatedAt = updatedAt
    }

    /// 관용 디코더 - 누락 키를 전부 기본값으로 허용한다(하위·상위 호환).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        self.icons = try c.decodeIfPresent([String: String].self, forKey: .icons) ?? [:]
        self.hiddenTabs = try c.decodeIfPresent([String].self, forKey: .hiddenTabs) ?? []
        self.enabledBuiltIns = try c.decodeIfPresent([String].self, forKey: .enabledBuiltIns) ?? []
        self.featureEnabled = try c.decodeIfPresent(Bool.self, forKey: .featureEnabled) ?? false
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - App Group UserDefaults ↔ 스냅샷

enum CategorySnapshotStore {

    // ⚠️ 키 이름은 CategoryStore/CategoryIconSettings 와 **정확히 같아야 한다**.
    //    한 글자만 달라도 조용히 빈 값이 되어 "복원했는데 카테고리가 없다"가 반복된다.
    static let categoriesKey = "userDefinedCategories_v1"
    static let iconsKey = "userCategoryIcons_v1"
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
        let usedNames = Set(
            memos.filter { !sampleIDs.contains($0.id) }
                 .map(\.category)
                 .filter { !$0.isEmpty && $0 != basicCategoryName }
        )
        snapshot.categories = snapshot.categories.filter { usedNames.contains($0) }

        // ⚠️ 이 기기의 **목록에는 없는데 단축어는 이미 그 카테고리에 들어 있는** 경우를 받아 준다.
        //    없으면 이런 고리가 생긴다: 목록이 빈약한 기기가 올린 스냅샷이 공용 레코드를
        //    통째로 덮어쓰고(payload 는 병합이 아니라 교체다), 그 기기는 자기가 올린 빈약한
        //    목록을 그대로 되받아 고착된다. 받는 쪽은 `.merge` 라 더하기만 하므로 **원본 기기는
        //    멀쩡해 보이고**, 빈약한 기기에서만 카테고리가 사라진다.
        //    실제로 맥에서 단축어 37개가 카테고리 12개를 쓰는데 탭은 2개만 서고 나머지 23개가
        //    전부 기본 칸으로 떠밀린 사고가 이것이었다.
        //    "비샘플 메모가 붙은 카테고리만 싣는다"는 원래 의도는 그대로다 - `usedNames` 가
        //    이미 샘플과 빈 값과 기본 센티널을 걸러 낸다.
        //    등장 순서를 유지해 `rebuildFromMemos` 와 같은 순서로 붙인다.
        var seen = Set(snapshot.categories)
        for memo in memos where !sampleIDs.contains(memo.id) {
            let name = memo.category
            guard usedNames.contains(name), !seen.contains(name) else { continue }
            seen.insert(name)
            snapshot.categories.append(name)
        }

        snapshot.icons = snapshot.icons.filter { usedNames.contains($0.key) }
        // ⚠️ 즐겨찾기 숨김은 카테고리 이름이 아니라 센티널이라 `usedNames` 에 절대 걸리지 않는다.
        //    그냥 거르면 "즐겨찾기 탭을 숨김" 설정이 기기 간에 영영 넘어가지 않는다.
        snapshot.hiddenTabs = snapshot.hiddenTabs.filter {
            $0 == CategoryBucketRule.favoritesTabKey || usedNames.contains($0)
        }
        return snapshot
    }

    /// 현재 기기의 카테고리 설정을 읽어 스냅샷으로 만든다. (백업용 - 전부 담는다)
    static func current() -> CategorySnapshot {
        guard let d = defaults else { return CategorySnapshot() }
        return CategorySnapshot(
            categories: d.stringArray(forKey: categoriesKey) ?? [],
            icons: (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:],
            hiddenTabs: d.stringArray(forKey: hiddenTabsKey) ?? [],
            enabledBuiltIns: d.stringArray(forKey: enabledBuiltInsKey) ?? [],
            featureEnabled: d.bool(forKey: featureEnabledKey)
        )
    }

    /// 스냅샷을 기기에 적용한다.
    ///
    /// ⚠️ **비어 있는 스냅샷으로 기존 설정을 지우지 않는다.** 복원 데이터에 카테고리가
    ///    없다고 해서 이미 잘 쓰고 있던 카테고리를 날리면 그게 더 큰 사고다.
    /// - Parameter mergeStrategy: `.replace` 는 순서까지 스냅샷 기준으로, `.merge` 는
    ///   기존에 없는 것만 뒤에 덧붙인다(동기화 기본값).
    static func apply(_ snapshot: CategorySnapshot, strategy: MergeStrategy = .merge) {
        guard let d = defaults, !snapshot.isEmpty else { return }

        switch strategy {
        case .replace:
            d.set(snapshot.categories, forKey: categoriesKey)
        case .merge:
            var merged = d.stringArray(forKey: categoriesKey) ?? []
            for name in snapshot.categories where !merged.contains(name) {
                merged.append(name)
            }
            d.set(merged, forKey: categoriesKey)
        }

        // 아이콘·숨김은 합집합 - 한쪽에만 있는 설정이 사라지지 않게.
        var icons = (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:]
        for (name, symbol) in snapshot.icons where icons[name] == nil { icons[name] = symbol }
        if !icons.isEmpty { d.set(icons, forKey: iconsKey) }

        if !snapshot.hiddenTabs.isEmpty {
            let hidden = Set(d.stringArray(forKey: hiddenTabsKey) ?? []).union(snapshot.hiddenTabs)
            d.set(Array(hidden), forKey: hiddenTabsKey)
        }
        if !snapshot.enabledBuiltIns.isEmpty {
            let builtIns = Set(d.stringArray(forKey: enabledBuiltInsKey) ?? []).union(snapshot.enabledBuiltIns)
            d.set(Array(builtIns), forKey: enabledBuiltInsKey)
        }
        // 카테고리가 하나라도 생기면 기능은 켜 준다 - 복원했는데 기능이 꺼져 있어
        // 탭이 안 보이면 사용자는 "복원 실패"로 받아들인다.
        if snapshot.featureEnabled || !snapshot.categories.isEmpty {
            d.set(true, forKey: featureEnabledKey)
        }

        AppLog.info(.store, "🗂 [CategorySnapshot.apply] 카테고리 \(snapshot.categories.count)개 적용(\(strategy))")
    }

    enum MergeStrategy: CustomStringConvertible {
        case replace, merge
        var description: String { self == .replace ? "replace" : "merge" }
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
