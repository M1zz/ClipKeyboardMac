//
//  MacSecureAccess.swift
//  ClipKeyboard.tap
//
//  맥에서 보안 메모(isSecure)에 접근할 때 Touch ID(없으면 암호) 인증을 요구하고,
//  성공 시 iCloud 키체인 키로 복호화한 값을 돌려준다. iOS와 동일하게 보안 메모는
//  인증 전까지 평문이 노출되지 않는다.
//

import Foundation
import LocalAuthentication

enum MacSecureAccess {

    /// 붙여넣기용 값을 비동기로 돌려준다.
    /// - 일반 메모: 즉시 resolvedForPaste() 반환.
    /// - 보안 메모: Touch ID/암호 인증 후 복호화 + 템플릿 자동변수 처리. 실패/취소/키 미동기화 시 nil.
    static func resolveForPaste(_ memo: Memo, completion: @escaping (String?) -> Void) {
        guard memo.isSecure else {
            completion(memo.resolvedForPaste())
            return
        }
        let context = LAContext()
        context.localizedFallbackTitle = NSLocalizedString("암호 입력", comment: "Password fallback")
        var error: NSError?
        // 생체 우선 + 기기 암호 폴백(Touch ID 없는 맥 지원).
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            print("🔒 [MacSecureAccess] 인증 불가: \(error?.localizedDescription ?? "")")
            completion(nil)
            return
        }
        context.evaluatePolicy(
            policy,
            localizedReason: NSLocalizedString("보안 단축어에 접근하려면 인증이 필요합니다", comment: "Mac secure memo auth reason")
        ) { success, _ in
            DispatchQueue.main.async {
                guard success else { completion(nil); return }
                let decrypted: String?
                if SecureMemoCrypto.isEncrypted(memo.value) {
                    decrypted = SecureMemoCrypto.decrypt(memo.value)
                } else {
                    decrypted = memo.value
                }
                guard let plain = decrypted else {
                    print("🔒 [MacSecureAccess] 키 미동기화 - 복호화 불가")
                    completion(nil)
                    return
                }
                // 자동 변수(날짜/시간 등) 치환 — resolvedForPaste와 동일 규칙.
                let processed = (memo.isTemplate || plain.contains("{"))
                    ? TemplateVariableProcessor.process(plain)
                    : plain
                completion(processed)
            }
        }
    }

    /// 리스트/미리보기에 표시할 마스킹 문자열. 보안 메모는 값을 숨긴다.
    static func maskedPreview(_ memo: Memo) -> String {
        memo.isSecure ? "••••••••" : memo.value
    }
}
