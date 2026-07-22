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
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // ScrollView로 감싸 어떤 창 크기에도 콘텐츠가 잘리지 않도록 보장.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    // App Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: AppSymbol.docOnClipboardFill)
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                    .padding(.top, 32)

                    // Welcome Text — fixedSize로 길이에 관계없이 세로 확장
                    VStack(spacing: 10) {
                        Text(NSLocalizedString("ClipKeyboard에 오신 것을 환영합니다", comment: "Welcome title"))
                            .font(.system(.title).weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(NSLocalizedString("macOS에서 가장 빠르고 편리한\n단축어 및 클립보드 관리 앱", comment: "Welcome subtitle"))
                            .font(.system(.body))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 40)

                    // Features
                    VStack(spacing: 14) {
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
                            description: NSLocalizedString("⌃⌥K로 어디서나 빠르게 접근", comment: "Global shortcuts description")
                        )

                        MacFeatureRow(
                            icon: "icloud.fill",
                            title: NSLocalizedString("iCloud 동기화", comment: "iCloud sync feature"),
                            description: NSLocalizedString("모든 기기에서 데이터 동기화", comment: "iCloud sync description")
                        )
                    }
                    .padding(.horizontal, 40)

                    // Get Started Button
                    Button(action: {
                        completeOnboarding()
                    }) {
                        HStack(spacing: 10) {
                            Text(NSLocalizedString("시작하기", comment: "Get started button"))
                                .font(.system(.body).weight(.semibold))
                            Image(systemName: AppSymbol.arrowRight)
                                .font(.system(.callout).weight(.semibold))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .cornerRadius(MacRadius.md)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 520, minHeight: 620)
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
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: MacRadius.sm)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(.title3))
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.callout).weight(.semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(.footnote))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
