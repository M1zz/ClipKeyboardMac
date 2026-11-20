//
//  MemoStore.swift
//  ClipKeyboard.tap
//
//  단축어 · 스택 · 복사 기록을 App Group 파일로 읽고 쓰는 저장소.
//  `Models.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import Foundation
import Combine
import AppKit

// MemoStore - Simplified for macOS
class MemoStore: ObservableObject {
    static let shared = MemoStore()

    /// `memoDataChanged` 의 userInfo 열쇠. iOS `MemoStore.changeKindKey` 와 같은 값이다.
    static let changeKindKey = "MemoStore.change"

    /// 쓴 횟수만 바뀐 저장의 알림인가. 공유 파일(`MemoSyncEngine`)이 iOS 와 같은 이름으로 부른다.
    /// Mac 저장은 아직 변경 종류를 싣지 않으므로 늘 내용 변경으로 본다(지금처럼 매번 동기화한다).
    static func isUsageOnly(_ note: Notification) -> Bool {
        (note.userInfo?[changeKindKey] as? String) == "usage"
    }

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
        #if DEBUG
        if MacShotMode.isOn { return }  // 촬영 모드는 디스크(실데이터)에 아무것도 쓰지 않는다
        #endif
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
        #if DEBUG
        if MacShotMode.isOn { return }
        #endif
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile, options: .atomic)
    }

    func load(type: MemoType) throws -> [Memo] {
        #if DEBUG
        // 촬영 모드: 실데이터 대신 실행 인자로 받은 데모 단축어를 보여 준다.
        if MacShotMode.isOn {
            guard type == .memo, let data = MacShotMode.demoData("ClipShotDemoMemos") else { return [] }
            return (try? JSONDecoder().decode([Memo].self, from: data)) ?? []
        }
        #endif
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

        // 못 읽은 원본을 옆에 남긴다 — 빈 목록으로 시작해 다음 저장이 덮어써도 되찾을 수 있게
        Self.keepUnreadable(fileURL)
        return []
    }

    /// 깨진 파일을 지우지 않고 `.unreadable` 사본으로 남긴다. 이미 있으면 첫 사본을 지킨다.
    static func keepUnreadable(_ url: URL) {
        try? FileManager.default.copyItem(at: url, to: url.appendingPathExtension("unreadable"))
    }

    func loadClipboardHistory() throws -> [ClipboardHistory] {
        #if DEBUG
        if MacShotMode.isOn {
            guard let data = MacShotMode.demoData("ClipShotDemoClips") else { return [] }
            return (try? JSONDecoder().decode([ClipboardHistory].self, from: data)) ?? []
        }
        #endif
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

        // 칸이 정한 개수까지만 유지 (무료 50 · Plus 100)
        let limit = MacPlan.shared.historyLimit
        if history.count > limit {
            history = Array(history.prefix(limit))
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
            content: NSLocalizedString("이미지", comment: "Image type"),
            copiedAt: Date(),
            isTemporary: true,
            imageFileName: fileName,
            contentType: .image
        )
        history.insert(newItem, at: 0)

        // 칸이 정한 개수까지만 유지 (무료 50 · Plus 100)
        let limit = MacPlan.shared.historyLimit
        if history.count > limit {
            // 삭제되는 항목의 이미지 파일도 삭제
            for item in history[limit...] {
                if let imageFileName = item.imageFileName {
                    try? deleteImage(fileName: imageFileName)
                }
            }
            history = Array(history.prefix(limit))
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
            throw NSError(domain: "MemoStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("앱 공용 저장소를 찾을 수 없습니다.",
                                                             comment: "Error: App Group container missing")
            ])
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
            throw NSError(domain: "MemoStore", code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("이미지를 PNG로 변환할 수 없습니다.",
                                                             comment: "Error: image to PNG conversion failed")
            ])
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
        Self.keepUnreadable(fileURL)
        return []
    }

    func saveCombos(_ combos: [Combo]) throws {
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.combosFileURL() else { return }
        try data.write(to: outfile, options: .atomic)
    }
}
