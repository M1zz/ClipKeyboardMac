//
//  MacSyncPrompt.swift
//  ClipKeyboard.tap
//
//  "아이폰과 동기화가 꺼져 있습니다" 안내 띠.
//
//  ⚠️ 동기화 엔진은 `MemoSyncFlags.enabled` 가 켜져 있을 때만 돈다. 꺼져 있으면 iCloud 에
//     변경이 있는지 **확인조차 하지 않는다.** 그런데 이 값은 기기마다 따로이고, 한 번도
//     돌린 적 없는 기기는 다른 기기의 설정을 이어받지 않는다(`adoptCloudPreferenceIfNeeded`
//     - 남의 데이터를 이 기기로 당겨오는 일은 이 기기에서 예라고 한 뒤에만 한다).
//     그래서 맥은 아이폰에서 켜 두어도 잠든 채로 남고, 사람은 그 사실을 알 길이 없었다.
//     환경설정에 스위치를 두는 것만으로는 부족해, 가장 자주 보는 화면에서 알린다.
//

import Combine
import SwiftUI

@MainActor
final class MacSyncPrompt: ObservableObject {
    static let shared = MacSyncPrompt()

    /// 띠를 보여야 하는가 - 동기화가 꺼져 있고, 사람이 "나중에" 를 누르지 않았을 때.
    @Published private(set) var needsAsk: Bool = false

    private var dismissed = false

    private init() {
        refresh()
    }

    func refresh() {
        needsAsk = !dismissed && !MemoSyncFlags.enabled
    }

    func enableSync() {
        MemoSyncFlags.setEnabled(true)
        MemoSyncEngine.shared.startIfEnabled()
        MemoSyncEngine.shared.syncNow()
        refresh()
    }

    /// 이번 실행에서만 감춘다 - 끄고 쓰기로 한 사람에게 매번 묻지 않되,
    /// 설정에서 언제든 켤 수 있다는 것은 환경설정 쪽에서 말한다.
    func dismiss() {
        dismissed = true
        needsAsk = false
    }
}

struct MacSyncPromptBanner: View {
    @ObservedObject var prompt: MacSyncPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("아이폰과 동기화가 꺼져 있습니다", comment: "Sync prompt title"))
                .font(MacFont.rowTitle)

            Text(NSLocalizedString("켜면 아이폰에서 더하거나 지운 단축어를 이 맥이 받아옵니다.", comment: "Sync prompt detail"))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: MacSpacing.sm) {
                Button(NSLocalizedString("동기화 켜기", comment: "Sync prompt: turn on")) {
                    prompt.enableSync()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString("나중에", comment: "Sync prompt: later")) {
                    prompt.dismiss()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MacSpacing.md)
        .background(Color.accentColor.opacity(0.08))
    }
}
