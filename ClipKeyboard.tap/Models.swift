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
    var isCombo: Bool = false
    var comboValues: [String] = []
    var currentComboIndex: Int = 0
    /// 콤보 = 자식 메모 참조(순서 있음). iOS와 round-trip 포맷 일치.
    var childMemoIds: [UUID] = []
    var comboInterval: TimeInterval = 2.0
    var autoDetectedType: ClipboardItemType?

    // 이미지 지원
    var imageFileName: String? // 이미지 파일명 (있는 경우) - 하위 호환성 유지
    var imageFileNames: [String] = [] // 여러 이미지 파일명
    var contentType: ClipboardContentType = .text

    /// "어디서 / 언제 쓰나요?" 컨텍스트 힌트 (iOS와 round-trip 일치).
    /// ⚠️ CodingKeys에서 빠지면 맥에서 저장할 때 iOS가 쓴 힌트가 영구 소실된다.
    var hint: String?

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, isTemplate: Bool = false, templateVariables: [String] = [], shortcut: String? = nil, placeholderValues: [String: [String]] = [:], imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text, hint: String? = nil) {
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

    enum CodingKeys: String, CodingKey {
        case id, title, value, isChecked
        case lastEdited, isFavorite, clipCount
        case category, isSecure, isTemplate, templateVariables, shortcut, placeholderValues
        case lastUsedAt, isCombo, comboValues, currentComboIndex, autoDetectedType
        case childMemoIds, comboInterval
        case imageFileName, imageFileNames, contentType
        case hint
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
        self.isCombo = try c.decodeIfPresent(Bool.self, forKey: .isCombo) ?? false
        self.comboValues = try c.decodeIfPresent([String].self, forKey: .comboValues) ?? []
        self.currentComboIndex = try c.decodeIfPresent(Int.self, forKey: .currentComboIndex) ?? 0
        self.childMemoIds = try c.decodeIfPresent([UUID].self, forKey: .childMemoIds) ?? []
        self.comboInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .comboInterval) ?? 2.0
        self.autoDetectedType = try c.decodeIfPresent(ClipboardItemType.self, forKey: .autoDetectedType)
        self.imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
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

// MemoStore - Simplified for macOS
class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []

    private static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            print("❌ [MemoStore.fileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }

        let fileURL: URL
        switch type {
        case .memo:
            fileURL = containerURL.appendingPathComponent(StorageFile.memos)
        case .clipboardHistory:
            fileURL = containerURL.appendingPathComponent(StorageFile.clipboardHistory)
        }

        return fileURL
    }

    func save(memos: [Memo], type: MemoType) throws {
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile, options: .atomic)
        // 메모 변경을 알려 동기화 엔진(MemoSyncEngine)이 변경분을 클라우드로 올리게 한다.
        // (iOS MemoStore.save와 동일한 신호. 콜러가 메인 스레드가 아닐 수 있어 메인에서 post.)
        if type == .memo {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .memoDataChanged, object: nil) }
        }
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile, options: .atomic)
    }

    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else {
            return []
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        if let memos = try? JSONDecoder().decode([Memo].self, from: data) {
            return memos
        }

        // 구버전(1.x) 포맷 폴백 — iOS decodeMemosFromData와 동일한 마이그레이션 경로.
        if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
            print("🔄 [MemoStore.load] 구버전 포맷 감지 - OldMemo \(oldMemos.count)개 마이그레이션")
            return oldMemos.map { Memo(from: $0) }
        }

        return []
    }

    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([ClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    // 클립보드 히스토리 추가
    func addToClipboardHistory(content: String) throws {
        var history = try loadClipboardHistory()

        // 중복 제거
        history.removeAll { $0.content == content }

        // 새 항목 추가
        let newItem = ClipboardHistory(content: content)
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    // 이미지와 함께 클립보드 히스토리 추가
    func addImageToClipboardHistory(image: NSImage) throws {
        var history = try loadClipboardHistory()

        // 이미지 파일로 저장
        let fileName = "\(UUID().uuidString).png"
        try saveImage(image, fileName: fileName)

        // 새 항목 추가
        let newItem = ClipboardHistory(
            content: "이미지",
            copiedAt: Date(),
            isTemporary: true,
            imageFileName: fileName,
            contentType: .image
        )
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            // 삭제되는 항목의 이미지 파일도 삭제
            for item in history[100...] {
                if let imageFileName = item.imageFileName {
                    try? deleteImage(fileName: imageFileName)
                }
            }
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let itemsToDelete = history.filter { $0.isTemporary && $0.copiedAt < sevenDaysAgo }
        for item in itemsToDelete {
            if let imageFileName = item.imageFileName {
                try? deleteImage(fileName: imageFileName)
            }
        }
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    // 이미지 저장
    func saveImage(_ image: NSImage, fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images", isDirectory: true)

        // 이미지 디렉토리 생성
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }

        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // NSImage를 PNG 데이터로 변환
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MemoStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "이미지를 PNG로 변환할 수 없음"])
        }

        try pngData.write(to: fileURL, options: .atomic)
    }

    // 이미지 로드
    func loadImage(fileName: String) -> NSImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            return nil
        }

        let fileURL = containerURL.appendingPathComponent("Images", isDirectory: true).appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return NSImage(contentsOf: fileURL)
    }

    // 이미지 삭제
    func deleteImage(fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            return
        }

        let fileURL = containerURL.appendingPathComponent("Images", isDirectory: true).appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Smart Clipboard History Methods

    private static func smartClipboardFileURL() throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            print("❌ [MemoStore.smartClipboardFileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }
        return containerURL.appendingPathComponent(StorageFile.smartClipboardHistory)
    }

    func loadSmartClipboardHistory() throws -> [SmartClipboardHistory] {
        guard let fileURL = try Self.smartClipboardFileURL() else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    func saveSmartClipboardHistory(history: [SmartClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.smartClipboardFileURL() else { return }
        try data.write(to: outfile, options: .atomic)
    }

    // MARK: - Combo Methods

    private static func combosFileURL() throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            print("❌ [MemoStore.combosFileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }
        return containerURL.appendingPathComponent(StorageFile.combos)
    }

    func loadCombos() throws -> [Combo] {
        guard let fileURL = try Self.combosFileURL() else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let combos = try? JSONDecoder().decode([Combo].self, from: data) {
            return combos
        }
        return []
    }

    func saveCombos(_ combos: [Combo]) throws {
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.combosFileURL() else { return }
        try data.write(to: outfile, options: .atomic)
    }
}

// MARK: - MacProManager

/// iOS 구매 상태를 iCloud KV Store로 동기화받아 macOS Pro 여부 판단.
/// iCloud KV Store 우선, 없으면 App Group UserDefaults 폴백.
struct MacProManager {
    static let proStatusKey = DefaultsKey.proStatus

    static let freeMemoLimit = 10
    static let freeClipboardLimit = 50

    static var isPro: Bool {
        if NSUbiquitousKeyValueStore.default.bool(forKey: proStatusKey) { return true }
        return UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: proStatusKey) ?? false
    }

    static var isCloudBackupAvailable: Bool {
        #if DEBUG
        return true   // 디버그 빌드: 백업 잠금 해제(그랜드파더 Pro 사용자 데이터 복구용). 릴리스/앱스토어 빌드엔 영향 없음.
        #else
        return isPro
        #endif
    }

    static var memoDisplayLimit: Int { isPro ? Int.max : freeMemoLimit }
    static var clipboardDisplayLimit: Int { isPro ? 100 : freeClipboardLimit }

    /// 구매 상태가 변경될 때 KV Store에서 새로고침 (앱 포그라운드 복귀 시 호출 권장)
    static func refreshFromCloud() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

// MARK: - MacMemoOrder

/// 사용자가 지정한 수동 순서(단축어 순서 바꾸기)를 App Group을 통해 iOS·키보드 익스텐션과 공유한다.
/// iOS `ClipKeyboardListViewModel`의 `sortMemos`/`commitReorder`와 **동일한 규칙**으로 동작해야
/// 아이폰에서 바꾼 순서가 맥에 그대로 나타나고, 맥에서 바꾼 순서도 아이폰·키보드에 반영된다.
enum MacMemoOrder {
    private static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    /// 사용자가 수동 순서를 한 번이라도 지정했는지. true면 즐겨찾기 고정을 풀고 지정 순서를 그대로 따른다.
    static var isActive: Bool {
        groupDefaults?.bool(forKey: DefaultsKey.memoManualOrderActiveV1) ?? false
    }

    /// 저장된 수동 순서(메모 id 배열).
    private static var order: [UUID] {
        let raw = groupDefaults?.stringArray(forKey: DefaultsKey.memoManualOrderV1) ?? []
        return raw.compactMap { UUID(uuidString: $0) }
    }

    /// 표시 정렬 — 수동 순서가 있으면 그 순서대로(미등록 새 메모는 맨 위), 없으면 즐겨찾기 먼저 → 최근 편집순.
    /// iOS `sortMemos`와 규칙이 동일하다.
    static func sorted(_ memos: [Memo]) -> [Memo] {
        if isActive {
            let ranks = Dictionary(
                order.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            return memos.sorted { a, b in
                switch (ranks[a.id], ranks[b.id]) {
                case let (ra?, rb?): return ra < rb
                case (nil, _?):      return true   // 순서 미등록(새 메모)은 위로
                case (_?, nil):      return false
                case (nil, nil):     return a.lastEdited > b.lastEdited
                }
            }
        }
        return memos.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite && !b.isFavorite }
            return a.lastEdited > b.lastEdited
        }
    }

    /// 재정렬된 부분집합(`reordered`)을 전체 순서에 병합해 App Group에 영구 저장한다.
    /// 현재 탭/카테고리의 메모만 재정렬한 경우, 전체 순서에서 그 메모들이 차지하던 슬롯만 새 순서로
    /// 치환한다 — 다른 메모의 상대 순서는 유지. iOS `commitReorder`와 동일한 규칙.
    /// - Parameters:
    ///   - reordered: 사용자가 드래그로 새로 정렬한 (부분)목록.
    ///   - allMemos: 디스크에서 로드한 전체 메모(정렬 전 원본이어도 됨 — 내부에서 표시 순서로 정렬해 병합).
    static func commit(reordered: [Memo], within allMemos: [Memo]) {
        guard !reordered.isEmpty else { return }
        let base = sorted(allMemos)   // 현재 표시 순서 기준으로 슬롯 치환
        let subsetIds = Set(reordered.map(\.id))
        var iterator = reordered.makeIterator()
        var merged: [Memo] = []
        merged.reserveCapacity(base.count)
        for memo in base {
            if subsetIds.contains(memo.id) {
                if let next = iterator.next() { merged.append(next) }
            } else {
                merged.append(memo)
            }
        }
        // 방어: base에 없던 재정렬 항목이 남으면 뒤에 덧붙인다(유실 방지).
        while let leftover = iterator.next() { merged.append(leftover) }

        groupDefaults?.set(merged.map { $0.id.uuidString }, forKey: DefaultsKey.memoManualOrderV1)
        groupDefaults?.set(true, forKey: DefaultsKey.memoManualOrderActiveV1)
        print("✅ [MacMemoOrder.commit] 수동 순서 저장 — 재정렬 \(reordered.count)개 / 전체 \(merged.count)개")
    }
}
