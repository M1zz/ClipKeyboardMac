//
//  AppLog.swift
//  ClipKeyboard
//
//  구조적 로깅 — `print` 대신 OSLog로 남긴다.
//
//  왜 바꾸나: `print` 는 Xcode 콘솔에만 뜨고 **사용자 기기에는 아무것도 안 남는다.**
//  "동기화가 가끔 실패한다"는 제보를 받아도 재현 전까지 손을 못 댄다.
//  OSLog 는 `.error` 이상이 시스템 로그에 보존돼 sysdiagnose 로 사후 추적이 된다.
//
//  ⚠️ 이모지 컨벤션(📁 ✅ ❌ 🔄 ⚠️)은 그대로 유지한다 — CLAUDE.md 의 디버깅 팁
//     (`grep "📁 \[MemoStore"`)이 계속 동작해야 한다.
//
//  ⚠️ 메시지를 `String` 으로 받아 `privacy: .public` 으로 남긴다.
//     이유: Logger 의 문자열 보간은 동적 값을 기본적으로 `<private>` 로 가려서,
//     그대로 두면 정작 필요한 개수·에러 사유가 로그에서 안 보인다.
//     대신 **PII를 절대 넘기지 말 것** — 메모 내용·이메일은 로그에 넣지 않는다.
//     (넘기는 값은 개수·상태·에러 설명뿐이라는 전제)
//
//  ⚠️ 대가: String 이 항상 만들어진다(OSLog 의 지연 포매팅을 못 쓴다).
//     이 앱의 로그 빈도(런치·저장·동기화 시점)에서는 문제되지 않는 수준이다.
//

import Foundation
import os

enum AppLog {

    /// 로그 분류 — Console.app 에서 category 로 필터할 수 있다.
    enum Category: String {
        case store = "MemoStore"
        case backup = "Backup"
        case sync = "MemoSync"
        case usage = "Usage"
        case diagnostics = "Diagnostics"
        case flags = "RemoteFlags"
        case wipe = "DataWipe"
    }

    private static let subsystem = "com.Ysoup.TokenMemo"

    private static func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// 정상 흐름 기록. 시스템 로그에 오래 남지 않는다(개발 중 확인용).
    static func info(_ category: Category, _ message: String) {
        logger(category).info("\(message, privacy: .public)")
    }

    /// 이상하지만 계속 진행 가능한 상황. 사후 추적 대상.
    static func warning(_ category: Category, _ message: String) {
        logger(category).warning("\(message, privacy: .public)")
    }

    /// 실패. **여기 남긴 것만 사용자 기기에서 나중에 확인할 수 있다.**
    static func error(_ category: Category, _ message: String) {
        logger(category).error("\(message, privacy: .public)")
    }
}
