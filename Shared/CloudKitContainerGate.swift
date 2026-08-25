//
//  CloudKitContainerGate.swift
//  ClipKeyboard
//
//  `CKContainer(identifier:)` 를 부르는 유일한 자리.
//

import Foundation
import CloudKit

/// CloudKit 컨테이너를 **메인 스레드 밖에서** 만들어 돌려주는 관문.
///
/// 왜 관문이 필요한가:
/// `CKContainer(identifier:)` 는 값 하나 만드는 생성자처럼 보이지만, 실제로는 cloudd 와
/// XPC 를 주고받는다. 그 데몬이 대답하지 않으면 부른 스레드가 그 자리에서 멈춘다.
/// 잡을 수 있는 오류가 나는 것도 아니고, 그냥 돌아오지 않는다.
///
/// 4.4.6 에서 이 한 줄이 첫 화면을 그리던 메인 스레드를 22초 붙잡았고, iOS 가 앱을
/// 워치독으로 죽였다(`0x8BADF00D`, `scene-create`). 그 런치에서 앱이 쓴 CPU 는 0.135초다.
/// 느려서 죽은 게 아니라 기다리다 죽었다. 기록: `docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md`
///
/// ⚠️ **`CKContainer(identifier:)` 를 다른 곳에서 직접 부르지 않는다.** 여기를 거친다.
///    액터 안에서 만들기 때문에, `@MainActor` 코드가 불러도 생성은 메인 스레드가 아닌
///    협력 스레드풀에서 일어난다. 부른 쪽은 `await` 로 비켜 서 있을 뿐 붙잡히지 않는다.
///    (`scripts/check_main_thread_cloudkit.sh` 가 이 규칙을 지킨다)
enum CloudKitContainer {

    /// 만든 컨테이너를 identifier 별로 한 개씩만 들고 있는 곳.
    ///
    /// **액터인 것이 이 파일의 요점이다.** 액터의 몸통은 협력 스레드풀에서 돌므로
    /// 여기 적힌 `CKContainer(identifier:)` 는 메인 스레드에서 실행될 수 없다.
    /// 덤으로 직렬화가 따라와, 여러 곳이 동시에 물어봐도 컨테이너는 한 번만 만들어진다.
    private actor Cache {
        static let shared = Cache()

        private var made: [String: CKContainer] = [:]

        func container(for identifier: String) -> CKContainer {
            if let existing = made[identifier] { return existing }
            let container = CKContainer(identifier: identifier)
            made[identifier] = container
            return container
        }

        func privateDatabase(for identifier: String) -> CKDatabase {
            container(for: identifier).privateCloudDatabase
        }

        func publicDatabase(for identifier: String) -> CKDatabase {
            container(for: identifier).publicCloudDatabase
        }
    }

    /// 컨테이너를 얻는다. 처음 한 번은 만드느라 오래 걸릴 수 있고, 그동안 부른 쪽은
    /// 기다리되 스레드를 붙잡지는 않는다.
    static func resolve(_ identifier: String) async -> CKContainer {
        await Cache.shared.container(for: identifier)
    }

    /// 컨테이너의 private DB. 데이터베이스를 꺼내는 일까지 액터 안에서 끝낸다.
    static func privateDatabase(_ identifier: String) async -> CKDatabase {
        await Cache.shared.privateDatabase(for: identifier)
    }

    /// 컨테이너의 public DB.
    static func publicDatabase(_ identifier: String) async -> CKDatabase {
        await Cache.shared.publicDatabase(for: identifier)
    }
}
