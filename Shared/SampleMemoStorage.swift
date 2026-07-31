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
    private static let key = "sampleMemoUUIDs_v1"

    static func save(ids: [UUID]) {
        UserDefaults.standard.set(ids.map { $0.uuidString }, forKey: key)
    }

    static func load() -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
