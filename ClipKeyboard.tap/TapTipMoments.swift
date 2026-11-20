//
//  TapTipMoments.swift
//  ClipKeyboard.tap
//
//  응원을 부탁해도 되는 순간을 가르는 규칙.
//  `MemoListView.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import SwiftUI
import AppKit
import LeeoKit

// MARK: - 응원 부탁 순간

/// 팁을 부탁할 순간 — 이 맥에서 클립키보드를 쓴 횟수(복사·채워 넣기·새 단축어, `LeeoEngagement` 가 센다). 큰 것부터.
enum TapTipMoments {
    static let uses = [1000, 300, 100]

    static func reached(uses count: Int) -> [LeeoTipMoment] {
        uses.filter { count >= $0 }.map {
            LeeoTipMoment(id: "uses.\($0)",
                          message: String(format: NSLocalizedString("이 맥에서 클립키보드를 %lld번 쓰셨어요",
                                                                    comment: "Tip ask card: how many times ClipKeyboard was used on this Mac"),
                                          count))
        }
    }

    static var reachedNow: [LeeoTipMoment] { reached(uses: LeeoEngagement.shared.significantEventCount) }
}
