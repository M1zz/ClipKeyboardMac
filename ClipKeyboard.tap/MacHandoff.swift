//
//  MacHandoff.swift
//  ClipKeyboard.tap
//
//  **옛 맥 앱(`com.ysoup.TokenMemo-tap`)에서 클립키보드 맥 앱(`com.Ysoup.TokenMemo`)으로 건너가기.**
//
//  두 앱은 App Store 레코드가 다르다. 단축어 · 복사 기록 · iCloud 는 같은 App Group 과 같은 컨테이너라
//  저절로 이어지지만, 앱마다 따로 두는 설정(표준 UserDefaults)과 "이 사람은 앱을 샀다" 는 사실은
//  이어지지 않는다. 그래서 옛 앱이 켤 때마다 그 둘을 App Group 에 적어 두고(`write`),
//  새 앱이 처음 켤 때 한 번 읽어 간다(`adopt`).
//
//  ⚠️ 이 파일은 두 갈래에 **똑같이** 있다: `sunset/old-mac`(옛 앱, 쓰는 쪽) · `unify/clip-record`(새 앱, 읽는 쪽).
//     한쪽을 고치면 다른 쪽도 같이 고친다. 키와 모양이 어긋나면 이어받기가 조용히 끊긴다.
//  ⚠️ 산 사람 표시는 옛 앱이 App Store 서명(`AppTransaction`, 프로덕션)으로 확인한 것만 적는다.
//

import AppKit
import Foundation

enum MacHandoff {

    static let oldBundleID = "com.ysoup.TokenMemo-tap"
    static let newBundleID = "com.Ysoup.TokenMemo"

    /// App Group 에 두는 꾸러미의 키.
    static let key = "macHandoff.fromTap.v1"
    /// 새 앱이 이미 읽어 갔다는 표시(새 앱의 표준 UserDefaults).
    static let adoptedKey = "macHandoff.adopted.v1"
    /// 옛 앱을 산 사람이라 Pro 평생으로 대한다(새 앱의 표준 UserDefaults).
    static let legacyProKey = "plan.legacyTapPurchase"

    /// 그대로 옮기는 설정(두 앱 모두 표준 UserDefaults 에 같은 키로 둔다).
    static let settingKeys = [
        "macLaunchAtLogin",
        "macClipboardMonitoring",
        "macMenuBarIconStyle",
        "macTopEdgeTrigger",
        DefaultsKey.autoBackupEnabled,
        DefaultsKey.hasCompletedOnboarding,
    ]

    private enum Field {
        static let paid = "paid"
        static let settings = "settings"
        static let writtenAt = "writtenAt"
    }

    // MARK: - 옛 앱: 적어 두기

    /// 지금 설정과 산 사람 여부를 적는다. 켤 때마다 덮어써서 마지막 상태가 넘어가게 한다.
    static func write(paid: Bool, from defaults: UserDefaults = .standard) {
        var settings: [String: Any] = [:]
        for key in settingKeys {
            if let value = defaults.object(forKey: key) { settings[key] = value }
        }
        AppGroup.defaults?.set([
            Field.paid: paid,
            Field.settings: settings,
            Field.writtenAt: Date(),
        ], forKey: key)
    }

    // MARK: - 새 앱: 읽어 가기

    /// 읽어 간 결과.
    struct Adopted: Equatable {
        var paid: Bool
        var settingCount: Int
    }

    /// 처음 한 번만 읽는다. 새 앱에서 이미 고른 설정은 덮지 않는다.
    /// 산 사람 표시는 읽은 뒤에도 꾸러미가 다시 적히면(옛 앱을 나중에 산 것으로 확인) 따라간다.
    @discardableResult
    static func adopt(into defaults: UserDefaults = .standard,
                      from shared: UserDefaults? = AppGroup.defaults) -> Adopted? {
        guard let package = shared?.dictionary(forKey: key) else { return nil }
        let paid = package[Field.paid] as? Bool ?? false
        if paid { defaults.set(true, forKey: legacyProKey) }
        guard !defaults.bool(forKey: adoptedKey) else { return nil }

        var count = 0
        for (settingKey, value) in package[Field.settings] as? [String: Any] ?? [:]
        where settingKeys.contains(settingKey) && defaults.object(forKey: settingKey) == nil {
            defaults.set(value, forKey: settingKey)
            count += 1
        }
        defaults.set(true, forKey: adoptedKey)
        print("✅ [MacHandoff.adopt] 옛 맥 앱에서 설정 \(count)개 이어받음, 산 사람: \(paid)")
        return Adopted(paid: paid, settingCount: count)
    }

    static var isLegacyPurchaser: Bool { UserDefaults.standard.bool(forKey: legacyProKey) }

    // MARK: - 두 앱이 함께 뜨지 않게

    static var isNewAppRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: newBundleID).isEmpty
    }

    static var newAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: newBundleID)
    }
}
