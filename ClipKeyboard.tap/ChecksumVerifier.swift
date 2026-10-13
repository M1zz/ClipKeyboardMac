//
//  ChecksumVerifier.swift
//  ClipKeyboard
//
//  "틀리지 않았다"를 사용자에게 보여주기 위한 검증 API.
//
//  왜 새로 만드나: mod-97(IBAN)·Luhn(카드) 검증은 `ClipboardClassificationService`
//  안에 이미 있지만 **private 이고, 분류에 성공했는지만 알려준다.** 사용자는
//  자기 계좌번호가 검증을 통과했다는 사실을 한 번도 못 본다. 조용히 맞히는 것과
//  "맞았습니다"라고 각인해 주는 것은 완전히 다른 경험이라 표시용 API를 따로 둔다.
//
//  ⚠️ 분류 동작은 건드리지 않는다. 이 파일은 **읽기 전용 판정**만 한다.
//     (여기에 사업자등록번호를 추가해도 자동분류 결과는 달라지지 않는다)
//
//  ⚠️ 확실할 때만 말한다 - 가장 중요한 규칙.
//     아무 숫자에나 "체크섬 불일치"를 띄우면 delight가 아니라 잘못된 고발이 된다.
//     그래서 형식이 명백한 경우(IBAN 형태, 4-4-4-4 카드 표기, 3-2-5 사업자번호)에만
//     실패를 단언하고, 형식이 모호하면 **성공만 말하고 실패는 침묵한다**(nil 반환).
//
//  ⚠️ 값 자체는 절대 로그에 남기지 않는다 - 계좌·카드번호다.
//

import Foundation

enum ChecksumVerifier {

    // MARK: - 판정 대상

    enum Subject {
        case iban
        case creditCard
        case businessNumber

        var displayName: String {
            switch self {
            case .iban:
                return NSLocalizedString("IBAN", comment: "Checksum subject: international bank account number")
            case .creditCard:
                return NSLocalizedString("카드번호", comment: "Checksum subject: credit card number")
            case .businessNumber:
                return NSLocalizedString("사업자등록번호", comment: "Checksum subject: Korean business registration number")
            }
        }

        /// 실패했을 때 어디를 보라고 알려줄지. 나무라지 않고 고칠 지점만 말한다.
        var repairHint: String {
            switch self {
            case .iban:
                return NSLocalizedString("앞 4자리(국가코드+검증번호)를 다시 확인해 주세요. 나머지는 형식이 맞습니다.",
                                         comment: "Repair hint when IBAN checksum fails")
            case .creditCard:
                return NSLocalizedString("숫자 하나가 어긋났어요. 카드에 적힌 번호와 다시 맞춰보세요.",
                                         comment: "Repair hint when card checksum fails")
            case .businessNumber:
                return NSLocalizedString("마지막 자리가 맞지 않아요. 사업자등록증과 다시 맞춰보세요.",
                                         comment: "Repair hint when business number checksum fails")
            }
        }
    }

    // MARK: - 결과

    struct Result: Equatable {
        let subject: Subject
        let isValid: Bool

        /// 통과 시 짧은 확인 문구, 실패 시 고칠 지점.
        var detail: String {
            isValid
                ? NSLocalizedString("체크섬을 통과했어요.", comment: "Message when a checksum passes")
                : subject.repairHint
        }

        /// 각인에 찍히는 한 단어.
        var stampLabel: String {
            isValid
                ? NSLocalizedString("검증됨", comment: "Stamp label: verified")
                : NSLocalizedString("확인 필요", comment: "Stamp label: needs checking")
        }
    }

    // MARK: - 진입점

    /// 값에 검증 가능한 체크섬이 있으면 판정한다.
    /// - Returns: 판정 결과. **검증 대상이 아니거나 형식이 모호하면 nil** (아무 말도 하지 않는다).
    static func verify(_ raw: String) -> Result? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }

        if let result = verifyIBAN(trimmed) { return result }
        if let result = verifyCreditCard(trimmed) { return result }
        if let result = verifyBusinessNumber(trimmed) { return result }
        return nil
    }

    // MARK: - IBAN (ISO 13616 mod-97)

    /// IBAN은 "2자리 국가코드 + 2자리 검증번호 + 영숫자" 형태 자체가 고유해서
    /// 형식만 맞으면 실패도 단언할 수 있다.
    static func verifyIBAN(_ raw: String) -> Result? {
        let normalized = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard normalized.range(of: "^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$",
                               options: .regularExpression) != nil else { return nil }

        return Result(subject: .iban, isValid: mod97(normalized) == 1)
    }

    /// 앞 4자를 뒤로 옮기고 문자를 숫자로 바꾼 뒤(A=10 … Z=35) 97로 나눈 나머지.
    /// 자릿수가 길어 정수 오버플로가 나므로 한 자리씩 누적한다.
    private static func mod97(_ normalized: String) -> Int? {
        let rearranged = String(normalized.dropFirst(4)) + String(normalized.prefix(4))
        var remainder = 0
        for char in rearranged {
            let chunk: String
            if char.isLetter {
                guard let ascii = char.asciiValue else { return nil }
                chunk = String(Int(ascii) - 55)
            } else {
                chunk = String(char)
            }
            for digitChar in chunk {
                guard let digit = digitChar.wholeNumberValue else { return nil }
                remainder = (remainder * 10 + digit) % 97
            }
        }
        return remainder
    }

    // MARK: - 카드번호 (Luhn)

    /// 4-4-4-4 처럼 **끊어 적은 표기**는 카드가 거의 확실하므로 실패도 말한다.
    /// 붙여 쓴 숫자 뭉치는 계좌번호일 수 있어서 통과했을 때만 말한다.
    static func verifyCreditCard(_ raw: String) -> Result? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 13, digits.count <= 19 else { return nil }

        let valid = isValidLuhn(digits)
        let looksGrouped = raw.range(of: "^[0-9]{4}[ -][0-9]{4}[ -][0-9]{4}[ -][0-9]{3,4}$",
                                     options: .regularExpression) != nil

        // 붙여 쓴 데다 통과도 못 했다면 카드번호라는 근거가 없다 → 침묵.
        guard valid || looksGrouped else { return nil }
        return Result(subject: .creditCard, isValid: valid)
    }

    static func isValidLuhn(_ digits: String) -> Bool {
        var sum = 0
        for (index, char) in digits.reversed().enumerated() {
            guard let digit = char.wholeNumberValue else { return false }
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    // MARK: - 사업자등록번호 (국세청 가중치 체크섬)

    /// 3-2-5 하이픈 표기면 사업자번호가 거의 확실하므로 실패도 말한다.
    /// 붙여 쓴 10자리는 전화번호와 겹칠 수 있어 통과했을 때만 말한다.
    static func verifyBusinessNumber(_ raw: String) -> Result? {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 10 else { return nil }

        let dashed = raw.range(of: "^[0-9]{3}-[0-9]{2}-[0-9]{5}$", options: .regularExpression) != nil
        let valid = isValidBusinessNumber(digits)

        guard valid || dashed else { return nil }
        return Result(subject: .businessNumber, isValid: valid)
    }

    /// 가중치 [1,3,7,1,3,7,1,3,5]로 앞 9자리를 더하고,
    /// 9번째 자리 × 5의 십의 자리를 한 번 더 더한 뒤 10의 보수가 마지막 자리와 같아야 한다.
    static func isValidBusinessNumber(_ digits: String) -> Bool {
        let numbers = digits.compactMap(\.wholeNumberValue)
        guard numbers.count == 10 else { return false }

        let weights = [1, 3, 7, 1, 3, 7, 1, 3, 5]
        var sum = zip(numbers.prefix(9), weights).reduce(0) { $0 + $1.0 * $1.1 }
        sum += (numbers[8] * 5) / 10

        let check = (10 - (sum % 10)) % 10
        return check == numbers[9]
    }
}
