//
//  MacPaywallView.swift
//  ClipKeyboard.tap
//
//  무료 · Plus · Pro 세 칸 페이월과 환경설정의 'Plus · Pro' 칸.
//  칸마다 연 구독(기본) · 평생, 펼치면 주 · 월. 아래에 비교표, 구매 복원, 약관.
//  구독 중인 사람의 '평생으로 바꾸기'는 LeeoKit 의 구독 졸업 화면을 쓴다.
//

import SwiftUI
import StoreKit
import LeeoKit

/// 페이월을 띄운 까닭. 앞에 세울 칸과 맨 위 한 줄이 달라진다.
enum MacPaywallReason: Equatable {
    case settings
    /// 100번째 붙여넣기 — "언제부터 몇 번 붙여넣었어요" 영수증
    case receipt
    /// 무료 한도를 넘겨 새로 만들려 할 때
    case limit(MacItemKind)
    case sync
    case backup
    case stacksAndSecure
    /// 설정의 '평생으로 바꾸기'(구독 중이 아닐 때)
    case lifetime
    /// 구독 졸업 제안
    case graduation

    var focus: MacTier {
        switch self {
        case .settings, .receipt, .limit: return .plus
        case .sync, .backup, .stacksAndSecure, .lifetime, .graduation: return .pro
        }
    }

    /// 아이폰과 잇는 값 · 평생으로 바꾸기는 평생을 먼저 보인다. 나머지는 연 구독.
    var startsWithLifetime: Bool { self == .sync || self == .lifetime }
}

@MainActor
enum MacPaywall {
    /// 페이월 창을 연다. 이 기기에서 상품을 한 번도 못 불러왔으면 열지 않는다(그때는 막지도 않는다).
    static func present(_ reason: MacPaywallReason) {
        guard MacPlan.shared.hasSeenStore else { return }
        WindowManager.shared.openPaywallWindow(reason)
    }
}

// MARK: - 페이월

struct MacPaywallView: View {
    let reason: MacPaywallReason
    let close: () -> Void
    @ObservedObject private var plan = MacPlan.shared
    @State private var showsGraduation = false
    @State private var restoring = false
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: MacSpacing.xl) {
                header
                if let context { contextBox(context) }
                if plan.isSelling {
                    HStack(alignment: .top, spacing: MacSpacing.md) {
                        freeCard
                        MacPlanCard(tier: .plus, reason: reason)
                        MacPlanCard(tier: .pro, reason: reason)
                    }
                } else {
                    unavailable
                }
                MacPlanCompareTable()
                footer
            }
            .padding(MacSpacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .task {
            await plan.loadProducts()
            await plan.refresh()
            loading = false
            if reason == .graduation { showsGraduation = true }
        }
        .sheet(isPresented: $showsGraduation) {
            LeeoGraduationOfferView(graduate: plan.graduateProduct) { await plan.refresh() }
                .frame(minWidth: 440, minHeight: 460)
        }
    }

    private var header: some View {
        VStack(spacing: MacSpacing.sm) {
            Text(NSLocalizedString("클립키보드 Plus · Pro", comment: "Paywall: title"))
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString("연 구독으로 가볍게, 평생으로 한 번에", comment: "Paywall: subtitle"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 맨 위 한 줄과 그 아래 설명.
    private var context: (title: String, detail: String?)? {
        switch reason {
        case .receipt:
            let since = Calendar.current.date(byAdding: .day, value: -(plan.daysSinceFirstPaste - 1), to: Date()) ?? Date()
            return (String(format: NSLocalizedString("%1$@부터 %2$lld번 붙여넣었어요", comment: "Paywall receipt: since <date> you pasted N times"),
                           since.formatted(.dateTime.month(.wide).day()), Int64(plan.pastes)),
                    NSLocalizedString("메일 서명 · 계좌번호를 다시 치지 않은 횟수예요.", comment: "Paywall receipt: what the count means"))
        case .limit(let kind):
            let format: String
            switch kind {
            case .snippet: format = NSLocalizedString("무료로는 단축어를 %lld개까지 새로 만들 수 있어요", comment: "Paywall: free snippet limit reached")
            case .template: format = NSLocalizedString("무료로는 템플릿을 %lld개까지 새로 만들 수 있어요", comment: "Paywall: free template limit reached")
            case .image: format = NSLocalizedString("무료로는 이미지 단축어를 %lld개까지 새로 만들 수 있어요", comment: "Paywall: free image snippet limit reached")
            }
            return (String(format: format, Int64(kind.freeLimit)),
                    NSLocalizedString("이미 만든 단축어는 그대로 쓰고 지울 수 있어요.", comment: "Paywall: existing items stay usable"))
        case .sync:
            return (NSLocalizedString("아이폰과 실시간 동기화는 Pro에서 써요", comment: "Paywall: sync needs Pro"), nil)
        case .backup:
            return (NSLocalizedString("iCloud 백업과 되돌리기는 Pro에서 써요", comment: "Paywall: iCloud backup needs Pro"), nil)
        case .stacksAndSecure:
            return (NSLocalizedString("아이폰에서 만든 스택 · 보안 단축어는 Pro에서 꺼내 써요", comment: "Paywall: stacks and secure snippets need Pro"), nil)
        case .settings, .lifetime, .graduation:
            return nil
        }
    }

    private func contextBox(_ context: (title: String, detail: String?)) -> some View {
        VStack(spacing: MacSpacing.xs) {
            Text(context.title)
                .font(.title3.weight(.semibold))
            if let detail = context.detail {
                Text(detail)
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(MacSpacing.lg)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: MacRadius.md))
        .accessibilityElement(children: .combine)
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("무료", comment: "Plan name: free"))
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString("단축어 100번 붙여넣기까지는 모든 기능을 그대로", comment: "Plan pitch: free"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if plan.owned == .free { MacCurrentPlanBadge() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(MacSpacing.lg)
        .macSurface(MacRadius.md)
    }

    private var unavailable: some View {
        VStack(spacing: MacSpacing.sm) {
            if loading {
                ProgressView()
            } else {
                Text(NSLocalizedString("요금제를 불러오지 못했어요", comment: "Paywall: products failed to load"))
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
                Button(NSLocalizedString("다시 시도", comment: "Paywall: retry loading products")) {
                    Task { loading = true; await plan.loadProducts(); loading = false }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var footer: some View {
        VStack(spacing: MacSpacing.md) {
            HStack(spacing: MacSpacing.lg) {
                Button {
                    Task { restoring = true; await plan.restore(); restoring = false }
                } label: {
                    if restoring { ProgressView().controlSize(.small) } else { Text(NSLocalizedString("구매 복원", comment: "Paywall: restore purchases")) }
                }
                .disabled(restoring)
                Link(NSLocalizedString("이용약관", comment: "Paywall: terms of use link"), destination: ClipKeyboardTapSpec.legal.termsURL ?? ClipKeyboardTapSpec.legal.supportURL)
                Link(NSLocalizedString("개인정보 처리방침", comment: "Paywall: privacy policy link"), destination: ClipKeyboardTapSpec.legal.privacyURL)
                Spacer()
                Button(NSLocalizedString("닫기", comment: "Close button"), action: close)
                    .keyboardShortcut(.cancelAction)
            }
            Text(NSLocalizedString("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 값으로 자동 갱신돼요. 결제는 Apple 계정으로 청구되고, App Store 계정 설정에서 언제든 관리하거나 해지할 수 있어요.", comment: "Paywall: auto-renewal disclosure"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 유료 칸 카드

private struct MacPlanCard: View {
    let tier: MacTier
    let reason: MacPaywallReason
    @ObservedObject private var plan = MacPlan.shared
    @Environment(\.purchase) private var purchase
    @State private var term: MacTerm
    @State private var showsShortTerms = false
    @State private var buying = false
    @State private var introEligible = false

    init(tier: MacTier, reason: MacPaywallReason) {
        self.tier = tier
        self.reason = reason
        _term = State(initialValue: reason.focus == tier && reason.startsWithLifetime ? .lifetime : .yearly)
    }

    private var isFocused: Bool { reason.focus == tier }
    private var name: String { tier == .pro ? "Pro" : "Plus" }

    private var pitch: String {
        tier == .pro
            ? NSLocalizedString("쌓은 것을 지키고 아이폰과 잇기", comment: "Plan pitch: Pro")
            : NSLocalizedString("마음껏 쌓기", comment: "Plan pitch: Plus")
    }

    /// 고른 기간의 상품. Plus 평생을 가진 사람의 Pro 평생은 올리기 상품.
    private func product(_ term: MacTerm) -> Product? {
        if tier == .pro, term == .lifetime, plan.ownsPlusLifetime, let upgrade = plan.upgradeProduct { return upgrade }
        return plan.product(tier, term)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(verbatim: name)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(pitch)
                .font(MacFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if plan.owned >= tier {
                Spacer(minLength: 0)
                if plan.owned == tier { MacCurrentPlanBadge() }
            } else {
                option(.yearly)
                option(.lifetime)
                if product(.weekly) != nil || product(.monthly) != nil {
                    DisclosureGroup(NSLocalizedString("주 · 월 구독 보기", comment: "Paywall: show weekly and monthly plans"),
                                    isExpanded: $showsShortTerms) {
                        option(.monthly)
                        option(.weekly)
                    }
                    .font(MacFont.body)
                }
                if let note {
                    Text(note)
                        .font(MacFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                buyButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(MacSpacing.lg)
        .macSurface(MacRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: MacRadius.md)
                .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        )
        .task(id: plan.product(tier, .yearly)?.id) {
            introEligible = await plan.product(tier, .yearly)?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    @ViewBuilder
    private func option(_ value: MacTerm) -> some View {
        if let product = product(value) {
            let selected = term == value
            Button {
                term = value
            } label: {
                HStack(spacing: MacSpacing.sm) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                        .accessibilityHidden(true)
                    Text(title(value))
                    Spacer(minLength: MacSpacing.sm)
                    Text(price(value, product))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(MacFont.body)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private func title(_ value: MacTerm) -> String {
        switch value {
        case .weekly: return NSLocalizedString("주 구독", comment: "Pricing: weekly subscription option")
        case .monthly: return NSLocalizedString("월 구독", comment: "Pricing: monthly subscription option")
        case .yearly: return LeeoLadderText.yearly
        case .lifetime: return LeeoLadderText.lifetime
        }
    }

    private func price(_ value: MacTerm, _ product: Product) -> String {
        switch value {
        case .weekly: return String(format: NSLocalizedString("%@ / 주", comment: "Pricing: weekly price. %@ = price"), product.displayPrice)
        case .monthly: return String(format: NSLocalizedString("%@ / 월", comment: "Pricing: monthly price. %@ = price"), product.displayPrice)
        case .yearly: return String(format: LeeoLadderText.perYearFormat, product.displayPrice)
        case .lifetime: return product.displayPrice
        }
    }

    /// 연 구독은 첫 해 할인, 평생은 올리기 값이나 "연 구독 N년치".
    private var note: String? {
        switch term {
        case .yearly:
            guard introEligible, let offer = plan.product(tier, .yearly)?.subscription?.introductoryOffer else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            if tier == .pro, plan.ownsPlusLifetime, let upgrade = plan.upgradeProduct {
                return String(format: NSLocalizedString("Plus 평생을 가진 분은 %@에 올려요", comment: "Paywall: upgrade price for Plus Lifetime owners. %@ = price"),
                              upgrade.displayPrice)
            }
            guard let yearly = plan.product(tier, .yearly), let lifetime = plan.product(tier, .lifetime), yearly.price > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime.price / yearly.price).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        case .weekly, .monthly:
            return nil
        }
    }

    private var buyButton: some View {
        Button {
            guard let product = product(term) else { return }
            Task {
                buying = true
                defer { buying = false }
                guard let result = try? await purchase(product),
                      case .success(let verification) = result,
                      case .verified(let tx) = verification else { return }
                await tx.finish()
                await plan.refresh()
            }
        } label: {
            Group {
                if buying { ProgressView().controlSize(.small) } else {
                    Text(String(format: NSLocalizedString("%@ 고르기", comment: "Paywall: buy button. %@ = plan name (Plus or Pro)"), name))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .modifier(MacProminence(prominent: isFocused))
        .disabled(buying || product(term) == nil)
    }
}

private struct MacProminence: ViewModifier {
    let prominent: Bool
    func body(content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent) } else { content.buttonStyle(.bordered) }
    }
}

private struct MacCurrentPlanBadge: View {
    var body: some View {
        Label(NSLocalizedString("지금 쓰는 칸", comment: "Paywall/Settings: the plan you are on"), systemImage: "checkmark.circle.fill")
            .font(MacFont.rowTitle)
            .foregroundStyle(Color.accentColor)
    }
}

// MARK: - 비교표

struct MacPlanCompareTable: View {
    private enum Cell { case yes, no, text(String) }

    private var unlimited: String { NSLocalizedString("무제한", comment: "Plan compare: unlimited") }

    private var rows: [(String, Cell, Cell, Cell)] {[
        (NSLocalizedString("빠른 붙여넣기 패널 · 메뉴바", comment: "Plan compare row"), .yes, .yes, .yes),
        (NSLocalizedString("만들 수 있는 단축어", comment: "Plan compare row: snippets you can create"), .text("10"), .text(unlimited), .text(unlimited)),
        (NSLocalizedString("만들 수 있는 템플릿", comment: "Plan compare row: templates you can create"), .text("3"), .text(unlimited), .text(unlimited)),
        (NSLocalizedString("만들 수 있는 이미지 단축어", comment: "Plan compare row: image snippets you can create"), .text("5"), .text(unlimited), .text(unlimited)),
        (NSLocalizedString("클립보드 기록 (7일)", comment: "Plan compare row: clipboard history kept 7 days"), .text("50"), .text("100"), .text("100")),
        (NSLocalizedString("카테고리 · 즐겨찾기 · 끌어서 정렬", comment: "Plan compare row"), .yes, .yes, .yes),
        (NSLocalizedString("파일 내보내기 · 가져오기", comment: "Plan compare row"), .yes, .yes, .yes),
        (NSLocalizedString("iCloud 백업 · 되돌리기", comment: "Plan compare row"), .no, .no, .yes),
        (NSLocalizedString("아이폰과 실시간 동기화", comment: "Plan compare row"), .no, .no, .yes),
        (NSLocalizedString("스택 · 보안 단축어 (Touch ID)", comment: "Plan compare row"), .no, .no, .yes),
    ]}

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: MacSpacing.lg, verticalSpacing: MacSpacing.sm) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Text(NSLocalizedString("무료", comment: "Plan name: free")).gridColumnAlignment(.center)
                Text(verbatim: "Plus").gridColumnAlignment(.center)
                Text(verbatim: "Pro").gridColumnAlignment(.center)
            }
            .font(MacFont.rowTitle)
            Divider()
            ForEach(rows.indices, id: \.self) { i in
                let row = rows[i]
                GridRow {
                    Text(row.0).fixedSize(horizontal: false, vertical: true)
                    cell(row.1)
                    cell(row.2)
                    cell(row.3)
                }
                .font(MacFont.body)
            }
        }
        .padding(MacSpacing.lg)
        .macSurface(MacRadius.md)
    }

    @ViewBuilder
    private func cell(_ value: Cell) -> some View {
        switch value {
        case .yes:
            Image(systemName: "checkmark")
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(NSLocalizedString("포함", comment: "Plan compare: included (VoiceOver)"))
        case .no:
            Text(verbatim: "–")
                .foregroundStyle(.secondary)
                .accessibilityLabel(NSLocalizedString("포함 안 됨", comment: "Plan compare: not included (VoiceOver)"))
        case .text(let text):
            Text(text).monospacedDigit()
        }
    }
}

// MARK: - 환경설정의 Plus · Pro 칸

/// 지금 쓰는 칸, 요금제 보기, 평생으로 바꾸기(늘), 구독 관리, 구매 복원.
/// 상품을 불러오지 못했고 산 것도 없으면 서지 않는다 — 팔 수 없는 것을 말하지 않는다.
struct MacPlanSettingsSection: View {
    @ObservedObject private var plan = MacPlan.shared
    @Environment(\.openURL) private var openURL
    @State private var showsGraduation = false
    @State private var restoring = false

    var body: some View {
        if plan.isSelling || plan.owned > .free {
            Section {
                LabeledContent(NSLocalizedString("지금 쓰는 칸", comment: "Paywall/Settings: the plan you are on"), value: status)
                Button(NSLocalizedString("요금제 보기", comment: "Settings: open the plans")) { MacPaywall.present(.settings) }
                if !plan.ownsLifetimePro {
                    Button(LeeoLadderText.switchToLifetimeEntry) {
                        if plan.subscription != nil, plan.graduateProduct != nil {
                            showsGraduation = true
                        } else {
                            MacPaywall.present(.lifetime)
                        }
                    }
                }
                if plan.subscription != nil {
                    Button(LeeoLadderText.manageSubscription) {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                    }
                }
                Button {
                    Task { restoring = true; await plan.restore(); restoring = false }
                } label: {
                    Text(NSLocalizedString("구매 복원", comment: "Paywall: restore purchases"))
                }
                .disabled(restoring)
            } header: {
                Text(verbatim: "Plus · Pro")
                    .font(MacFont.sectionTitle)
            }
            .sheet(isPresented: $showsGraduation) {
                LeeoGraduationOfferView(graduate: plan.graduateProduct) { await plan.refresh() }
                    .frame(minWidth: 440, minHeight: 460)
            }
        }
    }

    private var status: String {
        if plan.isPaidDownloadOwner {
            return NSLocalizedString("Pro 평생 · 앱을 사 주셔서 고마워요", comment: "Settings plan status: bought the app when it was paid")
        }
        let name = plan.owned == .pro ? "Pro" : "Plus"
        if plan.owned > .free {
            return plan.subscription != nil
                ? String(format: NSLocalizedString("%@ 구독 중", comment: "Settings plan status: subscribed. %@ = Plus or Pro"), name)
                : String(format: NSLocalizedString("%@ 평생", comment: "Settings plan status: lifetime. %@ = Plus or Pro"), name)
        }
        if plan.pastes < MacPlan.freeUsePastes {
            return String(format: NSLocalizedString("무료 · 모든 기능 체험 중 (붙여넣기 %1$lld/%2$lld)", comment: "Settings plan status: free trial of every feature until N pastes"),
                          Int64(plan.pastes), Int64(MacPlan.freeUsePastes))
        }
        return NSLocalizedString("무료", comment: "Plan name: free")
    }
}
