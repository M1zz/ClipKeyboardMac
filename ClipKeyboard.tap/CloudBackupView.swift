//
//  CloudBackupView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import CloudKit
import UniformTypeIdentifiers

struct CloudBackupView: View {
    @StateObject private var cloudService = CloudKitBackupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    // 파일 백업(내보내기/가져오기) — CloudKit·Pro·로그인과 무관한 최후의 보루
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupFileDocument? = nil
    @State private var exportFilename = "ClipKeyboard-Backup.json"

    var body: some View {
        if !MacProManager.isCloudBackupAvailable {
            macProGateView
        } else {
        backupContentView
        }
    }

    private var macProGateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: AppSymbol.icloudFill)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("iCloud 백업은 Pro 기능입니다", comment: "Cloud backup pro"))
                .font(.title3).fontWeight(.medium)
            Text(NSLocalizedString("iOS 앱에서 Pro를 구매하면 macOS에서도 자동으로 활성화됩니다.", comment: "Mac Pro sync hint"))
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
        .frame(minWidth: 500, minHeight: 420)
    }

    private var backupContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
            // 헤더
            VStack(spacing: 8) {
                Image(systemName: AppSymbol.icloudAndArrowUpFill)
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                Text(NSLocalizedString("iCloud 백업 및 복구", comment: "iCloud backup and restore title"))
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("데이터를 iCloud에 안전하게 백업하세요", comment: "Backup description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)

            Divider()

            // iCloud 상태
            HStack {
                Image(systemName: cloudService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Text(NSLocalizedString("iCloud 상태:", comment: "iCloud status label"))
                    .font(.headline)

                Text(cloudService.isAuthenticated ? NSLocalizedString("연결됨", comment: "Connected status") : NSLocalizedString("연결 안 됨", comment: "Disconnected status"))
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Spacer()

                Button(NSLocalizedString("상태 확인", comment: "Check status button")) {
                    cloudService.checkAccountStatus()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(MacRadius.sm)

            // 마지막 백업 정보
            if let lastBackupDate = cloudService.lastBackupDate {
                HStack {
                    Image(systemName: AppSymbol.clockFill)
                        .foregroundStyle(.blue)

                    Text(NSLocalizedString("마지막 백업:", comment: "Last backup label"))
                        .font(.headline)

                    Text(lastBackupDate, style: .relative)
                        .foregroundStyle(.secondary)

                    Text(NSLocalizedString("전", comment: "ago"))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(MacRadius.sm)
            }

            Spacer()

            // 액션 버튼들
            VStack(spacing: 16) {
                Button {
                    performBackup()
                } label: {
                    HStack {
                        if cloudService.isBackingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: AppSymbol.icloudAndArrowUp)
                        }
                        Text(cloudService.isBackingUp ? NSLocalizedString("백업 중...", comment: "Backing up status") : NSLocalizedString("백업하기", comment: "Backup button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!cloudService.isAuthenticated || cloudService.isBackingUp)

                Button {
                    performRestore()
                } label: {
                    HStack {
                        if cloudService.isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: AppSymbol.icloudAndArrowDown)
                        }
                        Text(cloudService.isRestoring ? NSLocalizedString("복구 중...", comment: "Restoring status") : NSLocalizedString("복구하기", comment: "Restore button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!cloudService.isAuthenticated || cloudService.isRestoring)

                Button {
                    performDelete()
                } label: {
                    HStack {
                        Image(systemName: AppSymbol.trash)
                        Text(NSLocalizedString("백업 삭제", comment: "Delete backup button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!cloudService.isAuthenticated || cloudService.lastBackupDate == nil)

                Divider()
                    .padding(.vertical, 4)

                // 파일 백업 — iCloud가 막혀도 데이터를 기기 파일로 직접 빼낼 수 있는 최후의 보루
                Button {
                    performExportToFile()
                } label: {
                    HStack {
                        Image(systemName: AppSymbol.arrowUpDocFill)
                        Text(NSLocalizedString("파일로 내보내기", comment: "Export to file button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Image(systemName: AppSymbol.arrowDownDocFill)
                        Text(NSLocalizedString("파일에서 가져오기", comment: "Import from file button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }

            Text(NSLocalizedString("📁 파일 백업은 iCloud와 별개로 데이터를 파일로 보관하는 가장 확실한 방법입니다. 가져오기는 현재 데이터를 지우지 않고 합칩니다.", comment: "File backup info"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            Text(NSLocalizedString("⚠️ 복구 시 현재 데이터가 백업 데이터로 교체됩니다", comment: "Restore warning"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 500, minHeight: 420)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                alertTitle = NSLocalizedString("내보내기 완료", comment: "Export completed")
                alertMessage = NSLocalizedString("데이터를 파일로 저장했습니다. 안전한 곳에 보관하세요.", comment: "Export success message")
            case .failure(let error):
                alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
                alertMessage = error.localizedDescription
            }
            showAlert = true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func performBackup() {
        Task {
            do {
                let memoCount = try await cloudService.backupData()
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 완료", comment: "Backup completed")
                    alertMessage = String(format: NSLocalizedString("단축어 %d개를 iCloud에 백업했습니다.", comment: "Backup success with count"), memoCount)
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performRestore() {
        Task {
            do {
                try await cloudService.restoreData()
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("백업 데이터가 성공적으로 복구되었습니다.", comment: "Backup data successfully restored")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performDelete() {
        Task {
            do {
                try await cloudService.deleteBackup()
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 완료", comment: "Deletion completed")
                    alertMessage = NSLocalizedString("백업 데이터가 삭제되었습니다.", comment: "Backup data deleted")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 실패", comment: "Deletion failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    // MARK: - 파일 백업 (내보내기/가져오기)

    private func performExportToFile() {
        do {
            let data = try DataPortability.makeBundleData()
            exportDocument = BackupFileDocument(data: data)
            exportFilename = DataPortability.suggestedFilename()
            showExporter = true
        } catch {
            alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
            alertMessage = error.localizedDescription
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let summary = try DataPortability.importBundle(data)
                NotificationCenter.default.post(name: .dataRestored, object: nil)
                alertTitle = NSLocalizedString("가져오기 완료", comment: "Import completed")
                alertMessage = summary.localizedDescription
                showAlert = true
            } catch {
                alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

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
        String(format: NSLocalizedString("단축어 %1$d개 추가, %2$d개 갱신 (총 %3$d개).\n콤보 %4$d개, 이미지 %5$d개를 가져왔습니다.", comment: "Import summary message"),
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
