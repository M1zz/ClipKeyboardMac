//
//  ClipboardMonitorService.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-12-11.
//

import AppKit
import Foundation

class ClipboardMonitorService {
    static let shared = ClipboardMonitorService()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ [ClipboardMonitor] 이미 모니터링 중입니다")
            return
        }

        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        // 1초마다 클립보드 변경 확인
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        print("✅ [ClipboardMonitor] 클립보드 모니터링 시작")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        print("🛑 [ClipboardMonitor] 클립보드 모니터링 중지")
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general

        // 클립보드 변경 확인
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        // 이미지가 있는지 확인
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            print("📸 [ClipboardMonitor] 이미지 감지됨")
            handleImageCopied(image)
            return
        }

        // 텍스트가 있는지 확인
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            print("📝 [ClipboardMonitor] 텍스트 감지됨: \(text.prefix(50))...")
            handleTextCopied(text)
            return
        }
    }

    private func handleTextCopied(_ text: String) {
        do {
            try MemoStore.shared.addToClipboardHistory(content: text)
            print("✅ [ClipboardMonitor] 텍스트 히스토리에 저장됨")
        } catch {
            print("❌ [ClipboardMonitor] 텍스트 저장 실패: \(error)")
        }
    }

    private func handleImageCopied(_ image: NSImage) {
        do {
            try MemoStore.shared.addImageToClipboardHistory(image: image)
            print("✅ [ClipboardMonitor] 이미지 히스토리에 저장됨")
        } catch {
            print("❌ [ClipboardMonitor] 이미지 저장 실패: \(error)")
        }
    }
}
