//
//  OnboardingView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI
import AppKit

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        // 배경은 시스템 창 색 그대로 — 그라디언트 없이 담백하게.
        // ScrollView로 감싸 어떤 창 크기에도 콘텐츠가 잘리지 않도록 보장.
        ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: MacSpacing.xl) {
                    // App Icon
                    Image(systemName: AppSymbol.docOnClipboardFill)
                        .font(.system(size: MacIcon.hero))
                        .foregroundStyle(.tint)
                        .padding(.top, MacSpacing.xl)

                    // Welcome Text — fixedSize로 길이에 관계없이 세로 확장
                    VStack(spacing: MacSpacing.sm) {
                        Text(NSLocalizedString("ClipKeyboard에 오신 것을 환영합니다", comment: "Welcome title"))
                            .font(MacFont.screenTitle)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(NSLocalizedString("macOS에서 가장 빠르고 편리한\n단축어 및 클립보드 관리 앱", comment: "Welcome subtitle"))
                            .font(MacFont.secondary)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, MacSpacing.xl)

                    // Features
                    VStack(spacing: MacSpacing.lg) {
                        MacFeatureRow(
                            icon: "square.and.pencil",
                            title: NSLocalizedString("단축어", comment: "Snippet feature"),
                            description: NSLocalizedString("자주 사용하는 텍스트를 저장하고 빠르게 붙여넣기", comment: "Quick memo description")
                        )

                        MacFeatureRow(
                            icon: "clock.arrow.circlepath",
                            title: NSLocalizedString("클립보드 히스토리", comment: "Clipboard history feature"),
                            description: NSLocalizedString("복사한 내용을 자동으로 저장하고 관리", comment: "Clipboard history description")
                        )

                        MacFeatureRow(
                            icon: "keyboard",
                            title: NSLocalizedString("전역 단축키", comment: "Global shortcuts feature"),
                            description: NSLocalizedString("⌃⇧V로 어디서나 빠르게 접근", comment: "Global shortcuts description")
                        )

                        MacFeatureRow(
                            icon: "icloud.fill",
                            title: NSLocalizedString("iCloud 동기화", comment: "iCloud sync feature"),
                            description: NSLocalizedString("모든 기기에서 데이터 동기화", comment: "iCloud sync description")
                        )
                    }
                    .padding(.horizontal, MacSpacing.xl)

                    // Get Started Button
                    Button {
                        completeOnboarding()
                    } label: {
                        Text(NSLocalizedString("시작하기", comment: "Get started button"))
                            .font(MacFont.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MacSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.horizontal, MacSpacing.xl)
                    .padding(.bottom, MacSpacing.xl)
                }
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 520, minHeight: 600)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
        onComplete()
    }
}

// MARK: - Mac Feature Row
struct MacFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: MacSpacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            // Text
            VStack(alignment: .leading, spacing: MacSpacing.xs / 2) {
                Text(title)
                    .font(MacFont.rowTitle)

                Text(description)
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
