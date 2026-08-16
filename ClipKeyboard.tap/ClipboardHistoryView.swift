//
//  ClipboardHistoryView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @State private var clipboardHistory: [ClipboardHistory] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var searchText: String = ""

    var filteredHistory: [ClipboardHistory] {
        if searchText.isEmpty {
            return clipboardHistory
        }
        return clipboardHistory.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: MacSpacing.md) {
                    HStack(spacing: MacSpacing.md) {
                        VStack(alignment: .leading, spacing: MacSpacing.xs) {
                            Text(NSLocalizedString("클립보드 히스토리", comment: "Clipboard history title"))
                                .font(MacFont.screenTitle)

                            Text(String(format: NSLocalizedString("%d개의 항목", comment: "Item count"), clipboardHistory.count))
                                .font(MacFont.secondary)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(NSLocalizedString("전체 삭제", comment: "Clear all")) {
                            clearAll()
                        }
                        .tint(.red)
                        .disabled(clipboardHistory.isEmpty)
                    }

                    // 검색 바
                    HStack(spacing: MacSpacing.sm) {
                        Image(systemName: AppSymbol.magnifyingglass)
                            .foregroundStyle(.secondary)

                        TextField(NSLocalizedString("검색...", comment: "Search placeholder"), text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: AppSymbol.xmarkCircleFill)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, MacSpacing.md)
                    .padding(.vertical, MacSpacing.sm)
                    .macSurface()
                }
                .font(MacFont.body)
                .padding(MacSpacing.xl)

                Divider()

                // 리스트
                if filteredHistory.isEmpty {
                    EmptyListView
                } else {
                    List {
                        ForEach(filteredHistory) { item in
                            ClipboardItemRow(item: item) {
                                // 클립보드에 복사
                                if item.contentType == .image {
                                    copyImageToClipboard(item)
                                    showToast(message: NSLocalizedString("이미지", comment: "Image type"))
                                } else {
                                    copyToClipboard(item.content)
                                    showToast(message: item.content)
                                }
                            } onSave: {
                                // 메모로 저장
                                saveToMemo(item)
                            } onDelete: {
                                // 삭제
                                deleteItem(item)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }

            // Toast 메시지
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .font(MacFont.body)
                        .padding(.horizontal, MacSpacing.lg)
                        .padding(.vertical, MacSpacing.md)
                        .background(.black.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, MacSpacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture {
                            showToast = false
                        }
                }
            }
            .animation(.easeInOut, value: showToast)
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            loadHistory()
        }
    }

    // MARK: - Empty View

    private var EmptyListView: some View {
        VStack(spacing: MacSpacing.md) {
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tertiary)

            Text(searchText.isEmpty ? NSLocalizedString("클립보드 히스토리 없음", comment: "No clipboard history") : NSLocalizedString("검색 결과 없음", comment: "No search results"))
                .font(MacFont.sectionTitle)

            Text(searchText.isEmpty ?
                 NSLocalizedString("복사한 내용이 자동으로 여기에 저장됩니다\n(최대 100개, 7일간 유지)", comment: "Clipboard history empty description") :
                 String(format: NSLocalizedString("'%@'와 일치하는 항목이 없습니다", comment: "No results for search query"), searchText))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadHistory() {
        do {
            clipboardHistory = try MemoStore.shared.loadClipboardHistory()
            print("📋 [ClipboardHistory] \(clipboardHistory.count)개 항목 로드됨")
        } catch {
            print("❌ [ClipboardHistory] 로드 실패: \(error)")
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyImageToClipboard(_ item: ClipboardHistory) {
        guard let imageFileName = item.imageFileName,
              let image = MemoStore.shared.loadImage(fileName: imageFileName) else {
            print("❌ [ClipboardHistory] 이미지 로드 실패")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func showToast(message: String) {
        let preview = message.prefix(30)
        toastMessage = String(format: NSLocalizedString("[%@] 클립보드에 복사되었습니다", comment: "Clipboard copy toast"), String(preview) + (message.count > 30 ? "..." : ""))
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func deleteItem(_ item: ClipboardHistory) {
        clipboardHistory.removeAll { $0.id == item.id }
        do {
            try MemoStore.shared.saveClipboardHistory(history: clipboardHistory)
            print("🗑️ [ClipboardHistory] 항목 삭제됨")
        } catch {
            print("❌ [ClipboardHistory] 삭제 실패: \(error)")
        }
    }

    private func clearAll() {
        clipboardHistory.removeAll()
        do {
            try MemoStore.shared.saveClipboardHistory(history: [])
            print("🗑️ [ClipboardHistory] 전체 삭제됨")
        } catch {
            print("❌ [ClipboardHistory] 전체 삭제 실패: \(error)")
        }
    }

    private func saveToMemo(_ item: ClipboardHistory) {
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            let newMemo = Memo(
                title: item.contentType == .image ? NSLocalizedString("이미지", comment: "Image type") : String(item.content.prefix(30)),
                value: item.content,
                lastEdited: Date(),
                imageFileName: item.imageFileName,
                contentType: item.contentType
            )
            memos.append(newMemo)
            try MemoStore.shared.save(memos: memos, type: .memo)

            toastMessage = NSLocalizedString("단축어로 저장되었습니다", comment: "Saved as memo toast")
            showToast = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
            }

            print("💾 [ClipboardHistory] 메모로 저장됨")
        } catch {
            print("❌ [ClipboardHistory] 메모 저장 실패: \(error)")
        }
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardHistory
    let onCopy: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: MacSpacing.md) {
            // 콘텐츠
            VStack(alignment: .leading, spacing: MacSpacing.sm) {
                if item.contentType == .image {
                    // 이미지 표시
                    if let imageFileName = item.imageFileName,
                       let image = MemoStore.shared.loadImage(fileName: imageFileName) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .cornerRadius(MacRadius.sm)
                    } else {
                        HStack(spacing: MacSpacing.sm) {
                            Image(systemName: AppSymbol.photo)
                            Text(NSLocalizedString("이미지를 불러올 수 없습니다", comment: "Image load error"))
                        }
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    // 텍스트 표시
                    Text(item.content)
                        .font(MacFont.body)
                        .lineLimit(3)
                }

                HStack(spacing: MacSpacing.md) {
                    Text(formatDate(item.copiedAt))

                    if item.isTemporary {
                        Text(NSLocalizedString("임시", comment: "Temporary tag"))
                            .padding(.horizontal, MacSpacing.sm)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }

                    if item.contentType == .image {
                        Text(NSLocalizedString("이미지", comment: "Image tag"))
                            .padding(.horizontal, MacSpacing.sm)
                            .padding(.vertical, 1)
                            .background(MacColor.surface, in: Capsule())
                    }
                }
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // 액션 버튼들 (hover 시에만 표시)
            if isHovering {
                HStack(spacing: MacSpacing.md) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: AppSymbol.squareAndArrowDown)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("단축어로 저장", comment: "Save as memo tooltip"))

                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: AppSymbol.docOnDoc)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("클립보드에 복사", comment: "Copy to clipboard tooltip"))

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: AppSymbol.trash)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("삭제", comment: "Delete tooltip"))
                }
                .font(MacFont.body)
            }
        }
        .padding(.vertical, MacSpacing.md)
        .padding(.horizontal, MacSpacing.md)
        .background(isHovering ? MacColor.hover : Color.clear)
        .cornerRadius(MacRadius.sm)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCopy()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ClipboardHistoryView()
}
