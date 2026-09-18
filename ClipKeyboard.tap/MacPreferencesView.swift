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
    /// 아이폰과의 실시간 동기화. 값은 App Group 에 있고 켜면 iCloud 로 다른 기기에도 전파된다.
    @State private var syncEnabled: Bool = MemoSyncFlags.enabled
    /// 마지막으로 받아온 시각 - 켜 놓고도 안 오는지 사람이 눈으로 볼 수 있어야 한다.
    @State private var syncStatus: String = ""
    /// iCloud 안을 직접 읽어 본 결과 - 안 맞을 때 어느 쪽이 안 올리는지 가리는 자리.
    @State private var diagnostics: String = ""
    @State private var isDiagnosing = false
    @State private var isResetting = false

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

            // ⚠️ 이 스위치가 없어서 맥은 아이폰 변경을 영영 못 받았다. 엔진은 이 값이 켜져
            //    있을 때만 돌고(`MemoSyncFlags.enabled`), 값은 기기마다 따로다. 갓 설치한
            //    기기는 다른 기기 설정을 이어받지도 않으므로(`adoptCloudPreferenceIfNeeded`),
            //    켤 자리가 없으면 잠든 채로 남는다.
            Section {
                Toggle(NSLocalizedString("아이폰과 실시간으로 동기화", comment: "Prefs: realtime sync toggle"),
                       isOn: Binding(get: { syncEnabled }, set: { setSyncEnabled($0) }))
                if !syncStatus.isEmpty {
                    Text(syncStatus)
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)
                }
                Button(NSLocalizedString("지금 동기화", comment: "Prefs: sync now button")) {
                    MemoSyncEngine.shared.startIfEnabled()
                    MemoSyncEngine.shared.syncNow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refreshSyncStatus() }
                }
                .disabled(!syncEnabled)

                // 동기화가 겉으로는 도는데 데이터가 안 맞을 때, iCloud 안을 직접 읽어 센다.
                Button(isDiagnosing
                       ? NSLocalizedString("살펴보는 중…", comment: "Prefs: diagnostics running")
                       : NSLocalizedString("iCloud 안 살펴보기", comment: "Prefs: inspect iCloud button")) {
                    isDiagnosing = true
                    Task {
                        let result = await MacSyncDiagnostics.inspect()
                        diagnostics = result
                        isDiagnosing = false
                    }
                }
                .disabled(isDiagnosing)

                // 아이폰에서 지웠는데 맥에 되살아난 것들을 정리한다(위 살펴보기에 개수가 나온다).
                Button(NSLocalizedString("아이폰에서 지운 것 반영하기", comment: "Prefs: apply cloud deletions")) {
                    applyCloudDeletions()
                }
                .disabled(!syncEnabled || isResetting)

                // 되돌릴 수 없는 일이라 아래쪽에, 빨갛게, 두 번 묻고 실행한다.
                Button(NSLocalizedString("이 맥 것을 지우고 아이폰에서 다시 받기", comment: "Prefs: wipe and pull button")) {
                    confirmWipeAndPull()
                }
                .tint(.red)
                .disabled(!syncEnabled || isResetting)

                if !diagnostics.isEmpty {
                    Text(diagnostics)
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(NSLocalizedString("Sync", comment: "Prefs section: sync"))
                    .font(MacFont.sectionTitle)
            } footer: {
                Text(NSLocalizedString("켜면 아이폰에서 더하거나 지운 단축어가 이 맥에도 바로 반영됩니다. 끄면 이 맥의 단축어는 이 맥에만 남습니다.", comment: "Prefs: realtime sync note"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
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
        .onAppear {
            syncEnabled = MemoSyncFlags.enabled
            refreshSyncStatus()
        }
    }

    /// 지우기 전에 **무엇을 받아오게 되는지 세어 보여 주고** 확인받는다.
    /// 아무것도 못 받아오는 상태에서 지우면 그냥 데이터가 사라지는 것이라, 그때는 막는다.
    private func confirmWipeAndPull() {
        isResetting = true
        Task {
            do {
                let plan = try await MacSyncReset.plan()
                isResetting = false
                guard plan.cloudCount > 0 else {
                    showAlert(title: NSLocalizedString("받아올 것이 없습니다", comment: "Reset: nothing to pull title"),
                              message: MacSyncReset.Failure.cloudEmpty.localizedDescription ?? "")
                    return
                }

                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = NSLocalizedString("이 맥의 단축어를 지우고 다시 받을까요?", comment: "Reset: confirm title")
                alert.informativeText = String(
                    format: NSLocalizedString("이 맥의 단축어 %1$d개가 사라지고, iCloud 에 있는 %2$d개를 처음부터 받아옵니다. 지우기 전에 지금 데이터를 파일로 한 벌 남깁니다. iCloud 와 아이폰은 건드리지 않습니다.", comment: "Reset: confirm body"),
                    plan.localCount, plan.cloudCount)
                alert.addButton(withTitle: NSLocalizedString("지우고 다시 받기", comment: "Reset: confirm button"))
                alert.addButton(withTitle: NSLocalizedString("취소", comment: "Cancel button"))
                guard alert.runModal() == .alertFirstButtonReturn else { return }

                isResetting = true
                let result = try await MacSyncReset.wipeAndPull()
                isResetting = false

                let done = NSAlert()
                done.messageText = NSLocalizedString("앱을 다시 켭니다.", comment: "Reset: done title v2")
                var body = String(format: NSLocalizedString("다시 켜지는 순간 이 맥을 비우고, iCloud 에서 %d개를 처음부터 받아옵니다.", comment: "Reset: done body v2"),
                                  result.cloudCount)
                if let safety = result.safetyCopy {
                    body += "\n\n" + String(format: NSLocalizedString("지우기 전 사본: %@", comment: "Reset: safety copy path"),
                                             safety.path)
                }
                done.informativeText = body
                done.addButton(withTitle: NSLocalizedString("다시 켜기", comment: "Reset: relaunch button"))
                done.runModal()
                MacSyncReset.relaunch()
            } catch {
                isResetting = false
                showAlert(title: NSLocalizedString("다시 받기 실패", comment: "Reset: failed title"),
                          message: error.localizedDescription)
            }
        }
    }

    /// iCloud 가 지웠다고 하는 것을 이 맥에서도 지운다. 개수를 먼저 보여 주고 확인받는다.
    private func applyCloudDeletions() {
        isResetting = true
        Task {
            do {
                let removed = try await MacSyncReset.applyCloudDeletions()
                isResetting = false
                if removed > 0 {
                    diagnostics = ""
                    showAlert(title: NSLocalizedString("정리했습니다", comment: "Deletions: done title"),
                              message: String(format: NSLocalizedString("아이폰에서 지운 단축어 %d개를 이 맥에서도 지웠습니다.", comment: "Deletions: done body"), removed))
                } else {
                    showAlert(title: NSLocalizedString("지울 것이 없습니다", comment: "Deletions: none title"),
                              message: NSLocalizedString("아이폰에서 지운 것 중 이 맥에 남아 있는 단축어가 없습니다.", comment: "Deletions: none body"))
                }
            } catch {
                isResetting = false
                showAlert(title: NSLocalizedString("정리 실패", comment: "Deletions: failed title"),
                          message: error.localizedDescription)
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("확인", comment: "OK button"))
        alert.runModal()
    }

    private func setSyncEnabled(_ on: Bool) {
        syncEnabled = on
        MemoSyncFlags.setEnabled(on)
        if on {
            MemoSyncEngine.shared.startIfEnabled()
            MemoSyncEngine.shared.syncNow()
        }
        refreshSyncStatus()
    }

    /// 마지막으로 받아온·올린 시각을 한 줄로. 아무 기록이 없으면 아직 한 번도 못 돈 것이다.
    private func refreshSyncStatus() {
        guard MemoSyncFlags.enabled else { syncStatus = ""; return }
        if let error = MemoSyncStatus.lastError, !error.isEmpty {
            syncStatus = String(format: NSLocalizedString("동기화 오류: %@", comment: "Prefs: sync error"), error)
            return
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        if let pulled = MemoSyncStatus.lastPullAt ?? MemoSyncStatus.lastCheckAt {
            syncStatus = String(format: NSLocalizedString("마지막 확인: %@", comment: "Prefs: last sync time"),
                                formatter.string(from: pulled))
        } else {
            syncStatus = NSLocalizedString("아직 받아온 기록이 없습니다.", comment: "Prefs: never synced")
        }
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
