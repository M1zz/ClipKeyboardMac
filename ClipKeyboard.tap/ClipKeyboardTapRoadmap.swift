//
//  ClipKeyboardTapRoadmap.swift
//  ClipKeyboard.tap
//
//  **앞으로 만들 것**의 원본. 환경설정 ▸ 일반 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("5.1.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다). 같은 피처는 다른 앱과 같은 id 를 쓴다.
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 번역은 `Localizable.xcstrings` 에 모든 언어를 채운다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//     규칙: 아이폰 앱 레포의 docs/engineering/ROADMAP.md
//

import SwiftUI
import LeeoKit

extension ClipKeyboardTapSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "a11y.voiceover", status: .planned,
              title: NSLocalizedString("VoiceOver로 더 편하게", comment: "Roadmap item: better VoiceOver support"),
              detail: NSLocalizedString("VoiceOver가 단추와 단축어를 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: better VoiceOver support")),
        .init(id: "a11y.largetext", status: .planned,
              title: NSLocalizedString("글자 크게 보기", comment: "Roadmap item: larger text"),
              detail: NSLocalizedString("앱 안의 글자를 더 크게 키워 볼 수 있어요.", comment: "Roadmap item detail: larger text")),
        .init(id: "a11y.contrast", status: .planned,
              title: NSLocalizedString("보기 편한 색과 대비", comment: "Roadmap item: contrast and color"),
              detail: NSLocalizedString("대비를 높이거나 색을 구별하기 어려워도 내용을 알아볼 수 있어요.", comment: "Roadmap item detail: contrast and color")),
        .init(id: "a11y.motion", status: .planned,
              title: NSLocalizedString("움직임 줄이기", comment: "Roadmap item: reduce motion"),
              detail: NSLocalizedString("움직임 줄이기를 켜면 화면 효과가 차분해져요.", comment: "Roadmap item detail: reduce motion")),
        .init(id: "tips", status: .planned,
              title: NSLocalizedString("쓰는 요령 알려 주기", comment: "Roadmap item: tips"),
              detail: NSLocalizedString("알아 두면 편한 기능을 알맞은 때에 살짝 알려 줘요.", comment: "Roadmap item detail: tips")),
        .init(id: "widgets", status: .planned,
              title: NSLocalizedString("데스크톱 위젯", comment: "Roadmap item: desktop widgets"),
              detail: NSLocalizedString("앱을 열지 않고 데스크톱에서 단축어를 바로 꺼내 써요.", comment: "Roadmap item detail: desktop widgets")),
        .init(id: "shortcuts", status: .planned,
              title: NSLocalizedString("Siri로 바로 꺼내 쓰기", comment: "Roadmap item: Siri and the Shortcuts app"),
              detail: NSLocalizedString("Siri에게 말하거나 단축어 앱에서 저장한 글을 바로 불러와요.", comment: "Roadmap item detail: Siri and the Shortcuts app")),
        .init(id: "data.delete", status: .planned,
              title: NSLocalizedString("단축어 한 번에 지우기", comment: "Roadmap item: delete all data"),
              detail: NSLocalizedString("원하면 이 맥에 저장한 단축어를 모두 지울 수 있어요.", comment: "Roadmap item detail: delete all data")),
        .init(id: "autosave", status: .planned,
              title: NSLocalizedString("쓰던 단축어 이어 쓰기", comment: "Roadmap item: keep unsaved drafts"),
              detail: NSLocalizedString("새 단축어를 쓰다가 창을 닫아도 쓰던 내용이 남아 있어요.", comment: "Roadmap item detail: keep unsaved drafts")),
    ]}
}

// MARK: - 화면

/// 환경설정 ▸ 앞으로 만들 기능. 맥 환경설정 창에는 내비게이션이 없어 시트로 연다.
/// "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 화면으로 넘어간다.
struct RoadmapScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            LeeoRoadmapView<ClipKeyboardTapSpec>(onSuggest: { showFeedback = true })
                .navigationDestination(isPresented: $showFeedback) {
                    LeeoFeedbackView<ClipKeyboardTapSpec>(initialType: .feature)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("닫기", comment: "Roadmap: close sheet button")) { dismiss() }
                    }
                }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 520, idealHeight: 620)
    }
}
