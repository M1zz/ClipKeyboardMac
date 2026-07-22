//
//  MacPreferencesView.swift
//  ClipKeyboard.tap
//
//  Mac-native preferences window for the menu bar companion app.
//

import ServiceManagement
import SwiftUI

struct MacPreferencesView: View {
    @AppStorage("macLaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("macClipboardMonitoring") private var clipboardMonitoring: Bool = true
    @AppStorage("macMenuBarIconStyle") private var iconStyle: String = "symbol"
    @AppStorage("macAutoPaste") private var autoPaste: Bool = false
    @State private var hasAccessibility: Bool = DirectPasteHelper.hasAccessibilityPermission()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(NSLocalizedString("General", comment: "Prefs: general"), systemImage: AppSymbol.gear) }

            shortcutsTab
                .tabItem { Label(NSLocalizedString("Shortcuts", comment: "Prefs: shortcuts"), systemImage: AppSymbol.command) }

            proTab
                .tabItem { Label(NSLocalizedString("Pro", comment: "Prefs: pro"), systemImage: AppSymbol.starFill) }

            aboutTab
                .tabItem { Label(NSLocalizedString("About", comment: "Prefs: about"), systemImage: AppSymbol.infoCircle) }
        }
        .frame(minWidth: 520, minHeight: 400)
        .padding()
        .onAppear { MacProManager.refreshFromCloud() }
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
                    .font(.headline)
            }

            Section {
                Toggle(NSLocalizedString("Paste directly after selecting", comment: "Prefs: auto paste"), isOn: $autoPaste)
                if autoPaste {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasAccessibility ? .green : .orange)
                        Text(hasAccessibility
                             ? NSLocalizedString("Accessibility permission granted", comment: "Prefs: a11y granted")
                             : NSLocalizedString("Accessibility permission required for direct paste.", comment: "Prefs: a11y needed"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Spacer()
                        if !hasAccessibility {
                            Button(NSLocalizedString("Grant Access…", comment: "Prefs: grant access")) {
                                _ = DirectPasteHelper.requestAccessibilityPermission()
                                // 사용자가 시스템 설정에서 토글 후 돌아왔을 때 refresh.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    hasAccessibility = DirectPasteHelper.hasAccessibilityPermission()
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("Paste behavior", comment: "Prefs section: paste"))
                    .font(.headline)
            } footer: {
                Text(NSLocalizedString("When on, pressing Enter in the menu bar popover copies AND pastes to the frontmost app. Otherwise, Enter only copies (use ⌥Enter to paste).", comment: "Prefs: paste behavior note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
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
                    .font(.headline)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("ClipKeyboard needs Accessibility permission to register global shortcuts. Grant access in System Settings → Privacy & Security → Accessibility.", comment: "Accessibility note"))
                    Text(NSLocalizedString("The quick paste panel (⌃⇧V) stays over your current app — click a memo and the text is pasted directly into the text field you were typing in, without losing focus.", comment: "Quick paste explainer (3-key)"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var proTab: some View {
        VStack(spacing: 20) {
            // 현재 상태
            HStack(spacing: 12) {
                Image(systemName: MacProManager.isPro ? "checkmark.seal.fill" : "star.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(MacProManager.isPro ? .yellow : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(MacProManager.isPro
                         ? NSLocalizedString("Pro 활성화됨", comment: "Pro active")
                         : NSLocalizedString("무료 플랜", comment: "Free plan"))
                        .font(.title3).fontWeight(.semibold)
                    Text(MacProManager.isPro
                         ? NSLocalizedString("모든 기능을 사용할 수 있습니다.", comment: "All features unlocked")
                         : NSLocalizedString("단축어 5개 · 클립보드 20개 제한", comment: "Free limits"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(MacProManager.isPro ? Color.yellow.opacity(0.1) : Color.secondary.opacity(0.08))
            .cornerRadius(MacRadius.sm)

            Divider()

            // 기능 비교
            VStack(alignment: .leading, spacing: 10) {
                featureRow(NSLocalizedString("단축어", comment: "Feature: snippets"),
                           free: NSLocalizedString("최대 5개", comment: "Free memo limit"),
                           pro: NSLocalizedString("무제한", comment: "Unlimited"))
                featureRow(NSLocalizedString("클립보드 히스토리", comment: "Feature: clipboard"),
                           free: NSLocalizedString("최대 20개", comment: "Free clipboard limit"),
                           pro: NSLocalizedString("최대 100개", comment: "Pro clipboard limit"))
                featureRow(NSLocalizedString("iCloud 백업", comment: "Feature: icloud"),
                           free: "—", pro: "✓")
                featureRow(NSLocalizedString("iOS 구매 시 자동 연동", comment: "Feature: ios sync"),
                           free: "—", pro: "✓")
            }

            Spacer()

            if !MacProManager.isPro {
                Text(NSLocalizedString("iOS 앱에서 Pro를 구매하면 이 Mac에서도 자동으로 활성화됩니다.", comment: "iOS purchase hint"))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(NSLocalizedString("상태 새로고침", comment: "Refresh Pro status")) {
                    MacProManager.refreshFromCloud()
                }
                .controlSize(.regular)
            }
        }
        .padding()
        .formStyle(.grouped)
    }

    private func featureRow(_ name: String, free: String, pro: String) -> some View {
        HStack {
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            Text(free).foregroundStyle(.secondary).frame(width: 90, alignment: .center)
            Text(pro).foregroundStyle(MacProManager.isPro ? .primary : .secondary).frame(width: 90, alignment: .center)
        }
        .font(.subheadline)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.docOnClipboardFill)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 12)

            Text("ClipKeyboard")
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Version %@", comment: "Version label format"))
                .font(.caption)
                .foregroundColor(.secondary)
                .overlay(alignment: .center) {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
                    Text(String(format: NSLocalizedString("Version %@", comment: "Version label format"), version))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            Divider().padding(.vertical, 8)

            VStack(spacing: 8) {
                Link(NSLocalizedString("View User Guide", comment: "About: user guide"),
                     destination: URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html")!)

                Link(NSLocalizedString("Send Feedback", comment: "About: feedback"),
                     destination: URL(string: "mailto:leeo@kakao.com")!)

                Link(NSLocalizedString("Instagram DM (@lee25_ios)", comment: "About: instagram DM"),
                     destination: URL(string: "https://instagram.com/lee25_ios")!)
            }
            .font(.subheadline)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: MacRadius.xs))
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
