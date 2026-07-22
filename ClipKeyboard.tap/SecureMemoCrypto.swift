//
//  SecureMemoCrypto.swift
//  ClipKeyboard.tap
//
//  iOS의 SecureMemoCrypto와 동일 로직(맥 타겟은 코드를 공유하지 않으므로 이식).
//  같은 키체인 service/account + iCloud 키체인 동기화 + 같은 액세스 그룹을 쓰므로
//  iOS에서 만든 키를 그대로 읽어 보안 메모를 복호화한다.
//

import Foundation
import CryptoKit
import Security

enum SecureMemoCrypto {

    static let marker = "smenc1:"

    private static let keychainService = "com.Ysoup.TokenMemo.securememo"
    private static let keychainAccount = "secure_memo_master_key_v1"

    static func isEncrypted(_ value: String) -> Bool { value.hasPrefix(marker) }

    static var isKeyAvailable: Bool { loadKey() != nil }

    static func encrypt(_ plaintext: String) -> String? {
        if isEncrypted(plaintext) { return plaintext }
        guard let key = key() else { return nil }
        guard let data = plaintext.data(using: .utf8),
              let sealed = try? AES.GCM.seal(data, using: key),
              let combined = sealed.combined else { return nil }
        return marker + combined.base64EncodedString()
    }

    static func decrypt(_ value: String) -> String? {
        guard isEncrypted(value) else { return value }
        guard let key = loadKey() else { return nil }
        let b64 = String(value.dropFirst(marker.count))
        guard let combined = Data(base64Encoded: b64),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let opened = try? AES.GCM.open(box, using: key),
              let text = String(data: opened, encoding: .utf8) else { return nil }
        return text
    }

    private static func key() -> SymmetricKey? {
        if let existing = loadKey() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        if storeKey(newKey) { return newKey }
        return loadKey()
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }

    private static func loadKey() -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data, data.count == 32 else { return nil }
        return SymmetricKey(data: data)
    }

    @discardableResult
    private static func storeKey(_ key: SymmetricKey) -> Bool {
        let data = key.withUnsafeBytes { Data(Array($0)) }
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { return true }
        return status == errSecSuccess
    }
}
