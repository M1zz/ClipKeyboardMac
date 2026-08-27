//
//  MemoEditView.swift
//  ClipKeyboard.tap
//
//  이미 있는 단축어를 고치는 화면. 목록에서는 시트로, 메뉴바 팝오버에서는 창으로 열린다.
//
//  ⚠️ 새로 만들기(MemoAddView)와 달리 **원본 필드를 보존한 채 일부만 바꾼다.**
//     `payload` 는 로컬 `Memo` 의 JSON 통짜라, 여기서 새 Memo 를 만들어 덮으면
//     아이폰에만 있는 값(hint·hintShownOnKeyboard·콤보·사용 기록)이 조용히 사라진다.
//     그래서 `var updated = memo` 로 시작해 바꾼 칸만 대입한다.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MemoEditView: View {
    let memo: Memo
    /// 저장/취소 후 화면을 닫는 방법 — 시트면 dismiss, 창이면 창 닫기.
    var onFinish: () -> Void

    @State private var title: String
    @State private var textContent: String
    @State private var category: String
    @State private var isFavorite: Bool
    /// 이미 저장돼 있는 이미지 파일명(사용자가 뺄 수 있다).
    @State private var imageFileNames: [String]
    /// 이번에 새로 붙인 이미지(저장할 때 파일로 기록된다).
    @State private var newImages: [NSImage] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    init(memo: Memo, onFinish: @escaping () -> Void) {
        self.memo = memo
        self.onFinish = onFinish
        _title = State(initialValue: memo.title)
        _textContent = State(initialValue: memo.isSecure ? "" : memo.value)
        _category = State(initialValue: MacCategoryName.display(memo.category))
        _isFavorite = State(initialValue: memo.isFavorite)
        var names = memo.imageFileNames
        if let single = memo.imageFileName, !single.isEmpty, !names.contains(single) {
            names.append(single)
        }
        _imageFileNames = State(initialValue: names)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: MacSpacing.xl) {
                    contentSection
                    imageSection
                }
                .padding(MacSpacing.xl)
            }
            Divider()
            footer
        }
        .font(MacFont.body)
        .frame(minWidth: 520, minHeight: 560)
        .overlay(toastOverlay)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: MacSpacing.md) {
            HStack {
                Text(NSLocalizedString("단축어 수정", comment: "Edit memo title"))
                    .font(MacFont.screenTitle)

                Spacer()

                // 즐겨찾기 — 목록 맨 위 고정 여부. 수정 화면에서 바로 바꿀 수 있게 둔다.
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(isFavorite ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("즐겨찾기", comment: "Favorite toggle"))
            }

            TextField(NSLocalizedString("제목", comment: "Title placeholder"), text: $title)
                .textFieldStyle(.roundedBorder)
                .font(MacFont.body)

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
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            Text(NSLocalizedString("내용", comment: "Content section header"))
                .font(MacFont.sectionTitle)

            if memo.isSecure {
                // 보안 단축어의 값은 이 기기에 암호문으로만 있다. 평문으로 열어 되쓰면
                // 복호화 키가 없는 기기에서 값이 깨지므로, 맥에서는 내용을 건드리지 않는다.
                lockedContentNotice
            } else {
                TextEditor(text: $textContent)
                    .font(MacFont.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(MacSpacing.sm)
                    .macSurface()

                if textContent.contains("{") {
                    Text(textContent.templateChipAttributed())
                        .font(MacFont.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MacSpacing.md)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: MacRadius.sm))
                }

                Text(NSLocalizedString("{ }로 감싸면 입력할 때 채우는 칸이 됩니다", comment: "Custom placeholder hint"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }

            if memo.isCombo && !memo.comboValues.isEmpty {
                noticeRow(symbol: "square.stack",
                          text: NSLocalizedString("여러 값이 담긴 단축어입니다. 값 목록은 아이폰에서 바꿀 수 있어요.",
                                                  comment: "Combo memo edit notice"))
            }
        }
    }

    private var lockedContentNotice: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            HStack(spacing: MacSpacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                Text(verbatim: "••••••••")
                    .font(MacFont.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(MacSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .macSurface()

            noticeRow(symbol: AppSymbol.infoCircle,
                      text: NSLocalizedString("보안 단축어의 내용은 아이폰에서만 바꿀 수 있습니다. 여기서는 제목·카테고리만 수정돼요.",
                                              comment: "Secure memo edit notice"))
        }
    }

    private func noticeRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: MacSpacing.xs) {
            Image(systemName: symbol)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(MacFont.secondary)
        .foregroundStyle(.secondary)
    }

    // MARK: - Images

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: MacSpacing.sm) {
            HStack {
                Text(NSLocalizedString("이미지 첨부", comment: "Image attachment section header"))
                    .font(MacFont.sectionTitle)

                Spacer()

                if totalImageCount > 0 {
                    Text(String(format: NSLocalizedString("%d개", comment: "Item count"), totalImageCount))
                        .font(MacFont.secondary)
                        .foregroundStyle(.secondary)
                }
            }

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
                    Label(NSLocalizedString("클립보드에서 붙여넣기", comment: "Paste from clipboard"), systemImage: AppSymbol.docOnClipboard)
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(NSLocalizedString("클립보드에서 붙여넣기", comment: "Paste from clipboard"))
            }

            if totalImageCount > 0 {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                    ForEach(imageFileNames, id: \.self) { name in
                        if let image = MemoStore.shared.loadImage(fileName: name) {
                            ImageAttachmentView(image: image) {
                                imageFileNames.removeAll { $0 == name }
                            }
                        }
                    }
                    ForEach(Array(newImages.enumerated()), id: \.offset) { index, image in
                        ImageAttachmentView(image: image) {
                            guard index < newImages.count else { return }
                            newImages.remove(at: index)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var totalImageCount: Int { imageFileNames.count + newImages.count }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: MacSpacing.md) {
            Spacer()

            Button(NSLocalizedString("취소", comment: "Cancel button")) {
                onFinish()
            }
            .keyboardShortcut(.cancelAction)

            Button(NSLocalizedString("저장", comment: "Save button")) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .controlSize(.large)
        .padding(MacSpacing.lg)
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if memo.isSecure { return true }          // 값은 그대로 두고 제목만 고치는 경우
        return !textContent.isEmpty || totalImageCount > 0
    }

    private var toastOverlay: some View {
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
                if let image = NSImage(contentsOf: url) { newImages.append(image) }
            }
        }
    }

    private func pasteImageFromClipboard() {
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            newImages.append(image)
            showToastMessage(NSLocalizedString("클립보드에서 이미지를 추가했습니다", comment: "Toast: image added from clipboard"))
        } else {
            showToastMessage(NSLocalizedString("클립보드에 이미지가 없습니다", comment: "Toast: no image in clipboard"))
        }
    }

    private func save() {
        var updated = memo
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let typedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.category = typedCategory.isEmpty ? memo.category : MacCategoryName.stored(typedCategory)
        updated.isFavorite = isFavorite

        // 새로 붙인 이미지를 먼저 파일로 남긴다 — 본문보다 늦으면 깨진 참조가 생긴다.
        var names = imageFileNames
        for image in newImages {
            let fileName = "\(UUID().uuidString).png"
            do {
                try MemoStore.shared.saveImage(image, fileName: fileName)
                names.append(fileName)
            } catch {
                print("❌ [MemoEdit] 이미지 저장 실패: \(error)")
                showToastMessage(String(format: NSLocalizedString("저장 실패: %@", comment: "Toast: save failed with reason"), error.localizedDescription))
                return
            }
        }

        if !memo.isSecure {
            updated.value = textContent
            // 템플릿 여부는 **추출된 토큰이 있는지**로 판단한다(아이폰과 같은 규칙).
            let tokens = textContent.extractTemplatePlaceholders()
            updated.templateVariables = tokens
            updated.isTemplate = !tokens.isEmpty
        }

        updated.imageFileNames = names
        // 레거시 단일 필드도 같이 맞춘다 — 이 값만 읽는 화면(이미지 복사)이 아직 있다.
        updated.imageFileName = names.first
        updated.contentType = contentType(hasText: !updated.value.isEmpty, hasImage: !names.isEmpty)
        updated.lastEdited = Date()   // 동기화가 최신본을 고르는 기준

        guard MacMemoActions.update(updated) else {
            showToastMessage(NSLocalizedString("저장 실패: 단축어를 찾을 수 없습니다", comment: "Toast: memo missing on save"))
            return
        }

        // 사용자가 뺀 이미지는 이 단축어만 쓰던 것이면 정리한다.
        cleanUpRemovedImages(keeping: names)
        onFinish()
    }

    private func contentType(hasText: Bool, hasImage: Bool) -> ClipboardContentType {
        if hasText && hasImage { return .mixed }
        if hasImage { return .image }
        return .text
    }

    /// 편집 중 뺀 이미지 파일 정리 — 다른 단축어가 쓰고 있으면 남긴다.
    private func cleanUpRemovedImages(keeping names: [String]) {
        var original = memo.imageFileNames
        if let single = memo.imageFileName, !single.isEmpty, !original.contains(single) {
            original.append(single)
        }
        let removed = Set(original).subtracting(names)
        guard !removed.isEmpty else { return }

        let others = ((try? MemoStore.shared.load(type: .memo)) ?? []).filter { $0.id != memo.id }
        var stillUsed = Set(others.flatMap { $0.imageFileNames })
        for other in others {
            if let single = other.imageFileName, !single.isEmpty { stillUsed.insert(single) }
        }
        for name in removed where !stillUsed.contains(name) {
            try? MemoStore.shared.deleteImage(fileName: name)
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
    }
}

#Preview {
    MemoEditView(memo: Memo(title: "내 이메일", value: "example@email.com")) {}
}
