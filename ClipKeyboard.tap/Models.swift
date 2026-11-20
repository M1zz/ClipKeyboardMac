//
//  Models.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import Combine
import AppKit

// Clipboard History Model
struct ClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true // 자동으로 7일 후 삭제
    var imageFileName: String? // 이미지 파일명 (있는 경우)
    var imageFileNames: [String] = [] // 여러 이미지 파일명
    var contentType: ClipboardContentType = .text

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true, imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
    }
}

// MARK: - Clipboard Item Type (자동 분류)
enum ClipboardItemType: String, Codable, CaseIterable {
    case email = "이메일"
    case phone = "전화번호"
    case address = "주소"
    case url = "URL"
    case creditCard = "카드번호"
    case bankAccount = "계좌번호"
    case passportNumber = "여권번호"
    case declarationNumber = "통관번호"
    case postalCode = "우편번호"
    case name = "이름"
    case birthDate = "생년월일"
    case taxID = "세금번호"
    case insuranceNumber = "보험번호"
    case vehiclePlate = "차량번호"
    case ipAddress = "IP주소"
    case membershipNumber = "회원번호"
    case trackingNumber = "송장번호"
    case confirmationCode = "예약번호"
    case medicalRecord = "진료기록번호"
    case employeeID = "사번/학번"
    case image = "이미지"
    case text = "텍스트"
    // v4.0 글로벌 피봇 (iOS와 동기화)
    case iban = "IBAN"
    case swift = "SWIFT/BIC"
    case vat = "VAT Number"
    case cryptoWallet = "Crypto Wallet"
    case paypalLink = "PayPal Link"

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .address: return "location.fill"
        case .url: return "link"
        case .creditCard: return "creditcard.fill"
        case .bankAccount: return "banknote.fill"
        case .passportNumber: return "person.text.rectangle.fill"
        case .declarationNumber: return "doc.text.fill"
        case .postalCode: return "mappin.circle.fill"
        case .name: return "person.fill"
        case .birthDate: return "calendar"
        case .taxID: return "number.circle.fill"
        case .insuranceNumber: return "cross.case.fill"
        case .vehiclePlate: return "car.fill"
        case .ipAddress: return "network"
        case .membershipNumber: return "star.circle.fill"
        case .trackingNumber: return "shippingbox.fill"
        case .confirmationCode: return "checkmark.seal.fill"
        case .medicalRecord: return "stethoscope"
        case .employeeID: return "person.badge.key.fill"
        case .image: return "photo.fill"
        case .text: return "doc.text"
        case .iban: return "building.columns.fill"
        case .swift: return "globe"
        case .vat: return "doc.badge.gearshape"
        case .cryptoWallet: return "bitcoinsign.circle.fill"
        case .paypalLink: return "dollarsign.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .email: return "blue"
        case .phone: return "green"
        case .address: return "purple"
        case .url: return "orange"
        case .creditCard: return "red"
        case .bankAccount: return "indigo"
        case .passportNumber: return "brown"
        case .declarationNumber: return "cyan"
        case .postalCode: return "teal"
        case .name: return "pink"
        case .birthDate: return "mint"
        case .taxID: return "yellow"
        case .insuranceNumber: return "teal"
        case .vehiclePlate: return "green"
        case .ipAddress: return "purple"
        case .membershipNumber: return "orange"
        case .trackingNumber: return "brown"
        case .confirmationCode: return "indigo"
        case .medicalRecord: return "red"
        case .employeeID: return "cyan"
        case .image: return "pink"
        case .text: return "gray"
        case .iban: return "blue"
        case .swift: return "indigo"
        case .vat: return "orange"
        case .cryptoWallet: return "yellow"
        case .paypalLink: return "blue"
        }
    }

    // 다국어 지원 표시명
    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Clipboard item type")
    }

    // Xcode String Catalog이 문자열을 감지하도록 하는 헬퍼 함수
    static func preloadLocalizedStrings() {
        _ = NSLocalizedString("이메일", comment: "Email")
        _ = NSLocalizedString("전화번호", comment: "Phone Number")
        _ = NSLocalizedString("주소", comment: "Address")
        _ = NSLocalizedString("URL", comment: "URL")
        _ = NSLocalizedString("카드번호", comment: "Card Number")
        _ = NSLocalizedString("계좌번호", comment: "Account Number")
        _ = NSLocalizedString("여권번호", comment: "Passport Number")
        _ = NSLocalizedString("통관번호", comment: "Declaration Number")
        _ = NSLocalizedString("우편번호", comment: "Postal Code")
        _ = NSLocalizedString("이름", comment: "Name")
        _ = NSLocalizedString("생년월일", comment: "Date of Birth")
        _ = NSLocalizedString("세금번호", comment: "Tax ID")
        _ = NSLocalizedString("보험번호", comment: "Insurance Number")
        _ = NSLocalizedString("차량번호", comment: "Vehicle Plate")
        _ = NSLocalizedString("IP주소", comment: "IP Address")
        _ = NSLocalizedString("회원번호", comment: "Membership Number")
        _ = NSLocalizedString("송장번호", comment: "Tracking Number")
        _ = NSLocalizedString("예약번호", comment: "Confirmation Code")
        _ = NSLocalizedString("진료기록번호", comment: "Medical Record Number")
        _ = NSLocalizedString("사번/학번", comment: "Employee/Student ID")
        _ = NSLocalizedString("이미지", comment: "Image")
        _ = NSLocalizedString("텍스트", comment: "Text")
        // v4.0 글로벌 피봇
        _ = NSLocalizedString("IBAN", comment: "IBAN (International Bank Account Number)")
        _ = NSLocalizedString("SWIFT/BIC", comment: "SWIFT/BIC bank code")
        _ = NSLocalizedString("VAT Number", comment: "VAT identification number")
        _ = NSLocalizedString("Crypto Wallet", comment: "Cryptocurrency wallet address")
        _ = NSLocalizedString("PayPal Link", comment: "PayPal.me link")
    }
}

enum ClipboardContentType: String, Codable {
    case text
    case image
    case emoji
    case mixed // 텍스트 + 이미지
}

/// **단축어 스택**의 한 칸. 이름(`key`)과 넣을 글(`value`)을 함께 갖는다.
///
/// ⚠️ **iOS 의 `StackItem` 과 글자 하나까지 같은 모양이어야 한다.** 두 앱이 App Group 의
///    같은 `memos.data` 를 읽고 쓴다. 여기 모양이 어긋나면 한쪽이 저장할 때마다 다른 쪽이
///    지은 이름이 지워진다.
///
/// ⚠️ 맥은 이 값을 **고치지 않는다.** 칸 목록을 바꾸는 화면은 아이폰에만 있고, 맥은 읽어서
///    보여 주고 그대로 다시 쓰기만 한다. 그래도 필드를 가지고 있어야 하는 이유가 그것이다.
///    모르는 키는 합성 인코더가 **버리기** 때문에, 맥에서 메모를 한 번 저장하면
///    아이폰에서 지은 칸 이름이 통째로 사라진다.
struct StackItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var key: String
    var value: String
    var reference: UUID?

    init(id: UUID = UUID(), key: String = "", value: String, reference: UUID? = nil) {
        self.id = id
        self.key = key
        self.value = value
        self.reference = reference
    }

    /// 관용 디코더 - `Memo` 와 같은 이유다. 비옵셔널 키가 없으면 배열 전체가 무너진다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.reference = try c.decodeIfPresent(UUID.self, forKey: .reference)
    }

    enum CodingKeys: String, CodingKey { case id, key, value, reference }
}

struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var value: String
    var isChecked: Bool = false
    var lastEdited: Date = Date()
    var isFavorite: Bool = false
    var clipCount: Int = 0

    // New features
    var category: String = "기본"
    var isSecure: Bool = false
    var isTemplate: Bool = false
    var templateVariables: [String] = []
    var shortcut: String?

    // 템플릿의 플레이스홀더 값들 저장 (예: {이름}: [유미, 주디, 리이오])
    var placeholderValues: [String: [String]] = [:]

    // iOS 필드 (round-trip 손실 방지용)
    var lastUsedAt: Date?
    var isStack: Bool = false
    var stackValues: [String] = []
    var currentComboIndex: Int = 0
    /// 콤보 = 자식 메모 참조(순서 있음). iOS와 round-trip 포맷 일치.
    var childMemoIds: [UUID] = []
    var stackInterval: TimeInterval = 2.0
    /// 스택의 칸들(이름 + 값). 아이폰이 적고 맥은 읽어서 보여 주기만 한다.
    /// **가지고 있지 않으면 맥이 저장할 때마다 이름이 지워진다**(`StackItem` 머리말).
    var stackItems: [StackItem] = []
    var autoDetectedType: ClipboardItemType?

    // 이미지 지원
    var imageFileName: String? // 이미지 파일명 (있는 경우) - 하위 호환성 유지
    var imageFileNames: [String] = [] // 여러 이미지 파일명
    var contentType: ClipboardContentType = .text

    /// "어디서 / 언제 쓰나요?" 컨텍스트 힌트 (iOS와 round-trip 일치).
    /// ⚠️ CodingKeys에서 빠지면 맥에서 저장할 때 iOS가 쓴 힌트가 영구 소실된다.
    var hint: String?

    /// 힌트를 아이폰 키보드에 띄울지 (iOS 전용 UI 설정 — 맥에는 대응 화면이 없다).
    /// ⚠️ 맥이 쓰지 않는다고 빼면 안 된다. `payload` 는 로컬 `Memo` 의 JSON 통짜라,
    ///    맥이 이 메모를 한 번 수정해 올리는 순간 필드가 사라져 아이폰에서 기본값(true)으로
    ///    되살아난다 → 사용자가 꺼 둔 "키보드에 힌트 표시"가 저절로 켜진다.
    ///    맥은 값을 읽지도 쓰지도 않고 **그대로 실어 나르기만** 한다.
    var hintShownOnKeyboard: Bool = true

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, isTemplate: Bool = false, templateVariables: [String] = [], shortcut: String? = nil, placeholderValues: [String: [String]] = [:], imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text, hint: String? = nil, hintShownOnKeyboard: Bool = true) {
        self.id = id
        self.title = title
        self.value = value
        self.isChecked = isChecked
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
        self.category = category
        self.isSecure = isSecure
        self.isTemplate = isTemplate
        self.templateVariables = templateVariables
        self.shortcut = shortcut
        self.placeholderValues = placeholderValues
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
        self.hint = hint
        self.hintShownOnKeyboard = hintShownOnKeyboard
    }

    /// 구버전(1.x) 포맷 마이그레이션 — iOS의 Memo(from: OldMemo)와 동일.
    init(from oldMemo: OldMemo) {
        self.id = oldMemo.id
        self.title = oldMemo.title
        self.value = oldMemo.value
        self.isChecked = oldMemo.isChecked
        self.lastEdited = Date()
        self.isFavorite = false
    }

    /// 화면이 부를 칸 이름. 이름을 안 지은 칸은 자리로 부른다(1단계, 2단계).
    /// ⚠️ 그릴 때 만든다. 데이터에 적어 두면 언어를 바꿔도 그 말이 따라오지 않는다.
    func displayKey(at index: Int) -> String {
        guard stackItems.indices.contains(index) else { return "" }
        let key = stackItems[index].key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { return key }
        return String(format: NSLocalizedString("%d단계", comment: "Stack item fallback name by position"),
                      index + 1)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, value, isChecked
        case lastEdited, isFavorite, clipCount
        case category, isSecure, isTemplate, templateVariables, shortcut, placeholderValues
        // ⚠️ 파일에 적히는 글자는 옛 이름 그대로다. 코드 이름만 iOS 와 맞춘다.
        //    글자를 바꾸면 쓰던 사람의 memos.data 와 아이폰이 쓴 것을 못 읽는다.
        case lastUsedAt
        case isStack = "isCombo"
        case stackValues = "comboValues"
        case currentComboIndex, autoDetectedType
        case childMemoIds
        case stackInterval = "comboInterval"
        case stackItems
        case imageFileName, imageFileNames, contentType
        case hint, hintShownOnKeyboard
    }

    /// 관용 디코더 — 누락 키를 모두 기본값으로 허용한다. ⚠️ 하위호환 필수:
    /// 합성 Codable은 비옵셔널 키 누락 시 keyNotFound로 [Memo] 전체 디코딩을 무너뜨린다.
    /// iOS/구버전이 쓴 데이터에 일부 키가 없어도 macOS 앱에서 메모가 사라지지 않게 한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        self.lastEdited = try c.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.clipCount = try c.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        self.isSecure = try c.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        self.isTemplate = try c.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? false
        self.templateVariables = try c.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        self.shortcut = try c.decodeIfPresent(String.self, forKey: .shortcut)
        self.placeholderValues = try c.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        self.lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        self.isStack = try c.decodeIfPresent(Bool.self, forKey: .isStack) ?? false
        self.stackValues = try c.decodeIfPresent([String].self, forKey: .stackValues) ?? []
        self.currentComboIndex = try c.decodeIfPresent(Int.self, forKey: .currentComboIndex) ?? 0
        self.childMemoIds = try c.decodeIfPresent([UUID].self, forKey: .childMemoIds) ?? []
        self.stackInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .stackInterval) ?? 2.0
        // 새 키가 있으면 그것이 진짜다. 없으면 값만 있던 옛 콤보를 그 자리에서 칸으로 옮긴다
        // (아이폰과 같은 규칙). 이름은 비워 두고, 부를 때만 자리로 부른다.
        if let items = try c.decodeIfPresent([StackItem].self, forKey: .stackItems), !items.isEmpty {
            self.stackItems = items
        } else {
            self.stackItems = (try c.decodeIfPresent([String].self, forKey: .stackValues) ?? [])
                .map { StackItem(value: $0) }
        }
        // ⚠️ 스택인지는 **칸이 있는지**로 정한다 - 아이폰은 `isStack` 을 `!stackItems.isEmpty` 로
        //    계산한다. 파일의 `isCombo` 표시만 믿었더니, 표시가 false 로 남은 스택을 맥이 일반
        //    단축어로 보고 대표 값 하나만 복사했다(⌃⇧V 패널에서 스택 창이 안 뜸).
        self.isStack = !self.stackItems.isEmpty
        self.autoDetectedType = try c.decodeIfPresent(ClipboardItemType.self, forKey: .autoDetectedType)
        self.imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
        self.hintShownOnKeyboard = try c.decodeIfPresent(Bool.self, forKey: .hintShownOnKeyboard) ?? true
    }
}

/// 구버전(1.x) 메모 포맷 — load() 폴백 디코딩용 (iOS Memo.swift와 동일).
struct OldMemo: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    var isChecked: Bool = false
}

enum MemoType {
    case memo
    case clipboardHistory
}

// MARK: - Smart Clipboard History (자동 분류 + 메타데이터)
struct SmartClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true

    // 콘텐츠 타입
    var contentType: ClipboardContentType = .text

    // 이미지 데이터 (Base64 인코딩)
    var imageData: String?

    // 이미지 메타데이터
    var imageWidth: Int?
    var imageHeight: Int?
    var imageFormat: String?  // "png", "jpeg", "gif"

    // 자동 분류
    var detectedType: ClipboardItemType = .text
    var confidence: Double = 0.0  // 0.0 ~ 1.0 (인식 신뢰도)

    // 메타데이터
    var sourceApp: String?  // 복사한 앱
    var tags: [String] = []
    var autoSaveOffered: Bool = false  // 자동 저장 제안 했는지

    // 사용자 피드백
    var userCorrectedType: ClipboardItemType?  // 사용자가 수정한 타입

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true, contentType: ClipboardContentType = .text, imageData: String? = nil, detectedType: ClipboardItemType = .text, confidence: Double = 0.0) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
        self.contentType = contentType
        self.imageData = imageData
        self.detectedType = detectedType
        self.confidence = confidence
    }
}

// MARK: - Combo Models

enum ComboItemType: String, Codable {
    case memo = "메모"
    case clipboardHistory = "클립보드"
    case template = "템플릿"

    // 다국어 지원 표시명
    // 다국어 지원 표시명 — rawValue와 분리(용어 개편: 저장 항목은 '단축어').
    // ⚠️ rawValue("메모")는 저장 데이터에 직렬화되므로 변경 금지.
    var localizedName: String {
        switch self {
        case .memo: return NSLocalizedString("단축어", comment: "Snippet (saved key-value item) display name")
        case .clipboardHistory: return NSLocalizedString("클립보드", comment: "Clipboard")
        case .template: return NSLocalizedString("템플릿", comment: "Template")
        }
    }
}

// Combo에 포함되는 개별 항목
struct ComboItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ComboItemType
    var referenceId: UUID  // 메모 또는 클립보드 항목의 ID
    var order: Int  // 실행 순서

    // 표시용 정보 (캐시)
    var displayTitle: String?  // 항목의 제목/미리보기
    var displayValue: String?  // 항목의 실제 값 (미리보기용)

    init(id: UUID = UUID(), type: ComboItemType, referenceId: UUID, order: Int, displayTitle: String? = nil, displayValue: String? = nil) {
        self.id = id
        self.type = type
        self.referenceId = referenceId
        self.order = order
        self.displayTitle = displayTitle
        self.displayValue = displayValue
    }
}

// Combo - 여러 메모를 순서대로 자동 입력하는 시스템
struct Combo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ComboItem]  // 순서대로 실행될 항목들
    var interval: TimeInterval = 2.0  // 각 항목 사이의 시간 간격 (초)
    var createdAt: Date = Date()
    var lastUsed: Date?
    var category: String = "텍스트"
    var useCount: Int = 0
    var isFavorite: Bool = false

    init(id: UUID = UUID(), title: String, items: [ComboItem] = [], interval: TimeInterval = 2.0, createdAt: Date = Date(), lastUsed: Date? = nil, category: String = "텍스트", useCount: Int = 0, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.items = items.sorted(by: { $0.order < $1.order })
        self.interval = interval
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.category = category
        self.useCount = useCount
        self.isFavorite = isFavorite
    }

    // 항목을 순서대로 정렬
    mutating func sortItems() {
        items.sort(by: { $0.order < $1.order })
    }
}
