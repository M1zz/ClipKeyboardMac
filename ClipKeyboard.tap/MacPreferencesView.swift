//
//  MacPreferencesView.swift
//  ClipKeyboard.tap
//
//  Mac-native preferences window for the menu bar companion app.
//

import ServiceManagement
import SwiftUI
import LeeoKit

struct MacPreferencesView: View {
    @AppStorage("macLaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("macClipboardMonitoring") private var clipboardMonitoring: Bool = true
    @AppStorage("macMenuBarIconStyle") private var iconStyle: String = "symbol"
    /// 카테고리 탭을 아이폰 구성으로 따를지 — 배너로 물어본 뒤에도 여기서 언제든 바꿀 수 있다.
    @ObservedObject private var tabPreference = MacCategoryTabPreference.shared
    @State private var orderedMemos: [Memo] = []

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(NSLocalizedString("General", comment: "Prefs: general"), systemImage: AppSymbol.gear) }

            reorderTab
                .tabItem { Label(NSLocalizedString("Order", comment: "Prefs: reorder"), systemImage: "arrow.up.arrow.down") }

            shortcutsTab
                .tabItem { Label(NSLocalizedString("Shortcuts", comment: "Prefs: shortcuts"), systemImage: AppSymbol.command) }

            aboutTab
                .tabItem { Label(NSLocalizedString("About", comment: "Prefs: about"), systemImage: AppSymbol.infoCircle) }
        }
        .frame(minWidth: 580, minHeight: 460)
        .padding(MacSpacing.lg)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section {
                Toggle(NSLocalizedString("Launch at login", comment: "Prefs: launch at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
                Toggle(NSLocalizedString("Monitor clipboard in background", comment: "Prefs: clipboard monitoring"), isOn: $clipboardMonitoring)
            } header: {
                Text(NSLocalizedString("Startup", comment: "Prefs section: startup"))
                    .font(MacFont.sectionTitle)
            }

            Section {
                Toggle(NSLocalizedString("아이폰에서 설정한 카테고리 따르기", comment: "Prefs: follow phone category tabs"),
                       isOn: Binding(get: { tabPreference.followsPhone },
                                     set: { tabPreference.setFollowsPhone($0) }))
            } header: {
                Text(NSLocalizedString("Categories", comment: "Prefs section: categories"))
                    .font(MacFont.sectionTitle)
            } footer: {
                Text(NSLocalizedString("켜면 기본·즐겨찾기 같은 탭까지 아이폰과 똑같이 보입니다. 끄면 단축어가 들어 있는 카테고리만 '전체' 탭과 함께 보입니다.", comment: "Prefs: category parity note"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }

            Section {
                LeeoSupportSection<ClipKeyboardTapSpec>()
            } header: {
                Text(NSLocalizedString("Feedback & Review", comment: "Prefs section: feedback"))
                    .font(MacFont.sectionTitle)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Order (단축어 순서)

    /// 단축어 순서 변경 탭 — 위/아래 버튼(드래그 실패해도 확실히 동작) + 드래그 둘 다 지원.
    /// 지정한 순서는 MacMemoOrder 를 통해 App Group 에 저장돼 아이폰·키보드까지 동기화된다.
    private var reorderTab: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("Snippet order", comment: "Prefs: snippet order header"))
                .font(MacFont.sectionTitle)
            Text(NSLocalizedString("여기서 정한 순서는 아이폰·키보드까지 동기화됩니다.", comment: "Prefs: order sync hint"))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)

            if orderedMemos.isEmpty {
                Spacer()
                Text(NSLocalizedString("단축어 없음", comment: "No memos"))
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(Array(orderedMemos.enumerated()), id: \.element.id) { index, memo in
                        HStack(spacing: MacSpacing.md) {
                            Text("\(index + 1)")
                                .font(MacFont.mono)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)

                            Image(systemName: memo.contentType == .image ? "photo" :
                                    memo.isFavorite ? "star.fill" :
                                    memo.isSecure ? "lock.fill" : "doc.text")
                                .font(MacFont.body)
                                .foregroundStyle(memo.isFavorite ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                                .frame(width: MacIcon.glyph)

                            Text(memo.title)
                                .font(MacFont.body)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                move(memo, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)
                            .help(NSLocalizedString("Move up", comment: "Reorder: move up"))

                            Button {
                                move(memo, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == orderedMemos.count - 1)
                            .help(NSLocalizedString("Move down", comment: "Reorder: move down"))
                        }
                        .padding(.vertical, MacSpacing.xs / 2)
                    }
                    .onMove(perform: moveViaDrag)
                }
                .listStyle(.inset)
            }
        }
        .padding(MacSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: loadOrderedMemos)
        .onReceive(NotificationCenter.default.publisher(for: .dataRestored)) { _ in
            loadOrderedMemos()
        }
    }

    private func loadOrderedMemos() {
        let all = (try? MemoStore.shared.load(type: .memo)) ?? []
        orderedMemos = MacMemoOrder.sorted(all)
    }

    /// 위/아래 버튼 이동 — delta -1(위) / +1(아래).
    private func move(_ memo: Memo, by delta: Int) {
        guard let idx = orderedMemos.firstIndex(where: { $0.id == memo.id }) else { return }
        let target = idx + delta
        guard target >= 0, target < orderedMemos.count else { return }
        orderedMemos.swapAt(idx, target)
        persistOrder()
    }

    /// 드래그 이동.
    private func moveViaDrag(from source: IndexSet, to destination: Int) {
        orderedMemos.move(fromOffsets: source, toOffset: destination)
        persistOrder()
    }

    /// 현재 순서를 App Group 에 저장하고, 열려 있는 다른 화면(메인 창 등)도 갱신되도록 알린다.
    private func persistOrder() {
        MacMemoOrder.commit(reordered: orderedMemos, within: orderedMemos)
        NotificationCenter.default.post(name: .dataRestored, object: nil)
    }

    private var shortcutsTab: some View {
        Form {
            Section {
                shortcutRow(NSLocalizedString("Quick Paste Panel", comment: "Shortcut: quick paste"), keys: "⌃⇧V")
                shortcutRow(NSLocalizedString("Open memo list", comment: "Shortcut: memo list"), keys: "⌃⇧M")
                shortcutRow(NSLocalizedString("New memo", comment: "Shortcut: new memo"), keys: "⌃⇧N")
                shortcutRow(NSLocalizedString("Clipboard history", comment: "Shortcut: clipboard history"), keys: "⌃⇧H")
                shortcutRow(NSLocalizedString("iCloud Backup", comment: "Shortcut: iCloud backup"), keys: "⌃⇧B")
                shortcutRow(NSLocalizedString("Preferences", comment: "Shortcut: preferences"), keys: "⌘,")
            } header: {
                Text(NSLocalizedString("Global Shortcuts", comment: "Prefs section: global shortcuts"))
                    .font(MacFont.sectionTitle)
            } footer: {
                Text(NSLocalizedString("The quick paste panel (⌃⇧V) stays over your current app without stealing focus — click a memo to copy it, then press ⌘V right where your cursor was.", comment: "Quick paste explainer (3-key)"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: MacSpacing.md) {
            Spacer()

            Image(systemName: AppSymbol.docOnClipboardFill)
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tint)

            Text("ClipKeyboard")
                .font(MacFont.screenTitle)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
            Text(String(format: NSLocalizedString("Version %@", comment: "Version label format"), version))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)

            VStack(spacing: MacSpacing.sm) {
                Link(NSLocalizedString("View User Guide", comment: "About: user guide"),
                     destination: URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html")!)

                Link(NSLocalizedString("Send Feedback", comment: "About: feedback"),
                     destination: URL(string: "mailto:leeo@kakao.com")!)

                Link(NSLocalizedString("Instagram DM (@lee25_ios)", comment: "About: instagram DM"),
                     destination: URL(string: "https://instagram.com/lee25_ios")!)
            }
            .font(MacFont.body)
            .padding(.top, MacSpacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(MacSpacing.xl)
    }

    // MARK: - Helpers

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(MacFont.body)
            Spacer()
            Text(keys)
                .font(MacFont.mono)
                .padding(.horizontal, MacSpacing.sm)
                .padding(.vertical, MacSpacing.xs / 2)
                .background(MacColor.surface, in: RoundedRectangle(cornerRadius: MacRadius.xs))
        }
    }

    /// SMAppService.mainApp으로 실제 로그인 시 자동 실행 등록.
    /// - macOS 13+ 필요. sandbox 앱의 경우 앱 내부 Helper 없이 본 앱을 직접 등록.
    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                    print("✅ [Prefs] Launch at login 등록 성공 (status=\(service.status.rawValue))")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    print("🔓 [Prefs] Launch at login 해제 성공")
                }
            }
        } catch {
            print("❌ [Prefs] Launch at login 변경 실패: \(error.localizedDescription)")
            // 실패 시 UI 토글을 원래대로 되돌려 사용자 혼란 방지.
            DispatchQueue.main.async {
                self.launchAtLogin = (service.status == .enabled)
            }
        }
    }
}
