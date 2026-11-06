//
//  MacPlan.swift
//  ClipKeyboard.tap
//
//  무료 · Plus · Pro 세 칸. 이 맥 앱이 **스스로 파는** 상품(StoreKit 2)과, 그 상품이 여는 것.
//
//  - 무료: 단축어를 100번 붙여넣을 때까지 모든 기능. 그 뒤로는 새로 만들기 단축어 10 · 템플릿 3 ·
//          이미지 단축어 5, 클립보드 기록 50개. 이미 만든 것은 한도를 넘어도 그대로 쓰고 지운다.
//  - Plus: 만들기 무제한, 클립보드 기록 100개.
//  - Pro:  + iCloud 백업 · 되돌리기, 아이폰과 실시간 동기화, 스택 · 보안 단축어 꺼내기.
//
//  ⚠️ 5.0.5(20)은 Guideline 2.1(b) 로 거절됐다 — 화면에 Pro 가 있는데 **이 앱 레코드에 제출된 IAP 가
//     없었다**(아이폰 결제를 iCloud 로 비춰 잠그던 시절). 그래서 여기는 아이폰 구매를 보지 않는다.
//     이 앱이 파는 상품만 권한이 되고, 상품을 불러오지 못하면 Pro 라는 말도 페이월도 보이지 않는다.
//     심사에 낼 때는 아래 상품을 **같은 버전과 함께 제출**해야 한다.
//  ⚠️ 상품 ID 에는 하이픈을 쓸 수 없어 번들 ID(`com.ysoup.TokenMemo-tap`)의 `-` 를 `.` 으로 바꿨다(팁과 같다).
//

import AppKit
import Combine
import Foundation
import LeeoKit
import StoreKit

/// 칸. 위 칸은 아래 칸이 여는 것을 모두 연다.
enum MacTier: Int, Comparable {
    case free, plus, pro
    static func < (a: MacTier, b: MacTier) -> Bool { a.rawValue < b.rawValue }
}

/// 칸이 여는 것.
enum MacPlanFeature {
    /// 단축어 · 템플릿 · 이미지 단축어를 한도 없이 새로 만들기
    case unlimitedItems
    /// 클립보드 기록 100개
    case longHistory
    /// iCloud 백업 · 되돌리기
    case cloudBackup
    /// 아이폰과 실시간 동기화
    case sync
    /// 아이폰에서 만든 스택 · 보안 단축어 꺼내기
    case stacksAndSecure

    var tier: MacTier {
        switch self {
        case .unlimitedItems, .longHistory: return .plus
        case .cloudBackup, .sync, .stacksAndSecure: return .pro
        }
    }
}

/// 새로 만들 때 한도를 따로 세는 단축어 갈래.
enum MacItemKind {
    case snippet, template, image

    static func of(_ memo: Memo) -> MacItemKind {
        if !memo.imageFileNames.isEmpty || memo.imageFileName != nil || memo.contentType == .image { return .image }
        if memo.isTemplate { return .template }
        return .snippet
    }

    /// 무료로 새로 만들 수 있는 개수.
    var freeLimit: Int {
        switch self {
        case .snippet: return 10
        case .template: return 3
        case .image: return 5
        }
    }
}

/// 상품 기간.
enum MacTerm: CaseIterable {
    case weekly, monthly, yearly, lifetime
}

@MainActor
final class MacPlan: ObservableObject {
    static let shared = MacPlan()

    // MARK: 상품

    enum ID {
        static let prefix = "com.ysoup.TokenMemo.tap."
        static let plusWeekly = prefix + "plus.weekly"
        static let plusMonthly = prefix + "plus.monthly"
        static let plusYearly = prefix + "plus.yearly"
        static let plusLifetime = prefix + "plus"
        static let proWeekly = prefix + "pro.weekly"
        static let proMonthly = prefix + "pro.monthly"
        static let proYearly = prefix + "pro.yearly"
        static let proLifetime = prefix + "pro"
        /// Plus 평생을 산 사람이 Pro 평생으로 올리기.
        static let proUpgrade = prefix + "pro.upgrade"
        /// 구독하던 사람의 Pro 평생(구독 졸업).
        static let proGraduate = prefix + "pro.graduate"
    }

    static let subscriptionIDs: Set<String> = [
        ID.plusWeekly, ID.plusMonthly, ID.plusYearly, ID.proWeekly, ID.proMonthly, ID.proYearly,
    ]
    /// 팔고 권한이 되는 상품 전부. 팁은 넣지 않는다(기능을 열지 않는다).
    static let allProductIDs: [String] = [
        ID.plusWeekly, ID.plusMonthly, ID.plusYearly, ID.plusLifetime,
        ID.proWeekly, ID.proMonthly, ID.proYearly, ID.proLifetime,
        ID.proUpgrade, ID.proGraduate,
    ]

    static func productID(_ tier: MacTier, _ term: MacTerm) -> String {
        switch (tier, term) {
        case (.plus, .weekly): return ID.plusWeekly
        case (.plus, .monthly): return ID.plusMonthly
        case (.plus, .yearly): return ID.plusYearly
        case (.plus, .lifetime): return ID.plusLifetime
        case (_, .weekly): return ID.proWeekly
        case (_, .monthly): return ID.proMonthly
        case (_, .yearly): return ID.proYearly
        case (_, .lifetime): return ID.proLifetime
        }
    }

    static func tier(of productID: String) -> MacTier? {
        switch productID {
        case ID.plusWeekly, ID.plusMonthly, ID.plusYearly, ID.plusLifetime: return .plus
        case ID.proWeekly, ID.proMonthly, ID.proYearly, ID.proLifetime, ID.proUpgrade, ID.proGraduate: return .pro
        default: return nil
        }
    }

    // MARK: 유료 다운로드였던 시절에 산 사람

    /// 페이월이 없던(유료 다운로드) 마지막 판. 이 판까지 받은 사람은 앱을 산 사람이라 Pro 평생이다.
    /// 맥의 `originalAppVersion` 은 `CFBundleShortVersionString` 이다. 빌드 번호로 오면 그쪽으로 비교한다.
    /// ⚠️ 무료로 바꾸는 판은 반드시 이보다 높은 버전이어야 한다(5.1.9 는 이미 나가 있어 다시 쓸 수 없다).
    static let lastPaidVersion = "5.1.9"
    static let lastPaidBuild = 36

    static func boughtBeforeFree(originalAppVersion version: String) -> Bool {
        let trimmed = version.trimmingCharacters(in: .whitespaces)
        if let build = Int(trimmed) { return build <= lastPaidBuild }
        return trimmed.compare(lastPaidVersion, options: .numeric) != .orderedDescending
    }

    // MARK: 상태

    /// 불러온 상품(ID → 상품). 스토어에 아직 없는 상품은 빠진다 — 그 상품 버튼은 서지 않는다.
    @Published private(set) var products: [String: Product] = [:]
    /// 산 것(구독 · 평생 · 유료로 받은 앱)이 여는 칸. 다음 실행이 확인을 마치기 전까지 쓰려고 남겨 둔다.
    @Published private(set) var owned: MacTier
    /// Plus 평생을 샀다 — Pro 평생은 올리기 값으로 판다.
    @Published private(set) var ownsPlusLifetime = false
    /// 평생 Pro(평생 · 올리기 · 졸업 · 유료 다운로드)를 가졌다.
    @Published private(set) var ownsLifetimePro = false
    /// 지금 살아 있는 구독.
    @Published private(set) var subscription: LeeoGraduation.Subscription?
    /// 유료 다운로드 시절에 앱을 산 사람(App Store 가 서명한 첫 구매 판으로 확인).
    @Published private(set) var isPaidDownloadOwner: Bool
    /// 이 기기가 유료 칸 상품을 한 번이라도 불러왔다. 그 전에는 무료 한도로 막지 않는다 —
    /// 상품을 만들기 전에 나간 빌드에서 살 수도 없는데 막히는 사람이 없게.
    @Published private(set) var hasSeenStore: Bool
    /// 붙여넣은 횟수(무료 체험의 문턱).
    @Published private(set) var pastes: Int

    private let defaults = UserDefaults.standard
    private enum Key {
        static let owned = "plan.owned"
        static let paidDownload = "plan.paidDownloadOwner"
        static let seenStore = "plan.seenStore"
        static let pastes = "plan.pastes"
        static let firstPasteAt = "plan.firstPasteAt"
        static let receiptShown = "plan.receiptShown"
    }
    private var updates: Task<Void, Never>?

    private init() {
        owned = MacTier(rawValue: defaults.integer(forKey: Key.owned)) ?? .free
        isPaidDownloadOwner = defaults.bool(forKey: Key.paidDownload)
        hasSeenStore = defaults.bool(forKey: Key.seenStore)
        pastes = defaults.integer(forKey: Key.pastes)
    }

    // MARK: 권한

    /// 무료로 모든 기능을 쓰는 붙여넣기 횟수.
    static let freeUsePastes = 100

    /// 지금 열려 있는 칸. 산 칸, 그리고 체험(100번까지 · 상품을 아직 못 본 기기)은 Pro.
    var tier: MacTier {
        if !hasSeenStore || pastes < Self.freeUsePastes { return .pro }
        return owned
    }

    func allows(_ feature: MacPlanFeature) -> Bool { tier >= feature.tier }

    /// 막혔으면 페이월을 띄우고 false.
    @discardableResult
    func require(_ feature: MacPlanFeature, _ reason: MacPaywallReason) -> Bool {
        guard !allows(feature) else { return true }
        MacPaywall.present(reason)
        return false
    }

    /// 이 갈래를 하나 더 만들 수 있는가. 막혔으면 페이월을 띄운다.
    func requireRoom(for kind: MacItemKind, among memos: [Memo]) -> Bool {
        guard !allows(.unlimitedItems) else { return true }
        let count = memos.filter { MacItemKind.of($0) == kind && !$0.isStack && !$0.isSecure }.count
        guard count >= kind.freeLimit else { return true }
        MacPaywall.present(.limit(kind))
        return false
    }

    /// 클립보드 기록을 남기는 개수.
    var historyLimit: Int { allows(.longHistory) ? 100 : 50 }

    /// 페이월을 보일 수 있는가 — 이 기기에서 유료 칸 상품을 불러왔을 때만. 못 불러왔으면 Pro 라는 말도 꺼내지 않는다.
    var isSelling: Bool { !products.isEmpty }

    // MARK: 붙여넣기 세기

    /// 단축어를 하나 붙여넣었다(복사 · 채워 넣기 · 스택 칸). 100번째에 영수증 페이월을 한 번 띄운다.
    func recordPaste() {
        if defaults.object(forKey: Key.firstPasteAt) == nil { defaults.set(Date(), forKey: Key.firstPasteAt) }
        guard pastes < Int.max else { return }
        pastes += 1
        defaults.set(pastes, forKey: Key.pastes)
        if pastes >= Self.freeUsePastes, owned == .free, isSelling, !defaults.bool(forKey: Key.receiptShown) {
            defaults.set(true, forKey: Key.receiptShown)
            // 복사 피드백이 끝난 뒤에 — 붙여넣으려던 사람의 손을 막지 않는다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { MacPaywall.present(.receipt) }
        }
    }

    /// 첫 붙여넣기부터 오늘까지 며칠(오늘 포함).
    var daysSinceFirstPaste: Int {
        guard let first = defaults.object(forKey: Key.firstPasteAt) as? Date else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }

    // MARK: StoreKit

    /// 앱이 뜰 때 한 번. 결제 변경을 듣고, 상품과 권한을 읽는다.
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    if case .verified(let tx) = result { await tx.finish() }
                    await self?.refresh()
                }
            }
        }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: Self.allProductIDs), !loaded.isEmpty else { return }
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        if !hasSeenStore {
            hasSeenStore = true
            defaults.set(true, forKey: Key.seenStore)
        }
    }

    func product(_ tier: MacTier, _ term: MacTerm) -> Product? { products[Self.productID(tier, term)] }
    var graduateProduct: Product? { products[ID.proGraduate] }
    var upgradeProduct: Product? { products[ID.proUpgrade] }

    /// 산 것을 다시 읽는다.
    func refresh() async {
        var best = MacTier.free
        var plusLifetime = false
        var proLifetime = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result, tx.revocationDate == nil,
                  let tier = Self.tier(of: tx.productID) else { continue }
            best = max(best, tier)
            if tx.productType == .nonConsumable {
                if tier == .pro { proLifetime = true } else { plusLifetime = true }
            }
        }
        await checkPaidDownload()
        if isPaidDownloadOwner {
            best = .pro
            proLifetime = true
        }
        owned = best
        ownsPlusLifetime = plusLifetime
        ownsLifetimePro = proLifetime
        defaults.set(best.rawValue, forKey: Key.owned)
        subscription = await LeeoGraduation.currentSubscription(among: Self.subscriptionIDs)
    }

    /// 유료 다운로드 시절에 산 사람인가. App Store 가 서명한 첫 구매 판으로만 판단한다.
    /// 시험 환경(Xcode · 샌드박스 · TestFlight)은 첫 판이 늘 "1.0" 이라 보지 않는다 — 심사도 페이월을 본다.
    private func checkPaidDownload() async {
        guard !isPaidDownloadOwner,
              let result = try? await AppTransaction.shared,
              case .verified(let app) = result,
              app.environment == .production,
              Self.boughtBeforeFree(originalAppVersion: app.originalAppVersion) else { return }
        isPaidDownloadOwner = true
        defaults.set(true, forKey: Key.paidDownload)
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// 구독 졸업을 보일 때인가(6개월째 · 갱신 7일 전에 한 번씩). 보였다고 표시한다.
    func takeGraduationOfferIfDue() -> Bool {
        guard let subscription, !ownsLifetimePro, graduateProduct != nil,
              LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered()) else { return false }
        LeeoGraduation.markOffered()
        return true
    }
}

// MARK: - 동기화 입구

extension MemoSyncEngine {
    /// 맥의 동기화 입구 — Pro 일 때만 엔진을 세운다.
    /// (공유 파일 `MemoSyncEngine` 은 아이폰 원본과 같아야 해서 맥의 권한은 여기서 본다.)
    @MainActor func startIfAllowed() {
        guard MacPlan.shared.allows(.sync) else { return }
        startIfEnabled()
    }
}
