//
//  ValueFormat.swift
//  ClipKeyboard.tap
//
//  ⚠️ iOS `ClipKeyboard/Service/ValueFormat.swift` 를 옮겨 온 것. 자판 종류만 뺐다(맥에는 없다).
//     규칙을 고칠 일이 있으면 iOS 를 먼저 고치고 여기로 옮긴다.
//
//  딱 맞춰 적어야 쓸 수 있는 값(카드번호·전화번호·생년월일·여권번호·IBAN)의 입력 틀.
//
//  왜 필요한가: 이런 값은 한 자리만 어긋나도 결제·예약 칸에서 튕긴다. 예전에는 타입을
//  골라도 예시 값만 채워 줬고, 적는 동안에는 아무것도 잡아 주지 않았다. 체크섬 검증
//  (`ChecksumVerifier`)은 다 적은 뒤에야 말했다.
//
//  하는 일은 둘이다.
//  1. 적는 대로 모양을 잡는다(`format`). 카드는 4자리마다 하이픈, IBAN 은 4자마다 띄어쓰기.
//  2. 지금 값이 어떤 상태인지 한 줄로 말한다(`check`).
//
//  ⚠️ **막지 않고 알린다.** 여권번호는 나라마다, 카드는 15·16·19자리로 형식이 갈린다.
//     틀을 강제하면 외국 사용자나 예외 카드를 가진 사람이 저장 자체를 못 한다.
//     그래서 저장은 늘 되고, 틀린 것 같으면 어디를 볼지만 말한다(`ChecksumVerifier` 와 같은 태도).
//  ⚠️ 나라마다 다른 모양은 **확실한 곳에서만** 잡는다. 전화번호 하이픈은 한국 지역에서만
//     넣는다. 영국 07 번호에 한국식 하이픈을 넣으면 그건 돕는 게 아니라 망가뜨리는 것이다.
//  ⚠️ 값 자체는 로그에 남기지 않는다. 카드·여권번호다.
//

import AppKit
import SwiftUI

enum ValueFormat: CaseIterable {
    case creditCard
    case phone
    case birthDate
    case passport
    case iban

    // MARK: - 어느 값에 틀을 씌우나

    init?(type: ClipboardItemType) {
        switch type {
        case .creditCard:     self = .creditCard
        case .phone:          self = .phone
        case .birthDate:      self = .birthDate
        case .passportNumber: self = .passport
        case .iban:           self = .iban
        default:              return nil
        }
    }

    /// 단축어의 카테고리(테마 rawValue)로 찾는다.
    init?(category: String) {
        guard let type = ClipboardItemType(rawValue: category) else { return nil }
        self.init(type: type)
    }

    /// 템플릿 빈칸 이름(`{카드번호}`, `{Card Number}`)으로 찾는다.
    ///
    /// 빈칸 이름은 사람이 짓는다. 타입 이름(한국어 원래 이름 · 지금 언어의 이름)과
    /// 똑같을 때만 잡는다. "카드 메모" 같은 이름에 틀을 씌우면 글자를 못 적게 된다.
    init?(placeholder: String) {
        let name = placeholder
            .trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
            .lowercased()
        guard !name.isEmpty else { return nil }
        for format in Self.allCases {
            let type = format.type
            if name == type.rawValue.lowercased() || name == type.localizedName.lowercased() {
                self = format
                return
            }
        }
        return nil
    }

    var type: ClipboardItemType {
        switch self {
        case .creditCard: return .creditCard
        case .phone:      return .phone
        case .birthDate:  return .birthDate
        case .passport:   return .passportNumber
        case .iban:       return .iban
        }
    }

    // MARK: - 적는 대로 모양 잡기

    /// 적은 글을 이 값의 모양으로 다듬는다. **같은 값을 두 번 넣어도 결과가 같다**(멱등).
    ///
    /// ⚠️ 구분자는 **다음 글자가 있을 때만** 넣는다. "1234" 뒤에 하이픈을 미리 붙이면
    ///    지우기를 눌러 하이픈을 지운 순간 다시 붙어서, 지울 수가 없게 된다.
    /// ⚠️ 템플릿 칸(`{`)이 섞인 글은 건드리지 않는다. 부르는 쪽이 거른다.
    func format(_ raw: String) -> String {
        switch self {
        case .creditCard:
            let digits = String(raw.filter(\.isASCIIDigit).prefix(19))
            let groups = Self.isAmex(digits) ? [4, 6, 5] : [4, 4, 4, 4, 3]
            return Self.group(digits, sizes: groups, separator: "-")

        case .phone:
            // 국제 표기(+82 ...)나 다른 모양으로 적은 것은 손대지 않는다.
            guard Self.formatsKoreanPhone,
                  !raw.hasPrefix("+"),
                  raw.allSatisfy({ $0.isASCIIDigit || $0 == "-" }) else { return raw }
            return Self.koreanPhone(String(raw.filter(\.isASCIIDigit).prefix(11)))

        case .birthDate:
            // 숫자만 적고 있을 때만 잡는다. 1990.01.01 · 01/02/1990 처럼 자기 모양으로 적는 사람은 그대로 둔다.
            guard raw.allSatisfy({ $0.isASCIIDigit || $0 == "-" }) else { return raw }
            let digits = String(raw.filter(\.isASCIIDigit).prefix(8))
            return Self.group(digits, sizes: [4, 2, 2], separator: "-")

        case .passport:
            let cleaned = raw.uppercased().filter { $0.isASCIILetterOrDigit }
            return String(cleaned.prefix(9))

        case .iban:
            let cleaned = raw.uppercased().filter { $0.isASCIILetterOrDigit }
            return Self.group(String(cleaned.prefix(34)), sizes: Array(repeating: 4, count: 9), separator: " ")
        }
    }

    // MARK: - 지금 값이 어떤 상태인가

    enum Status: Equatable {
        /// 형식이 맞다.
        case ok(String)
        /// 아직 덜 적었다. 나무라지 않고 무엇이 남았는지만 말한다.
        case hint(String)
        /// 다 적었는데 맞지 않는 것 같다. 어디를 볼지 말한다.
        case problem(String)

        var message: String {
            switch self {
            case .ok(let m), .hint(let m), .problem(let m): return m
            }
        }
    }

    /// 지금 값의 상태. 비어 있으면 nil(아무 말도 하지 않는다).
    func check(_ raw: String) -> Status? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("{") else { return nil }

        switch self {
        case .creditCard:
            let digits = value.filter(\.isASCIIDigit)
            let expected = Self.isAmex(digits) ? 15 : 16
            if digits.count < expected {
                return .hint(NSLocalizedString("카드에 적힌 숫자를 모두 입력해 주세요",
                                               comment: "Card number field: shown while the number is still incomplete"))
            }
            return ChecksumVerifier.isValidLuhn(digits)
                ? .ok(NSLocalizedString("체크섬을 통과했어요.", comment: "Message when a checksum passes"))
                : .problem(ChecksumVerifier.Subject.creditCard.repairHint)

        case .phone:
            let digits = value.filter(\.isASCIIDigit)
            // 국제 전화번호(E.164)는 나라번호까지 15자리를 넘지 않는다.
            if digits.count > 15 {
                return .problem(Self.phoneLengthMessage)
            }
            return digits.count < 7 ? .hint(Self.phoneLengthMessage) : .ok(Self.formatOKMessage)

        case .birthDate:
            let digits = value.filter(\.isASCIIDigit)
            // 자기 모양(1990.01.01 등)으로 적었으면 숫자 8자리일 때만 날짜로 읽는다.
            guard digits.count >= 8 else {
                return .hint(NSLocalizedString("생년월일 8자리를 입력해 주세요 (예: 19900101)",
                                               comment: "Birth date field: shown while incomplete. Keep the example digits 19900101 as they are"))
            }
            return Self.isPlausibleBirthDate(digits) ? .ok(Self.formatOKMessage) : .problem(
                NSLocalizedString("없는 날짜예요. 다시 확인해 주세요",
                                  comment: "Birth date field: the date does not exist or is in the future"))

        case .passport:
            let cleaned = value.uppercased().filter { !$0.isWhitespace && $0 != "-" }
            let ok = cleaned.count >= 6 && cleaned.count <= 9
                && cleaned.allSatisfy(\.isASCIILetterOrDigit)
                && cleaned.contains(where: \.isASCIIDigit)
            if ok { return .ok(Self.formatOKMessage) }
            let message = NSLocalizedString("여권번호는 영문과 숫자 6~9자예요",
                                            comment: "Passport field: expected format. Passport numbers are 6 to 9 letters and digits")
            return cleaned.count < 6 ? .hint(message) : .problem(message)

        case .iban:
            let cleaned = value.uppercased().filter { $0.isASCIILetterOrDigit }
            if cleaned.count < 15 {
                return .hint(NSLocalizedString("국가 코드부터 끝까지 입력해 주세요",
                                               comment: "IBAN field: shown while the IBAN is still incomplete (it starts with a 2-letter country code)"))
            }
            guard let result = ChecksumVerifier.verifyIBAN(cleaned) else {
                return .problem(ChecksumVerifier.Subject.iban.repairHint)
            }
            return result.isValid
                ? .ok(NSLocalizedString("체크섬을 통과했어요.", comment: "Message when a checksum passes"))
                : .problem(ChecksumVerifier.Subject.iban.repairHint)
        }
    }

    // MARK: - Private Helpers

    private static var formatOKMessage: String {
        NSLocalizedString("형식이 맞아요", comment: "Value field: the typed value has the expected format")
    }

    private static var phoneLengthMessage: String {
        NSLocalizedString("전화번호는 숫자 7~15자리예요",
                          comment: "Phone field: expected length. Phone numbers have 7 to 15 digits")
    }

    /// 한국식 하이픈을 넣어도 되는 지역인가.
    private static var formatsKoreanPhone: Bool {
        Locale.current.region?.identifier == "KR"
    }

    /// Amex(34·37 로 시작)는 15자리, 4-6-5 로 끊는다.
    private static func isAmex(_ digits: String) -> Bool {
        digits.hasPrefix("34") || digits.hasPrefix("37")
    }

    /// 글자를 크기대로 끊어 구분자로 잇는다. 마지막 묶음 뒤에 남는 것은 마지막 묶음에 붙인다.
    private static func group(_ text: String, sizes: [Int], separator: String) -> String {
        var parts: [String] = []
        var rest = Substring(text)
        for (index, size) in sizes.enumerated() where !rest.isEmpty {
            let isLast = index == sizes.count - 1
            let take = isLast ? rest.count : min(size, rest.count)
            parts.append(String(rest.prefix(take)))
            rest = rest.dropFirst(take)
        }
        return parts.joined(separator: separator)
    }

    /// 02-123-4567 · 02-1234-5678 · 010-1234-5678 · 031-123-4567 · 1588-1234
    private static func koreanPhone(_ d: String) -> String {
        if d.hasPrefix("02") {
            let middle = d.count >= 10 ? 4 : 3
            return group(d, sizes: [2, middle, 4], separator: "-")
        }
        if d.count == 8, d.hasPrefix("1") {
            return group(d, sizes: [4, 4], separator: "-")
        }
        let middle = d.count >= 11 ? 4 : 3
        return group(d, sizes: [3, middle, 4], separator: "-")
    }

    /// 앞 8자리를 연월일(YYYYMMDD)로 읽어 실제로 있는 날이고, 1900년 이후이며 오늘을 넘지 않는가.
    private static func isPlausibleBirthDate(_ digits: String) -> Bool {
        let d = Array(digits.prefix(8))
        guard d.count == 8,
              let year = Int(String(d[0..<4])),
              let month = Int(String(d[4..<6])),
              let day = Int(String(d[6..<8])) else { return false }
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        let calendar = Calendar(identifier: .gregorian)
        guard year >= 1900,
              parts.isValidDate(in: calendar),
              let date = calendar.date(from: parts) else { return false }
        return date <= Date()
    }
}

// MARK: - Character

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetterOrDigit: Bool { isASCII && (isLetter || isNumber) }
}

// MARK: - 한 줄 안내

/// 입력칸 아래에 서는 한 줄. 맞으면 초록, 덜 적었으면 회색, 맞지 않는 것 같으면 주황.
///
/// ⚠️ 빨강을 쓰지 않는다. 오류가 아니라 확인해 달라는 말이다(`VerificationSealView` 와 같은 태도).
struct ValueFormatStatusLine: View {
    let status: ValueFormat.Status

    private var symbol: String {
        switch status {
        case .ok:      return AppSymbol.checkmarkSealFill
        case .hint:    return "info.circle"
        case .problem: return AppSymbol.exclamationmarkTriangleFill
        }
    }

    private var tint: Color {
        switch status {
        case .ok:      return Color(NSColor.systemGreen)
        case .hint:    return .secondary
        case .problem: return .orange
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
            Text(status.message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
