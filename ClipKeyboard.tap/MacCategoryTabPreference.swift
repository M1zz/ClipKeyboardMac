//
//  MacCategoryTabPreference.swift
//  ClipKeyboard.tap
//
//  "카테고리 탭을 아이폰 구성으로 맞출지" 하나만 정하는 설정.
//
//  왜 물어보는가: 4.4.7 부터 맥의 탭 구성이 아이폰과 같아진다(기본·즐겨찾기·기본 제공
//  카테고리가 생기고 "전체" 탭이 없어진다). 신규 설치라면 그게 그냥 처음 보는 모습이지만,
//  **이미 쓰던 사람에겐 어느 날 갑자기 화면이 바뀌는 일**이다. 단축어는 그대로여도
//  "전체 탭이 사라졌다 = 단축어가 사라졌다"로 읽힌다.
//  → 기존 사용자는 **묻기 전까지 예전 구성 그대로** 두고, 승낙했을 때만 바꾼다.
//
//  묻지 않는 경우:
//   - 신규 설치(단축어가 아직 없음) → 처음부터 아이폰 구성으로 시작.
//   - 바뀌어도 보이는 탭이 똑같은 경우 → 물어볼 이유가 없다(조용히 맞춘다).
//
//  설정은 App Group 에 남긴다 — 메뉴바 팝오버·목록 창·환경설정이 같은 값을 본다.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class MacCategoryTabPreference: ObservableObject {

    static let shared = MacCategoryTabPreference()

    /// 사용자의 선택. 값이 없으면 "아직 안 정함".
    private static let storageKey = "mac.category.followPhoneTabs.v1"

    /// 아이폰 구성을 따를지. 아직 안 정했으면 **따르지 않는다**(보수적 기본값).
    @Published private(set) var followsPhone: Bool
    /// 지금 물어봐야 하는지 — 기존 사용자이고, 바꾸면 실제로 탭이 달라질 때만 true.
    @Published private(set) var needsAsk: Bool = false

    private var defaults: UserDefaults? { AppGroup.defaults }

    private init() {
        followsPhone = AppGroup.defaults?.object(forKey: Self.storageKey) as? Bool ?? false
    }

    /// 아직 안 정한 사용자인지.
    private var isUndecided: Bool {
        defaults?.object(forKey: Self.storageKey) == nil
    }

    /// 현재 데이터로 "물어봐야 하는지"를 판단한다. 목록을 새로 읽을 때마다 부르면 된다.
    ///
    /// - 신규 설치(단축어 0개) → 묻지 않고 아이폰 구성으로 시작.
    /// - 예전 구성과 새 구성의 탭이 같음 → 묻지 않고 맞춘다.
    /// - 그 외(기존 사용자 + 실제로 달라짐) → `needsAsk = true`, 승낙 전까지 예전 구성 유지.
    func evaluate(memos: [Memo], snapshot: CategorySnapshot) {
        guard isUndecided else {
            needsAsk = false
            return
        }

        if memos.isEmpty {
            apply(true)
            return
        }

        let legacy = MacCategoryTabs.legacyTabs(memos: memos, snapshot: snapshot)
        let parity = MacCategoryTabs.phoneTabs(from: snapshot)
        if legacy == parity {
            apply(true)
            return
        }

        needsAsk = true
    }

    /// "맞추기" — 아이폰 구성으로 전환한다.
    func adoptPhoneTabs() { apply(true) }

    /// "지금은 그대로" — 예전 구성을 유지한다. 환경설정에서 언제든 다시 켤 수 있다.
    func keepCurrentTabs() { apply(false) }

    /// 환경설정 토글용 — 사용자가 직접 바꾼다.
    func setFollowsPhone(_ on: Bool) { apply(on) }

    private func apply(_ on: Bool) {
        defaults?.set(on, forKey: Self.storageKey)
        followsPhone = on
        needsAsk = false
    }
}

// MARK: - 물어보는 배너

/// "아이폰 카테고리로 맞출까요?" 한 줄 배너 — 목록 창과 메뉴바 팝오버가 함께 쓴다.
/// 답하면(어느 쪽이든) 사라진다.
struct MacCategoryAdoptBanner: View {
    @ObservedObject var preference: MacCategoryTabPreference

    var body: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("아이폰에서 설정한 카테고리로 맞출까요?", comment: "Category parity prompt title"))
                .font(MacFont.rowTitle)

            Text(NSLocalizedString("기본·즐겨찾기 같은 탭이 아이폰과 같아집니다. 단축어는 그대로 있어요.", comment: "Category parity prompt detail"))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: MacSpacing.sm) {
                Button(NSLocalizedString("맞추기", comment: "Category parity: adopt")) {
                    preference.adoptPhoneTabs()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString("지금은 그대로", comment: "Category parity: keep current")) {
                    preference.keepCurrentTabs()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MacSpacing.md)
        .background(Color.accentColor.opacity(0.08))
    }
}
