//
//  MacDefaultsKey.swift
//  ClipKeyboard.tap
//
//  맥 전용 UserDefaults 키.
//
//  ⚠️ 공유 파일인 `Shared/DefaultsKey.swift` 는 iOS 원본과 **바이트 단위로 같아야** 한다
//     (scripts/check_shared_drift.sh 가 배포를 막는다). 맥에만 있는 키를 거기 끼워 넣으면
//     다음 동기화 때 조용히 지워지고, 그 사이엔 드리프트로 배포가 막힌다.
//     → 맥에만 필요한 키는 여기에 확장으로 둔다.
//

import Foundation

// ⚠️ 지금은 비어 있다. `hasCompletedOnboarding` 이 여기 있었는데, 아이폰 쪽
//    `DefaultsKey` 가 같은 이름을 갖게 되면서 공유 파일과 **이름이 겹쳐 빌드가 깨졌다.**
//    같은 값을 두 곳에 적어 둘 이유가 없어 공유 파일 쪽을 남겼다.
//
//    맥에만 필요한 키가 생기면 아래에 확장으로 다시 열 것. 그때 아이폰 쪽에 같은 이름이
//    없는지 먼저 볼 것 - 공유 파일은 iOS 를 원본으로 통째로 덮어써진다
//    (`scripts/sync_shared.sh`).
