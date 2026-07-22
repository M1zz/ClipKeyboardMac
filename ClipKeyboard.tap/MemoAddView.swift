//
//  MemoAddView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-12-11.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MemoAddView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var textContent: String = ""
    @State private var category: String = "기본"
    @State private var attachedImages: [NSImage] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: AppSymbol.squareAndPencil)
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)

                    Text(NSLocalizedString("새 단축어", comment: "Add memo title"))
                        .font(.title2)
                        .bold()

                    Spacer()

                    Button {
                        closeWindow()
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // 제목 입력
                TextField(NSLocalizedString("제목", comment: "Title placeholder"), text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                // 카테고리 선택
                HStack {
                    Text(NSLocalizedString("Category Label", comment: "Category inline label (with colon)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(NSLocalizedString("카테고리", comment: "Category placeholder"), text: $category)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 100)

                    Spacer()
                }
            }
            .padding()

            Divider()

            // 컨텐츠 입력 영역
            ScrollView {
                VStack(spacing: 16) {
                    // 텍스트 입력
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: AppSymbol.textAlignleft)
                                .foregroundStyle(.blue)
                            Text(NSLocalizedString("내용", comment: "Content section header"))
                                .font(.headline)
                        }

                        TextEditor(text: $textContent)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(MacRadius.sm)

                        // 자동 변수 삽입 + 커스텀 플레이스홀더 안내
                        templateVariableBar

                        // 내용에 {토큰}이 있으면 칩 미리보기
                        if textContent.contains("{") {
                            Text(textContent.templateChipAttributed())
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.accentColor.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: MacRadius.sm))
                        }
                    }

                    // 이미지 첨부 영역
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: AppSymbol.photo)
                                .foregroundStyle(.purple)
                            Text(NSLocalizedString("이미지 첨부", comment: "Image attachment section header"))
                                .font(.headline)

                            Spacer()

                            if !attachedImages.isEmpty {
                                Text(String(format: NSLocalizedString("%d개", comment: "Item count"), attachedImages.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 이미지 추가 버튼
                        HStack(spacing: 12) {
                            Button {
                                selectImageFromFile()
                            } label: {
                                Label(NSLocalizedString("파일에서 선택", comment: "Pick from file"), systemImage: AppSymbol.folder)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                pasteImageFromClipboard()
                            } label: {
                                Label(NSLocalizedString("클립보드에서 붙여넣기", comment: "Paste from clipboard"), systemImage: AppSymbol.docOnClipboard)
                            }
                            .buttonStyle(.bordered)
                        }

                        // 첨부된 이미지들
                        if !attachedImages.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 120))
                            ], spacing: 12) {
                                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, image in
                                    ImageAttachmentView(image: image) {
                                        removeImage(at: index)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: AppSymbol.photoOnRectangleAngled)
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text(NSLocalizedString("이미지를 추가해보세요", comment: "Empty image hint"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(MacRadius.sm)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 하단 버튼
            HStack(spacing: 12) {
                Spacer()

                Button(NSLocalizedString("취소", comment: "Cancel button")) {
                    closeWindow()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("저장", comment: "Save button")) {
                    saveMemo()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, -20)
            .padding(.bottom)
        }
        .frame(minWidth: 480, minHeight: 560)
        .overlay(
            // Toast 메시지
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(MacRadius.sm)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: showToast)
        )
        .onTapGesture {
            // 빈 공간 탭 시 키보드 내리기
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    // MARK: - Template Variable Bar

    /// 탭하면 본문에 삽입되는 자동 변수들. iOS의 자동 변수 토큰과 동일.
    private let autoVars: [(token: String, labelKey: String)] = [
        ("{date}", "날짜"),
        ("{time}", "시간"),
        ("{timezone}", "타임존"),
        ("{currency}", "통화"),
        ("{greeting_time}", "인사"),
        ("{city}", "도시")
    ]

    private var templateVariableBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("자동으로 채워지는 값", comment: "Auto-fill variables hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(autoVars, id: \.token) { item in
                        Button {
                            insertToken(item.token)
                        } label: {
                            Text(NSLocalizedString(item.labelKey, comment: "Auto template variable"))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(NSLocalizedString("{ }로 감싸면 입력할 때 채우는 칸이 됩니다", comment: "Custom placeholder hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func insertToken(_ token: String) {
        textContent += token
    }

    // MARK: - Computed Properties

    private var canSave: Bool {
        if title.isEmpty {
            return false
        }
        return !textContent.isEmpty || !attachedImages.isEmpty
    }

    // MARK: - Actions

    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = NSLocalizedString("이미지를 선택하세요", comment: "Open panel: pick image message")

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    attachedImages.append(image)
                }
            }
        }
    }

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            attachedImages.append(image)
            showToastMessage(NSLocalizedString("클립보드에서 이미지를 추가했습니다", comment: "Toast: image added from clipboard"))
        } else {
            showToastMessage(NSLocalizedString("클립보드에 이미지가 없습니다", comment: "Toast: no image in clipboard"))
        }
    }

    private func removeImage(at index: Int) {
        guard index < attachedImages.count else { return }
        attachedImages.remove(at: index)
    }

    private func saveMemo() {
        do {
            var memos = try MemoStore.shared.load(type: .memo)

            // 이미지들을 파일로 저장
            var savedImageFileNames: [String] = []
            for image in attachedImages {
                let fileName = "\(UUID().uuidString).png"
                try MemoStore.shared.saveImage(image, fileName: fileName)
                savedImageFileNames.append(fileName)
            }

            // 컨텐츠 타입 결정
            let contentType: ClipboardContentType
            if !textContent.isEmpty && !savedImageFileNames.isEmpty {
                contentType = .mixed
            } else if !savedImageFileNames.isEmpty {
                contentType = .image
            } else {
                contentType = .text
            }

            // 템플릿 감지: 본문에 {토큰}이 있으면 템플릿으로 저장
            let customTokens = textContent.extractTemplatePlaceholders()
            let isTemplate = textContent.contains("{")

            let newMemo = Memo(
                title: title,
                value: textContent,
                category: category,
                isTemplate: isTemplate,
                templateVariables: customTokens,
                imageFileNames: savedImageFileNames,
                contentType: contentType
            )
            memos.append(newMemo)

            try MemoStore.shared.save(memos: memos, type: .memo)

            print("✅ [MemoAdd] 메모 저장 완료")
            showToastMessage(NSLocalizedString("단축어가 저장되었습니다", comment: "Toast: memo saved"))

            // 저장 후 창 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                closeWindow()
            }
        } catch {
            print("❌ [MemoAdd] 메모 저장 실패: \(error)")
            showToastMessage(String(format: NSLocalizedString("저장 실패: %@", comment: "Toast: save failed with reason"), error.localizedDescription))
        }
    }

    private func closeWindow() {
        // 현재 윈도우 찾아서 닫기
        if let window = NSApp.keyWindow {
            window.close()
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

// MARK: - Image Attachment View

struct ImageAttachmentView: View {
    let image: NSImage
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(MacRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: MacRadius.sm)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            if isHovering {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: AppSymbol.xmarkCircleFill)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MemoAddView()
}
