//
//  MacSpotlightIndexer.swift
//  ClipKeyboard.tap
//
//  Spotlight 에서 나라별 앱 이름 어느 것으로 검색해도 클립키보드가 나오게 한다.
//
//  ⚠️ Spotlight 는 앱 번들을 **시스템 언어의 이름 하나 + 파일 이름**으로만 색인한다.
//     한국어 맥에서 "剪贴键盘" 을 치면 앱이 안 나온다 (Apple 계산기도 "计算器" 로는 안 나온다).
//     번들에 키워드를 붙일 공식 방법이 없고, 번들에 xattr 을 붙이면 스토어 설치 때 사라진다.
//     그래서 앱이 직접 Core Spotlight 항목 하나를 모든 언어 이름을 키워드로 달아 올린다.
//     누르면 `AppDelegate.application(_:continue:restorationHandler:)` 가 단축어 목록을 연다.
//

import AppKit
import CoreSpotlight
import UniformTypeIdentifiers

enum MacSpotlightIndexer {
    static let itemID = "app.launcher"

    /// 실행할 때마다 다시 올린다 - 같은 id 라 덮어쓰기이고, 언어가 늘면 저절로 따라간다.
    static func indexAppNames() {
        let names = appNames()
        let attributes = CSSearchableItemAttributeSet(contentType: .application)
        attributes.title = localizedAppName()
        attributes.displayName = attributes.title
        attributes.keywords = names
        attributes.alternateNames = names
        attributes.thumbnailData = NSApp.applicationIconImage?.tiffRepresentation

        let item = CSSearchableItem(uniqueIdentifier: itemID,
                                    domainIdentifier: "app",
                                    attributeSet: attributes)
        item.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("⚠️ [Spotlight] 앱 이름 색인 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 번들에 들어 있는 모든 언어의 `CFBundleDisplayName` + 영문 이름.
    /// `InfoPlist.strings` 에 언어를 더하면 여기도 따라 늘어난다.
    static func appNames(bundle: Bundle = .main) -> [String] {
        var names: [String] = ["ClipKeyboard"]
        for localization in bundle.localizations {
            guard let path = bundle.path(forResource: "InfoPlist", ofType: "strings",
                                         inDirectory: nil, forLocalization: localization),
                  let table = NSDictionary(contentsOfFile: path),
                  let name = table["CFBundleDisplayName"] as? String
            else { continue }
            names.append(name)
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    private static func localizedAppName() -> String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? "ClipKeyboard"
    }
}
