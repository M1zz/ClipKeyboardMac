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
    @State private var selectedCategory: String = "전체"
    @State private var isViewActive: Bool = true
    /// 커스텀 플레이스홀더 값 채우기 시트 대상 메모.
    @State private var fillMemo: Memo?

    var categories: [String] {
        var cats = Set(memos.map { $0.category })
        cats.insert("전체")
        return Array(cats).sorted()
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

        // 카테고리 필터
        if selectedCategory != "전체" {
            filtered = filtered.filter { $0.category == selectedCategory }
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
        .onAppear {
            print("✅ [MemoListView] onAppear - 뷰 활성화")
            isViewActive = true
            loadMemos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataRestored)) { _ in
            // iCloud 자동/수동 복원 직후 목록 갱신.
            loadMemos()
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
        VStack(spacing: 6) {
            HStack {
                Image(systemName: AppSymbol.docOnClipboardFill)
                    .font(.system(.body))
                    .foregroundStyle(.blue)

                Text(NSLocalizedString("단축어", comment: "Snippets section header"))
                    .font(.headline)
                    .bold()

                Spacer()

                Text("\(filteredMemos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                categoryPicker
            }

            searchBar
        }
        .padding(8)
    }

    /// 카테고리 선택 Picker
    private var categoryPicker: some View {
        Picker("", selection: $selectedCategory) {
            ForEach(categories, id: \.self) { category in
                categoryLabel(category).tag(category)
            }
        }
        .frame(width: 80)
        .controlSize(.small)
    }

    /// Picker 항목 라벨 — 중첩 삼항/옵셔널 체인을 헬퍼로 분리해 타입체커 부담을 낮춘다.
    private func categoryLabel(_ category: String) -> Text {
        if category == "전체" {
            return Text(NSLocalizedString("전체", comment: "All categories"))
        }
        let localized = ClipboardItemType(rawValue: category)?.localizedName ?? category
        return Text(localized)
    }

    /// 컴팩트 검색 바
    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: AppSymbol.magnifyingglass)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(NSLocalizedString("검색", comment: "Search placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: AppSymbol.xmarkCircleFill)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(MacRadius.xs)
    }

    /// 무료 유저: 숨겨진 메모 잠금 배너 (조건 미충족 시 빈 뷰)
    @ViewBuilder
    private var lockedBanner: some View {
        if isFreeUser && hiddenMemoCount > 0 {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.lockFill)
                    .font(.system(.caption))
                Text(String(format: NSLocalizedString("%d개 단축어 잠김 — iOS에서 Pro 구매 시 동기화됩니다", comment: "Locked memos banner"), hiddenMemoCount))
                    .font(.system(.caption))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.85))
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
                    CompactMemoItemRow(memo: memo) {
                        handleMemoTap(memo)
                    }
                }
                // 드래그로 순서 변경 — 지정한 순서는 App Group을 통해 iOS·키보드와 공유된다.
                .onMove(perform: reorderHandler)
            }
            .listStyle(.plain)

            // 순서 변경 안내 — 검색 중이 아닐 때만.
            if canReorder && filteredMemos.count > 1 {
                HStack(spacing: 4) {
                    Image(systemName: AppSymbol.arrowUpAndDownAndArrowLeftAndRight)
                    Text(NSLocalizedString("드래그하여 순서를 바꿀 수 있어요", comment: "Mac reorder hint"))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
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
        } else if memo.hasCustomPlaceholders {
            fillMemo = memo
        } else {
            copyToClipboard(memo.resolvedForPaste())
        }
    }

    // MARK: - Empty View

    private var CompactEmptyListView: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? NSLocalizedString("단축어 없음", comment: "No memos") : NSLocalizedString("검색 결과 없음", comment: "No search results"))
                .font(.caption)
                .bold()
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
        do {
            memos = try MemoStore.shared.load(type: .memo)
            print("✅ [MemoListView] loadMemos - \(memos.count)개 메모 로드 완료")
        } catch {
            print("❌ [MemoListView] loadMemos - 메모 로드 실패: \(error)")
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

struct CompactMemoItemRow: View {
    let memo: Memo
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        // Button(.plain)으로 감싸야 macOS List의 드래그 순서변경(.onMove)과 클릭-복사가
        // 공존한다. .onTapGesture 는 List의 reorder 드래그 제스처를 가로채 드래그가 안 먹는다.
        Button(action: onCopy) {
        HStack(spacing: 6) {
            // 아이콘
            Image(systemName: memo.contentType == .image ? "photo" :
                  memo.isFavorite ? "star.fill" :
                  memo.isSecure ? "lock.fill" : "doc.text")
                .foregroundStyle(memo.contentType == .image ? .purple :
                                memo.isFavorite ? .yellow : .blue)
                .font(.caption)
                .frame(width: 16)

            // 콘텐츠
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(memo.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    if isHovering {
                        Image(systemName: memo.contentType == .image ? "photo" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                if memo.contentType == .image || memo.contentType == .mixed {
                    // 이미지 미리보기
                    let imageFileNames = memo.imageFileNames.isEmpty && memo.imageFileName != nil
                        ? [memo.imageFileName!]
                        : memo.imageFileNames

                    if !imageFileNames.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(imageFileNames.prefix(3).enumerated()), id: \.offset) { _, fileName in
                                if let image = MemoStore.shared.loadImage(fileName: fileName) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 30, height: 30)
                                        .clipped()
                                        .cornerRadius(MacRadius.xs)
                                }
                            }

                            if imageFileNames.count > 3 {
                                Text("+\(imageFileNames.count - 3)")
                                    .font(.system(.caption2))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memo.contentType == .mixed && !memo.value.isEmpty {
                        Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                            .font(.system(.caption))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                        .font(.system(.caption))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(MacRadius.xs)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }
}

#Preview {
    MemoListView()
}
