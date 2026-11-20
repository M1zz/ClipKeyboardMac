//
//  DataPortability.swift
//  ClipKeyboard.tap
//
//  파일로 내보내고 가져오기: 묶음의 모양 · 읽고 쓰는 규칙 · 파일 도큐먼트.
//  `CloudBackupView.swift` 에서 떼어 냈다. 한 파일에 한 가지만 두어, 고칠 자리를 이름으로 찾게 한다.
//

import SwiftUI
import AppKit
import CloudKit
import UniformTypeIdentifiers

// MARK: - 파일 백업 번들 (내보내기/가져오기)

/// App Group에 저장된 모든 사용자 데이터를 담는 자기완결형 백업 번들.
/// 이미지까지 base64로 동봉하므로 이 파일 하나로 전체 복원이 가능하다.
struct ExportBundle: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var memos: [Memo]
    var smartClipboard: [SmartClipboardHistory]
    var combos: [Combo]
    var images: [String: Data]
}

/// 가져오기 결과 요약.
struct ImportSummary {
    var addedMemos: Int
    var updatedMemos: Int
    var totalMemos: Int
    var addedCombos: Int
    var addedClips: Int
    var images: Int

    var localizedDescription: String {
        String(format: NSLocalizedString("단축어 %1$d개 추가, %2$d개 갱신 (총 %3$d개).\n스택 %4$d개, 이미지 %5$d개를 가져왔습니다.", comment: "Import summary message"),
               addedMemos, updatedMemos, totalMemos, addedCombos, images)
    }
}

enum PortabilityError: LocalizedError {
    case noContainer
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .noContainer:
            return NSLocalizedString("저장소를 찾을 수 없습니다.", comment: "App Group container missing")
        case .unreadableFile:
            return NSLocalizedString("이 파일은 ClipKeyboard 백업 파일이 아니거나 손상되었습니다.", comment: "Unrecognized backup file")
        }
    }
}

/// 내보내기/가져오기 공통 로직. App Group 컨테이너 파일을 직접 다루므로
/// UIKit/AppKit 의존이 없고 iOS·macOS 양쪽에서 동일하게 동작한다.
enum DataPortability {
    static let currentFormatVersion = 1

    private static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    private static func read<T: Decodable>(_ file: String, as type: T.Type) -> T? {
        guard let url = container()?.appendingPathComponent(file),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to file: String) throws {
        guard let url = container()?.appendingPathComponent(file) else { throw PortabilityError.noContainer }
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    static var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    static func suggestedFilename() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return "ClipKeyboard-Backup-\(f.string(from: Date())).json"
    }

    /// 현재 App Group의 모든 데이터를 JSON 번들로 직렬화(이미지 동봉).
    static func makeBundleData() throws -> Data {
        let memos = read(StorageFile.memos, as: [Memo].self) ?? []
        let smart = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        let combos = read(StorageFile.combos, as: [Combo].self) ?? []

        var images: [String: Data] = [:]
        if let imagesDir = container()?.appendingPathComponent("Images", isDirectory: true) {
            for name in Set(memos.flatMap { $0.imageFileNames }) {
                if let d = try? Data(contentsOf: imagesDir.appendingPathComponent(name)) {
                    images[name] = d
                }
            }
        }

        let bundle = ExportBundle(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            appVersion: appVersionString,
            memos: memos, smartClipboard: smart, combos: combos, images: images
        )
        return try JSONEncoder().encode(bundle)
    }

    /// 번들을 병합 가져오기. 절대 삭제하지 않고, id 기준으로 합치며 충돌 시 최신본(lastEdited) 유지.
    @discardableResult
    static func importBundle(_ data: Data) throws -> ImportSummary {
        guard let bundle = try? JSONDecoder().decode(ExportBundle.self, from: data) else {
            throw PortabilityError.unreadableFile
        }
        guard let container = container() else { throw PortabilityError.noContainer }

        // 1) 이미지 먼저 복원(메모가 참조). 이미 있으면 보존.
        var restoredImages = 0
        if !bundle.images.isEmpty {
            let imagesDir = container.appendingPathComponent("Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            for (name, bytes) in bundle.images {
                let dest = imagesDir.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try? bytes.write(to: dest, options: .atomic)
                    restoredImages += 1
                }
            }
        }

        // 2) 메모 병합 (순서 보존, id 충돌 시 최신 lastEdited 우선)
        var memos = read(StorageFile.memos, as: [Memo].self) ?? []
        var indexById = [UUID: Int]()
        for (i, m) in memos.enumerated() { indexById[m.id] = i }
        var added = 0, updated = 0
        for m in bundle.memos {
            if let i = indexById[m.id] {
                if m.lastEdited > memos[i].lastEdited { memos[i] = m; updated += 1 }
            } else {
                indexById[m.id] = memos.count
                memos.append(m)
                added += 1
            }
        }
        try write(memos, to: StorageFile.memos)

        // 3) 콤보 병합 (union by id)
        var combos = read(StorageFile.combos, as: [Combo].self) ?? []
        var comboIds = Set(combos.map { $0.id })
        var addedCombos = 0
        for c in bundle.combos where !comboIds.contains(c.id) {
            combos.append(c); comboIds.insert(c.id); addedCombos += 1
        }
        try write(combos, to: StorageFile.combos)

        // 4) 스마트 클립보드 병합 (union by id)
        var clips = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        var clipIds = Set(clips.map { $0.id })
        var addedClips = 0
        for c in bundle.smartClipboard where !clipIds.contains(c.id) {
            clips.append(c); clipIds.insert(c.id); addedClips += 1
        }
        try write(clips, to: StorageFile.smartClipboardHistory)

        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)

        return ImportSummary(addedMemos: added, updatedMemos: updated, totalMemos: memos.count,
                             addedCombos: addedCombos, addedClips: addedClips, images: restoredImages)
    }
}

// MARK: - 파일 도큐먼트 (fileExporter/fileImporter 용)

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    CloudBackupView()
}
