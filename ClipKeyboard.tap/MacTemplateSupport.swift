//
//  MacTemplateSupport.swift
//  ClipKeyboard.tap
//
//  맥 앱은 iOS의 TemplateVariableProcessor / templateChipAttributed 를 공유하지
//  않으므로(별도 코드베이스) 같은 동작을 여기에 이식한다. 로직은 iOS 원본과
//  동일하게 유지해 메모/템플릿 처리 결과가 두 플랫폼에서 일치하도록 한다.
//

import SwiftUI

// MARK: - TemplateVariableProcessor (iOS 원본 이식)

enum TemplateVariableProcessor {

    static let userTimezoneKey = DefaultsKey.userTimezone
    static let userCurrencyKey = DefaultsKey.userCurrency

    /// 모든 자동 변수 토큰. 커스텀 플레이스홀더 추출 시 이 집합은 제외한다.
    static let autoVariableTokens: Set<String> = [
        "{날짜}", "{date}",
        "{시간}", "{time}",
        "{연도}", "{year}",
        "{월}", "{month}",
        "{일}", "{day}",
        "{timezone}", "{타임존}",
        "{timezone_offset}",
        "{currency}", "{통화}",
        "{greeting_time}", "{인사}",
        "{city}", "{도시}"
    ]

    /// 자동 변수(날짜/시간/타임존 등)를 치환. 커스텀 플레이스홀더는 그대로 둔다.
    static func process(_ text: String, at reference: Date = Date()) -> String {
        var result = text

        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: reference))
        let month = String(format: "%02d", calendar.component(.month, from: reference))
        let day = String(format: "%02d", calendar.component(.day, from: reference))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = dateFormatter.string(from: reference)
        dateFormatter.dateFormat = "HH:mm:ss"
        let isoTime = dateFormatter.string(from: reference)

        let dateTokens = ["{날짜}", "{date}"]
        let timeTokens = ["{시간}", "{time}"]
        let yearTokens = ["{연도}", "{year}"]
        let monthTokens = ["{월}", "{month}"]
        let dayTokens = ["{일}", "{day}"]

        for token in dateTokens { result = result.replacingOccurrences(of: token, with: isoDate) }
        for token in timeTokens { result = result.replacingOccurrences(of: token, with: isoTime) }
        for token in yearTokens { result = result.replacingOccurrences(of: token, with: year) }
        for token in monthTokens { result = result.replacingOccurrences(of: token, with: month) }
        for token in dayTokens { result = result.replacingOccurrences(of: token, with: day) }

        let groupDefaults = UserDefaults(suiteName: AppGroup.identifier)
        let timezoneValue = groupDefaults?.string(forKey: userTimezoneKey)?.nonEmpty
            ?? TimeZone.current.identifier
        result = result.replacingOccurrences(of: "{timezone}", with: timezoneValue)
        result = result.replacingOccurrences(of: "{타임존}", with: timezoneValue)

        let offsetSeconds = TimeZone.current.secondsFromGMT(for: reference)
        let offsetHours = offsetSeconds / 3600
        let offsetString = offsetHours >= 0 ? "GMT+\(offsetHours)" : "GMT\(offsetHours)"
        result = result.replacingOccurrences(of: "{timezone_offset}", with: offsetString)

        let currencyValue = groupDefaults?.string(forKey: userCurrencyKey)?.nonEmpty
            ?? Locale.current.currency?.identifier
            ?? "USD"
        result = result.replacingOccurrences(of: "{currency}", with: currencyValue)
        result = result.replacingOccurrences(of: "{통화}", with: currencyValue)

        let greeting = localizedGreeting(for: reference)
        result = result.replacingOccurrences(of: "{greeting_time}", with: greeting)
        result = result.replacingOccurrences(of: "{인사}", with: greeting)

        let city = cityFromTimezone(timezoneValue)
        result = result.replacingOccurrences(of: "{city}", with: city)
        result = result.replacingOccurrences(of: "{도시}", with: city)

        return result
    }

    private static func cityFromTimezone(_ tz: String) -> String {
        guard let last = tz.split(separator: "/").last else { return tz }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    private static func localizedGreeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return NSLocalizedString("Good morning", comment: "Greeting — morning")
        case 12..<18:
            return NSLocalizedString("Good afternoon", comment: "Greeting — afternoon")
        default:
            return NSLocalizedString("Good evening", comment: "Greeting — evening/night")
        }
    }

    /// 메모 본문에서 커스텀 토큰만 추출 (autoVariableTokens 제외). 등장 순서 보존·중복 제거.
    static func extractCustomTokens(in text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        var seen: Set<String> = []
        var ordered: [String] = []
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let token = String(text[range])
            if autoVariableTokens.contains(token) { continue }
            if seen.insert(token).inserted { ordered.append(token) }
        }
        return ordered
    }

    /// 사용자 입력값으로 토큰 치환 후 자동 변수까지 처리한 최종 문자열.
    static func substitute(_ text: String, with inputs: [String: String]) -> String {
        var result = text
        for (token, value) in inputs {
            result = result.replacingOccurrences(of: token, with: value)
        }
        return process(result)
    }
}

// MARK: - Template chip rendering (맥용, 시스템 색)

extension String {
    /// `{플레이스홀더}`를 중괄호 없는 칩(강조색 + 부드러운 배경)으로 렌더링.
    /// 아직 채우지 않은 변수 자리를 코드가 아니라 '채울 칸'처럼 보이게 한다.
    func templateChipAttributed() -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else {
            return AttributedString(self)
        }
        let ns = self as NSString
        var out = AttributedString()
        var cursor = 0
        for match in regex.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            let full = match.range
            if full.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: full.location - cursor))
                out += AttributedString(plain)
            }
            let name = ns.substring(with: match.range(at: 1))
            var chip = AttributedString("\u{2009}\(name)\u{2009}")
            chip.foregroundColor = Color.accentColor
            chip.backgroundColor = Color.accentColor.opacity(0.16)
            chip.font = .body.weight(.semibold)
            out += chip
            cursor = full.location + full.length
        }
        if cursor < ns.length {
            out += AttributedString(ns.substring(from: cursor))
        }
        return out
    }

    /// 자동 변수를 뺀 사용자 정의 플레이스홀더 목록.
    func extractTemplatePlaceholders() -> [String] {
        TemplateVariableProcessor.extractCustomTokens(in: self)
    }
}

// MARK: - Memo template helpers

extension Memo {
    /// 채워야 할 사용자 정의 플레이스홀더 목록 (자동 변수 제외).
    var customPlaceholders: [String] {
        TemplateVariableProcessor.extractCustomTokens(in: value)
    }

    /// 사용자 입력이 필요한 커스텀 플레이스홀더가 있는지.
    var hasCustomPlaceholders: Bool { !customPlaceholders.isEmpty }

    /// 붙여넣기용으로 자동 변수(날짜/시간/타임존 등)를 치환한 문자열.
    /// 커스텀 플레이스홀더({이름} 등)는 그대로 둔다 — 값 채우기 UI에서 처리.
    func resolvedForPaste() -> String {
        guard isTemplate || value.contains("{") else { return value }
        return TemplateVariableProcessor.process(value)
    }
}

// MARK: - Helpers

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
