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
    @State private var category: String = MacCategoryName.localizedBasic
    @State private var attachedImages: [NSImage] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: MacSpacing.md) {
                HStack {
                    Text(NSLocalizedString("새 단축어", comment: "Add memo title"))
                        .font(MacFont.screenTitle)

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
                    .font(MacFont.body)

                // 카테고리 선택
                HStack(spacing: MacSpacing.sm) {
                    Text(NSLocalizedString("Category Label", comment: "Category inline label (with colon)"))
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)

                    TextField(NSLocalizedString("카테고리", comment: "Category placeholder"), text: $category)
                        .textFieldStyle(.roundedBorder)
                        .font(MacFont.body)
                        .frame(width: 160)

                    Spacer()
                }
            }
            .padding(MacSpacing.xl)

            Divider()

            // 컨텐츠 입력 영역
            ScrollView {
                VStack(spacing: MacSpacing.xl) {
                    // 텍스트 입력
                    VStack(alignment: .leading, spacing: MacSpacing.sm) {
                        Text(NSLocalizedString("내용", comment: "Content section header"))
                            .font(MacFont.sectionTitle)

                        TextEditor(text: $textContent)
                            .font(MacFont.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(MacSpacing.sm)
                            .macSurface()
                            .overlay(alignment: .topLeading) {
                                // 빈 상태 힌트 — 단축어에 보일 내용을 입력하라는 안내.
                                if textContent.isEmpty {
                                    Text(NSLocalizedString("단축어에 보일 내용을 입력하세요", comment: "Content placeholder"))
                                        .font(MacFont.body)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            }

                        // 자동 변수 삽입 + 커스텀 플레이스홀더 안내
                        templateVariableBar

                        // 내용에 {토큰}이 있으면 칩 미리보기
                        if textContent.contains("{") {
                            Text(textContent.templateChipAttributed())
                                .font(MacFont.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(MacSpacing.md)
                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: MacRadius.sm))
                        }
                    }

                    // 이미지 첨부 영역
                    VStack(alignment: .leading, spacing: MacSpacing.sm) {
                        HStack {
                            Text(NSLocalizedString("이미지 첨부", comment: "Image attachment section header"))
                                .font(MacFont.sectionTitle)

                            Spacer()

                            if !attachedImages.isEmpty {
                                Text(String(format: NSLocalizedString("%d개", comment: "Item count"), attachedImages.count))
                                    .font(MacFont.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 이미지 추가 버튼
                        HStack(spacing: MacSpacing.md) {
                            Button {
                                selectImageFromFile()
                            } label: {
                                Label(NSLocalizedString("파일에서 선택", comment: "Pick from file"), systemImage: AppSymbol.folder)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button {
                                pasteImageFromClipboard()
                            } label: {
                                // 아이콘만 표시 — 접근성/툴팁은 라벨 텍스트 유지.
                                Label(NSLocalizedString("클립보드에서 붙여넣기", comment: "Paste from clipboard"), systemImage: AppSymbol.docOnClipboard)
                                    .labelStyle(.iconOnly)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .help(NSLocalizedString("클립보드에서 붙여넣기", comment: "Paste from clipboard"))
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
                            VStack(spacing: MacSpacing.md) {
                                Image(systemName: AppSymbol.photoOnRectangleAngled)
                                    .font(.system(size: MacIcon.hero))
                                    .foregroundStyle(.tertiary)
                                Text(NSLocalizedString("이미지를 추가해보세요", comment: "Empty image hint"))
                                    .font(MacFont.secondary)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MacSpacing.xl)
                            .macSurface()
                        }
                    }
                }
                .padding(MacSpacing.xl)
            }

            Divider()

            // 하단 버튼
            HStack(spacing: MacSpacing.md) {
                Spacer()

                Button(NSLocalizedString("취소", comment: "Cancel button")) {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("저장", comment: "Save button")) {
                    saveMemo()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .controlSize(.large)
            .padding(MacSpacing.lg)
        }
        .font(MacFont.body)
        .frame(minWidth: 520, minHeight: 600)
        .overlay(
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
    private let autoVars: [(token: String, label: String)] = [
        ("{date}", NSLocalizedString("날짜", comment: "Auto template variable")),
        ("{time}", NSLocalizedString("시간", comment: "Auto template variable")),
        ("{timezone}", NSLocalizedString("타임존", comment: "Auto template variable")),
        ("{currency}", NSLocalizedString("통화", comment: "Auto template variable")),
        ("{greeting_time}", NSLocalizedString("인사", comment: "Auto template variable")),
        ("{city}", NSLocalizedString("도시", comment: "Auto template variable"))
    ]

    private var templateVariableBar: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("자동으로 채워지는 값", comment: "Auto-fill variables hint"))
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MacSpacing.sm) {
                    ForEach(autoVars, id: \.token) { item in
                        Button {
                            insertToken(item.token)
                        } label: {
                            Text(item.label)
                                .font(MacFont.body)
                                .padding(.horizontal, MacSpacing.md)
                                .padding(.vertical, MacSpacing.xs + 2)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            Text(NSLocalizedString("{ }로 감싸면 입력할 때 채우는 칸이 됩니다", comment: "Custom placeholder hint"))
                .font(MacFont.secondary)
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

            // 템플릿 감지: 본문에 {토큰}이 있으면 템플릿으로 저장.
            // ⚠️ 기준은 `contains("{")` 가 아니라 **추출된 토큰이 있는지**다.
            //    iOS 는 `isTemplate` 을 `!templateVariables.isEmpty` 로 계산하므로,
            //    `{` 만 있고 유효 토큰이 없는 본문을 맥만 템플릿으로 보면 같은 메모가
            //    기기마다 다르게 동작한다(맥은 채우기 시트, 아이폰은 그냥 붙여넣기).
            let customTokens = textContent.extractTemplatePlaceholders()
            let isTemplate = !customTokens.isEmpty

            let newMemo = Memo(
                title: title,
                value: textContent,
                category: MacCategoryName.stored(category),
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
