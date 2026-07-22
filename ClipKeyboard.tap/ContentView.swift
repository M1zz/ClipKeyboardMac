//
//  ContentView.swift
//  ClipKeyboard.tap
//
//  Created by hyunho lee on 11/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showNewMemoSheet = false
    @State private var showClipboardHistorySheet = false
    @State private var showSettingsSheet = false
    @State private var showCloudBackupSheet = false
    @State private var observerTokens: [NSObjectProtocol] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: AppSymbol.docOnClipboard)
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text(NSLocalizedString("클립키보드", comment: "App name"))
                    .font(.largeTitle)
                    .bold()

                Text(NSLocalizedString("macOS 전용 단축어 앱", comment: "App tagline"))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: AppSymbol.keyboard)
                        Text(NSLocalizedString("전역 단축키: ⌃⌥K", comment: "Global hotkey description"))
                        Spacer()
                        Text(NSLocalizedString("단축어 목록 표시", comment: "Show memo list label"))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: AppSymbol.menubarRectangle)
                        Text(NSLocalizedString("메뉴바 아이콘: 🛶", comment: "Menu bar icon description"))
                        Spacer()
                        Text(NSLocalizedString("언제든지 접근 가능", comment: "Always accessible label"))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: AppSymbol.command)
                        Text(NSLocalizedString("앱 메뉴: 클립키보드", comment: "App menu description"))
                        Spacer()
                        Text(NSLocalizedString("모든 기능 사용", comment: "All features label"))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(MacRadius.sm)

                Spacer()

                Text(NSLocalizedString("창을 닫아도 앱은 백그라운드에서 계속 실행됩니다", comment: "Background run hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 500, minHeight: 400)
            .navigationTitle(NSLocalizedString("클립키보드", comment: "App name"))
        }
        .sheet(isPresented: $showNewMemoSheet) {
            Text(NSLocalizedString("새 단축어 화면", comment: "New memo screen placeholder"))
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showClipboardHistorySheet) {
            ClipboardHistoryView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            Text(NSLocalizedString("설정 화면", comment: "Settings screen placeholder"))
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showCloudBackupSheet) {
            CloudBackupView()
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
            observerTokens.removeAll()
        }
    }

    private func setupNotifications() {
        guard observerTokens.isEmpty else { return }
        print("🎯 [ContentView] 알림 리스너 등록")

        let t1 = NotificationCenter.default.addObserver(
            forName: .showMemoList,
            object: nil,
            queue: .main
        ) { _ in
            print("📋 [ContentView] 메모 목록 윈도우 열기 요청")
            NotificationCenter.default.post(name: .openMemoListWindow, object: nil)
        }

        let t2 = NotificationCenter.default.addObserver(
            forName: .showNewMemo,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("📝 [ContentView] 새 메모 표시")
            showNewMemoSheet = true
        }

        let t3 = NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("📋 [ContentView] 클립보드 히스토리 표시")
            showClipboardHistorySheet = true
        }

        let t4 = NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⚙️ [ContentView] 설정 표시")
            showSettingsSheet = true
        }

        let t5 = NotificationCenter.default.addObserver(
            forName: .showCloudBackup,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("☁️ [ContentView] 클라우드 백업 표시")
            showCloudBackupSheet = true
        }

        observerTokens = [t1, t2, t3, t4, t5]
    }
}

#Preview {
    ContentView()
}
