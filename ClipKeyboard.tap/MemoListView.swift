//
//  MemoListView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

struct MemoListView: View {
    @State private var memos: [Memo] = []
    @State private var searchText: String = ""
    /// 선택된 카테고리 탭. 첫 탭은 구성에 따라 다르다(아이폰 구성=기본 / 예전 구성=전체).
    @State private var selectedTab: CategoryTab = .all
    /// 아이폰 구성을 따를지 — 기존 사용자에겐 배너로 묻고, 승낙 전까진 예전 구성을 유지한다.
    @ObservedObject private var tabPreference = MacCategoryTabPreference.shared
    @State private var isViewActive: Bool = true
    /// 커스텀 플레이스홀더 값 채우기 시트 대상 메모.
    @State private var fillMemo: Memo?
    /// 여러 값(콤보) 중 하나를 골라 복사하는 시트 대상 메모.
    @State private var comboPickMemo: Memo?
    /// 수정 시트 대상 메모.
    @State private var editMemo: Memo?
    /// 삭제 확인을 기다리는 메모 — 확인 없이 지우면 되돌릴 방법이 없다(휴지통이 없다).
    @State private var deleteCandidate: Memo?
    /// 중복 정리 확인 시트 표시 여부.
    @State private var showDuplicateCleanup: Bool = false

    /// 아이폰에서 넘어온 카테고리 설정(순서·아이콘·숨김).
    /// `MemoSyncEngine` 이 `CategorySettings` 레코드를 받아 App Group 에 적용하고,
    /// 여기서 다시 읽어 탭에 반영한다 — 그래야 "아이폰과 같은 탭 구성"이 된다.
    @State private var categorySettings: CategorySnapshot = CategorySnapshotStore.current()

    /// 탭 목록 — 아이폰 구성을 따르기로 했으면 아이폰 그대로, 아니면 4.4.6 까지의 구성.
    /// 비어 있으면(카테고리 기능 꺼짐) 탭 없이 전체 한 장.
    var tabs: [CategoryTab] {
        MacCategoryTabs.tabs(memos: memos,
                             snapshot: categorySettings,
                             followsPhone: tabPreference.followsPhone)
    }

    private var isFreeUser: Bool { !MacProManager.isPro }
    private var hiddenMemoCount: Int {
        guard isFreeUser else { return 0 }
        return max(0, memos.count - MacProManager.freeMemoLimit)
    }

    var filteredMemos: [Memo] {
        // 사용자가 지정한 수동 순서(있으면) → 없으면 즐겨찾기 먼저, 최근순. iOS와 순서 공유.
        var filtered = MacMemoOrder.sorted(memos)

        // 무료 유저: 표시 한도 적용 (정렬 후 상위 N개만)
        if isFreeUser {
            filtered = Array(filtered.prefix(MacProManager.freeMemoLimit))
        }

        // 카테고리 탭 — 탭이 없으면(기능 꺼짐) 필터도 없다.
        if !tabs.isEmpty {
            filtered = MacCategoryTabs.memos(filtered, for: selectedTab, in: categorySettings)
        }

        // 검색 필터 — 보안 메모는 제목으로만(값은 암호문이라 검색 제외).
        if !searchText.isEmpty {
            filtered = filtered.filter {
                if $0.title.localizedCaseInsensitiveContains(searchText) { return true }
                if $0.isSecure { return false }
                return $0.value.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    /// 드래그 순서 변경 가능 여부 — 검색 중일 땐 결과 순서를 흐트러뜨리지 않도록 잠근다.
    private var canReorder: Bool { searchText.isEmpty }

    /// onMove 핸들러 — MainActor 격리 메서드(moveMemos)와 타입을 일치시키려 @MainActor로 명시.
    /// 삼항(메서드 참조 vs nil) 공통타입 추론 실패를 막는다.
    private var reorderHandler: (@MainActor (IndexSet, Int) -> Void)? {
        if canReorder {
            return moveMemos
        } else {
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            if tabPreference.needsAsk {
                MacCategoryAdoptBanner(preference: tabPreference)
                Divider()
            }
            lockedBanner
            listSection
        }
        .frame(minWidth: 360, minHeight: 420)
        .sheet(item: $fillMemo) { memo in
            MacTemplateFillSheet(memo: memo) { resolved, paste in
                copyToClipboard(resolved)
                if paste {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        DirectPasteHelper.pasteToFrontmostApp()
                    }
                }
            }
        }
        .sheet(item: $comboPickMemo) { memo in
            MacComboValuePicker(memo: memo) { value in
                copyToClipboard(value)
            }
        }
        .sheet(item: $editMemo) { memo in
            MemoEditView(memo: memo) {
                editMemo = nil
                loadMemos()
            }
        }
        .alert(
            NSLocalizedString("이 단축어를 삭제할까요?", comment: "Delete confirm title"),
            isPresented: Binding(get: { deleteCandidate != nil },
                                 set: { if !$0 { deleteCandidate = nil } }),
            presenting: deleteCandidate
        ) { memo in
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) {
                MacMemoActions.delete(memo)
                loadMemos()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) {}
        } message: { memo in
            Text(String(format: NSLocalizedString("'%@'이(가) 이 맥과 동기화된 기기에서 사라집니다.",
                                                  comment: "Delete confirm message"), memo.title))
        }
        .confirmationDialog(
            NSLocalizedString("중복된 단축어를 정리할까요?", comment: "Dedupe confirm title"),
            isPresented: $showDuplicateCleanup,
            titleVisibility: .visible
        ) {
            Button(String(format: NSLocalizedString("%d개 삭제", comment: "Dedupe delete button"), duplicateExtraCount),
                   role: .destructive) {
                let removed = MacMemoActions.removeDuplicates()
                print("🧹 [MemoListView] 중복 \(removed)개 정리")
                loadMemos()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("제목과 내용이 똑같은 단축어를 하나만 남기고 지웁니다. 즐겨찾기·많이 쓴 단축어가 남습니다.",
                                   comment: "Dedupe confirm message"))
        }
        .onAppear {
            print("✅ [MemoListView] onAppear - 뷰 활성화")
            isViewActive = true
            loadMemos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataRestored)) { _ in
            // iCloud 자동/수동 복원 직후 목록 갱신.
            loadMemos()
        }
        .onChange(of: tabPreference.followsPhone) { _ in
            // 배너·환경설정에서 구성을 바꾸면 탭 목록이 통째로 달라진다 — 첫 탭으로 옮긴다.
            selectedTab = tabs.first ?? .all
        }
        .onDisappear {
            print("⚠️ [MemoListView] onDisappear - 뷰 비활성화 시작")
            isViewActive = false
            print("✅ [MemoListView] onDisappear - 뷰 비활성화 완료")
        }
    }

    // MARK: - Sections (타입체커 부하 분산 — body를 작은 서브뷰로 분리)

    /// 컴팩트 헤더 (타이틀·개수·카테고리 Picker + 검색 바)
    private var headerSection: some View {
        VStack(spacing: MacSpacing.sm) {
            HStack(spacing: MacSpacing.sm) {
                Text(NSLocalizedString("단축어", comment: "Snippets section header"))
                    .font(MacFont.sectionTitle)

                Text("\(filteredMemos.count)")
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)

                Spacer()

                duplicateCleanupButton
                categoryPicker
            }

            searchBar
        }
        .padding(MacSpacing.md)
    }

    /// 중복 정리 버튼 — 똑같은 단축어가 두 벌 이상 있을 때만 나타난다.
    /// 동기화가 어긋나 같은 단축어가 쌓였을 때 한 번에 걷어내는 길.
    @ViewBuilder
    private var duplicateCleanupButton: some View {
        if duplicateExtraCount > 0 {
            Button {
                showDuplicateCleanup = true
            } label: {
                Label(String(format: NSLocalizedString("중복 %d개", comment: "Duplicate count badge"), duplicateExtraCount),
                      systemImage: "wand.and.sparkles")
                    .font(MacFont.secondary)
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("똑같은 단축어를 하나만 남기고 정리합니다", comment: "Dedupe button help"))
        }
    }

    /// 지울 수 있는 중복 개수(묶음마다 하나는 남긴다).
    private var duplicateExtraCount: Int {
        MacMemoActions.duplicateGroups(in: memos).reduce(0) { $0 + $1.count - 1 }
    }

    /// 카테고리 선택 Picker — 탭 구성·이름·아이콘 모두 아이폰과 같다.
    @ViewBuilder
    private var categoryPicker: some View {
        if !tabs.isEmpty {
            Picker("", selection: $selectedTab) {
                ForEach(tabs, id: \.self) { tab in
                    Label(MacCategoryName.display(tab.displayName), systemImage: tab.icon).tag(tab)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
    }

    /// 컴팩트 검색 바
    private var searchBar: some View {
        HStack(spacing: MacSpacing.sm) {
            Image(systemName: AppSymbol.magnifyingglass)
                .foregroundStyle(.secondary)

            TextField(NSLocalizedString("검색", comment: "Search placeholder"), text: $searchText)
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
        .font(MacFont.body)
        .padding(.horizontal, MacSpacing.sm)
        .padding(.vertical, MacSpacing.xs + 2)
        .macSurface(MacRadius.xs)
    }

    /// 무료 유저: 숨겨진 메모 잠금 배너 (조건 미충족 시 빈 뷰)
    @ViewBuilder
    private var lockedBanner: some View {
        if isFreeUser && hiddenMemoCount > 0 {
            HStack(spacing: MacSpacing.sm) {
                Image(systemName: AppSymbol.lockFill)
                Text(String(format: NSLocalizedString("%d개 단축어 잠김 — iOS에서 Pro 구매 시 동기화됩니다", comment: "Locked memos banner"), hiddenMemoCount))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(MacFont.body)
            .foregroundStyle(.orange)
            .padding(.horizontal, MacSpacing.md)
            .padding(.vertical, MacSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
        }
    }

    /// 메모 리스트 (비었으면 빈 상태, 아니면 List + 순서변경 안내)
    @ViewBuilder
    private var listSection: some View {
        if filteredMemos.isEmpty {
            CompactEmptyListView
        } else {
            List {
                ForEach(filteredMemos) { memo in
                    CompactMemoItemRow(
                        memo: memo,
                        onCopy: { handleMemoTap(memo) },
                        onEdit: { editMemo = memo },
                        onDelete: { deleteCandidate = memo },
                        onToggleFavorite: {
                            MacMemoActions.toggleFavorite(memo)
                            loadMemos()
                        }
                    )
                }
                // 드래그로 순서 변경 — 지정한 순서는 App Group을 통해 iOS·키보드와 공유된다.
                .onMove(perform: reorderHandler)
            }
            .listStyle(.plain)

            // 순서 변경 안내 — 검색 중이 아닐 때만.
            if canReorder && filteredMemos.count > 1 {
                HStack(spacing: MacSpacing.xs) {
                    Image(systemName: AppSymbol.arrowUpAndDownAndArrowLeftAndRight)
                    Text(NSLocalizedString("드래그하여 순서를 바꿀 수 있어요", comment: "Mac reorder hint"))
                }
                .font(MacFont.secondary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MacSpacing.sm)
            }
        }
    }

    /// 메모 탭 시 동작 — 이미지/보안/플레이스홀더/일반 분기.
    private func handleMemoTap(_ memo: Memo) {
        if memo.contentType == .image {
            copyImageToClipboard(memo)
        } else if memo.isSecure {
            // 보안 메모: Touch ID 인증 + 복호화 후 복사
            MacSecureAccess.resolveForPaste(memo) { resolved in
                if let resolved { copyToClipboard(resolved) }
            }
        } else if memo.isCombo && !memo.comboValues.isEmpty {
            // 여러 값(콤보) — 값 하나를 골라 복사하는 시트.
            comboPickMemo = memo
        } else if memo.hasCustomPlaceholders {
            fillMemo = memo
        } else {
            copyToClipboard(memo.resolvedForPaste())
        }
    }

    // MARK: - Empty View

    private var CompactEmptyListView: some View {
        VStack(spacing: MacSpacing.md) {
            Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: MacIcon.hero))
                .foregroundStyle(.tertiary)

            Text(searchText.isEmpty ? NSLocalizedString("단축어 없음", comment: "No memos") : NSLocalizedString("검색 결과 없음", comment: "No search results"))
                .font(MacFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    /// 드래그로 바뀐 순서를 App Group에 저장한다. 현재 보이는(카테고리/한도 적용된) 목록만
    /// 재정렬하고, 전체 순서에서 그 항목들의 슬롯만 치환한다 — iOS 순서 바꾸기와 동일 규칙.
    private func moveMemos(from source: IndexSet, to destination: Int) {
        var visible = filteredMemos
        visible.move(fromOffsets: source, toOffset: destination)
        MacMemoOrder.commit(reordered: visible, within: memos)
        // 저장된 수동 순서를 반영해 목록을 다시 로드(다음 filteredMemos가 새 순서로 정렬됨).
        loadMemos()
    }

    private func loadMemos() {
        print("📂 [MemoListView] loadMemos - 메모 로드 시작")
        // 메모와 카테고리 설정은 같은 동기화(.dataRestored)로 함께 갱신된다 —
        // 따로 읽으면 새 탭의 메모는 왔는데 탭 순서·아이콘은 옛것인 상태가 생긴다.
        categorySettings = CategorySnapshotStore.current()
        do {
            memos = try MemoStore.shared.load(type: .memo)
            print("✅ [MemoListView] loadMemos - \(memos.count)개 메모 로드 완료")
        } catch {
            print("❌ [MemoListView] loadMemos - 메모 로드 실패: \(error)")
        }

        // 기존 사용자에게 "아이폰 구성으로 맞출까요?"를 물어봐야 하는 상황인지 판단한다.
        tabPreference.evaluate(memos: memos, snapshot: categorySettings)

        // 구성이 바뀌거나(승낙) 아이폰에서 카테고리를 숨기면 보고 있던 탭이 사라진다 —
        // 그 자리에 서 있는 첫 탭으로 되돌린다(빈 화면에 갇히지 않게).
        let available = tabs
        if !available.isEmpty && !available.contains(selectedTab) {
            selectedTab = available[0]
        }
    }

    private func copyToClipboard(_ text: String) {
        print("📋 [MemoListView] copyToClipboard - 클립보드 복사 시작")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("✅ [MemoListView] copyToClipboard - 클립보드 복사 완료")
    }

    private func copyImageToClipboard(_ memo: Memo) {
        guard let imageFileName = memo.imageFileName,
              let image = MemoStore.shared.loadImage(fileName: imageFileName) else {
            print("❌ [MemoListView] 이미지 로드 실패")
            return
        }

        print("📸 [MemoListView] copyImageToClipboard - 이미지 클립보드 복사 시작")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        print("✅ [MemoListView] copyImageToClipboard - 이미지 클립보드 복사 완료")
    }
}

// MARK: - Compact Memo Item Row

// MARK: - Combo Value Picker (여러 값 중 하나 골라 복사)

/// 콤보(여러 값) 메모 탭 시 뜨는 값 선택 시트 — 값 하나를 눌러 복사한다.
private struct MacComboValuePicker: View {
    let memo: Memo
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var values: [String] {
        memo.comboValues.isEmpty ? [memo.value] : memo.comboValues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacSpacing.md) {
            VStack(alignment: .leading, spacing: MacSpacing.xs) {
                Text(memo.title)
                    .font(MacFont.sectionTitle)
                    .lineLimit(1)
                Text(NSLocalizedString("값을 눌러 복사하세요", comment: "Combo preview: tap a value to copy"))
                    .font(MacFont.secondary)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: MacSpacing.sm) {
                    ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                        Button {
                            onPick(value)
                            dismiss()
                        } label: {
                            HStack(spacing: MacSpacing.md) {
                                Text("\(idx + 1)")
                                    .font(MacFont.mono)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(value.isEmpty ? "—" : value)
                                    .font(MacFont.body)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(MacSpacing.md)
                            .macSurface()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(value.isEmpty)
                    }
                }
            }
        }
        .padding(MacSpacing.xl)
        .frame(width: 380, height: 400)
    }
}

struct CompactMemoItemRow: View {
    let memo: Memo
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: MacSpacing.xs) {
            copyButton
            // 수정·삭제는 복사 버튼 **바깥**에 둔다 — 버튼 안에 버튼을 넣으면
            // macOS 에서 바깥 버튼이 클릭을 먼저 먹어 눌리지 않는다.
            if isHovering {
                rowActions
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(NSLocalizedString("복사", comment: "Context: copy")) { onCopy() }
            Button(NSLocalizedString("수정…", comment: "Context: edit")) { onEdit() }
            Button(memo.isFavorite
                   ? NSLocalizedString("즐겨찾기 해제", comment: "Context: unfavorite")
                   : NSLocalizedString("즐겨찾기", comment: "Favorite toggle")) { onToggleFavorite() }
            Divider()
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) { onDelete() }
        }
    }

    /// 수정·삭제 버튼 — 마우스를 올렸을 때만 나타나 평소 목록을 조용하게 둔다.
    private var rowActions: some View {
        HStack(spacing: MacSpacing.xs) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(MacFont.body)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("수정…", comment: "Context: edit"))
            .accessibilityLabel(NSLocalizedString("수정…", comment: "Context: edit"))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(MacFont.body)
                    .foregroundStyle(.red)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("삭제", comment: "Delete button"))
            .accessibilityLabel(NSLocalizedString("삭제", comment: "Delete button"))
        }
        .padding(.trailing, MacSpacing.xs)
    }

    private var copyButton: some View {
        // Button(.plain)으로 감싸야 macOS List의 드래그 순서변경(.onMove)과 클릭-복사가
        // 공존한다. .onTapGesture 는 List의 reorder 드래그 제스처를 가로채 드래그가 안 먹는다.
        Button(action: onCopy) {
        HStack(spacing: MacSpacing.md) {
            // 아이콘 — 즐겨찾기만 색으로 강조하고 나머지는 무채색으로 통일.
            Image(systemName: memo.contentType == .image ? "photo" :
                  memo.isFavorite ? "star.fill" :
                  memo.isSecure ? "lock.fill" : "doc.text")
                .foregroundStyle(memo.isFavorite ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                .font(MacFont.body)
                .frame(width: MacIcon.glyph)

            // 콘텐츠
            VStack(alignment: .leading, spacing: MacSpacing.xs / 2) {
                HStack(spacing: MacSpacing.xs) {
                    Text(memo.title)
                        .font(MacFont.rowTitle)
                        .lineLimit(1)

                    Spacer()

                    if isHovering {
                        Image(systemName: memo.contentType == .image ? "photo" : "doc.on.doc")
                            .font(MacFont.body)
                            .foregroundStyle(.tint)
                    }
                }

                if memo.contentType == .image || memo.contentType == .mixed {
                    // 이미지 미리보기
                    let imageFileNames = memo.imageFileNames.isEmpty && memo.imageFileName != nil
                        ? [memo.imageFileName!]
                        : memo.imageFileNames

                    if !imageFileNames.isEmpty {
                        HStack(spacing: MacSpacing.xs) {
                            ForEach(Array(imageFileNames.prefix(3).enumerated()), id: \.offset) { _, fileName in
                                if let image = MemoStore.shared.loadImage(fileName: fileName) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipped()
                                        .cornerRadius(MacRadius.xs)
                                }
                            }

                            if imageFileNames.count > 3 {
                                Text("+\(imageFileNames.count - 3)")
                                    .font(MacFont.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memo.contentType == .mixed && !memo.value.isEmpty {
                        Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                            .font(MacFont.secondary)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                        .font(MacFont.secondary)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, MacSpacing.sm)
        .padding(.horizontal, MacSpacing.sm)
        .background(isHovering ? MacColor.hover : Color.clear)
        .cornerRadius(MacRadius.xs)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }
}

#Preview {
    MemoListView()
}
