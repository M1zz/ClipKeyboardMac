//
//  SampleMemoStorage.swift
//  ClipKeyboard.tap
//
//  시드 샘플 메모의 id 를 기억한다 — "이건 사용자가 만든 게 아니다"를 판별하기 위해서.
//
//  왜 필요한가: 샘플은 기기 언어에 맞춰(`isKorean`) **매번 새 UUID 로** 심긴다.
//  동기화는 UUID 로 동일성을 보므로, 표식이 없으면 맥의 샘플과 아이폰의 샘플을
//  서로 다른 사용자 메모로 취급해 양쪽에 퍼뜨린다.
//  → 영어 맥 + 한국어 아이폰을 함께 쓰면 "모르는 단축어가 섞여" 보인다.
//
//  ⚠️ iOS 앱에도 같은 이름·같은 키의 저장소가 있다(ClipKeyboard/Tips.swift).
//     각 기기가 **자기 샘플만** 기억하면 되므로 App Group 이 아닌 standard 를 쓴다.
//

import Foundation

enum SampleMemoStorage {
    private static let key = DefaultsKey.sampleMemoIdsV1

    /// 표준 UserDefaults 에 적던 시절의 자리. 옮겨 오기 위해서만 읽는다.
    private static let legacyKey = "sampleMemoUUIDs_v1"

    static func save(ids: [UUID]) {
        AppGroup.defaults?.set(ids.map { $0.uuidString }, forKey: key)
    }

    /// 두 자리를 **합쳐서** 읽는다. 한 번 샘플이었던 것은 계속 샘플이다.
    ///
    /// 옮겨 오기 전에 앱이 먼저 물어볼 수 있어서, 읽는 쪽에서도 옛 자리를 같이 본다.
    /// (옮기는 일 자체는 `migrateToAppGroupIfNeeded` 가 한 번만 한다)
    static func load() -> Set<UUID> {
        let current = AppGroup.defaults?.stringArray(forKey: key) ?? []
        let legacy = UserDefaults.standard.stringArray(forKey: legacyKey) ?? []
        return Set((current + legacy).compactMap { UUID(uuidString: $0) })
    }

    /// 옛 자리에 있던 샘플 id 를 App Group 으로 옮긴다.
    ///
    /// 이걸 안 하면 이미 쓰고 있던 사람의 샘플이 전부 "자기 것" 으로 세어져,
    /// 늘려 주려던 칸이 도리어 줄어든다.
    static func migrateToAppGroupIfNeeded() {
        let legacy = UserDefaults.standard.stringArray(forKey: legacyKey) ?? []
        guard !legacy.isEmpty else { return }
        let merged = Set((AppGroup.defaults?.stringArray(forKey: key) ?? []) + legacy)
        guard merged.count != (AppGroup.defaults?.stringArray(forKey: key) ?? []).count else { return }
        AppGroup.defaults?.set(Array(merged), forKey: key)
        print("🔄 [SampleMemoStorage] 샘플 id \(merged.count)개를 App Group 으로 옮김")
    }

    static func clear() {
        AppGroup.defaults?.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
}
