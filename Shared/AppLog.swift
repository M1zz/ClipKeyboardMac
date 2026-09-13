//
//  AppLog.swift
//  ClipKeyboard
//
//  구조적 로깅 - `print` 대신 OSLog로 남긴다.
//
//  왜 바꾸나: `print` 는 Xcode 콘솔에만 뜨고 **사용자 기기에는 아무것도 안 남는다.**
//  "동기화가 가끔 실패한다"는 제보를 받아도 재현 전까지 손을 못 댄다.
//  OSLog 는 `.error` 이상이 시스템 로그에 보존돼 sysdiagnose 로 사후 추적이 된다.
//
//  ⚠️ 이모지 컨벤션(📁 ✅ ❌ 🔄 ⚠️)은 그대로 유지한다 - CLAUDE.md 의 디버깅 팁
//     (`grep "📁 \[MemoStore"`)이 계속 동작해야 한다.
//
//  ⚠️ 메시지를 `String` 으로 받아 `privacy: .public` 으로 남긴다.
//     이유: Logger 의 문자열 보간은 동적 값을 기본적으로 `<private>` 로 가려서,
//     그대로 두면 정작 필요한 개수·에러 사유가 로그에서 안 보인다.
//     대신 **PII를 절대 넘기지 말 것** - 메모 내용·이메일은 로그에 넣지 않는다.
//     (넘기는 값은 개수·상태·에러 설명뿐이라는 전제)
//
//  ⚠️ 대가: String 이 항상 만들어진다(OSLog 의 지연 포매팅을 못 쓴다).
//     이 앱의 로그 빈도(런치·저장·동기화 시점)에서는 문제되지 않는 수준이다.
//

import Foundation
import os

enum AppLog {

    /// 로그 분류 - Console.app 에서 category 로 필터할 수 있다.
    enum Category: String {
        case store = "MemoStore"
        case backup = "Backup"
        case sync = "MemoSync"
        case usage = "Usage"
        case diagnostics = "Diagnostics"
        case flags = "RemoteFlags"
        case wipe = "DataWipe"
        case launch = "Launch"
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

// MARK: - Release 에서 사라지는 print

/// 모듈 안의 `print` 를 가로채는 셤.
///
/// 왜 필요한가: 이 저장소에는 `print` 가 400개 넘게 있고 전부 릴리즈 빌드에 그대로
/// 실려 나갔다. `print` 는 stdout 으로 쓰는 **동기 호출**이라, 부르는 자리가
/// 메인 스레드면 그만큼 메인 스레드가 멈춘다. 특히 `applyFilters()` 는 한 번에
/// 네 줄을 찍는데 검색어를 칠 때마다 불리고, 키보드 익스텐션에도 49개가 있다.
/// 익스텐션은 시간·메모리 제약이 가장 빡빡한 곳이다.
///
/// 왜 이 방식인가: 모듈 최상위에 같은 이름·같은 시그니처로 선언하면 `Swift.print`
/// 대신 이것이 잡힌다. 호출부 400여 곳을 건드리지 않아도 되고, 새로 쓰는 `print`
/// 도 저절로 걸린다. `AppLog.swift` 는 앱과 키보드 익스텐션 **두 타겟 모두**에
/// 들어 있으므로 한 벌로 양쪽이 덮인다.
///
/// ⚠️ 인자 **식** 자체는 릴리즈에서도 계산된다(가변 인자라 `@autoclosure` 를 못 쓴다).
///    문자열 보간이 무거운 자리라면 `#if DEBUG` 로 직접 감쌀 것.
///
/// ⚠️ 사용자 기기에 남겨야 하는 기록은 `print` 가 아니라 `AppLog.error` 로 남긴다.
///    릴리즈에서 `print` 는 아무 데도 안 남는다.
@inlinable
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
    #endif
}
