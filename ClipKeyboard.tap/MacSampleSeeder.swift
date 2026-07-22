//
//  MacSampleSeeder.swift
//  ClipKeyboard.tap
//
//  Mac 첫 실행 시 더미 메모를 시드한다. 온보딩 대신 바로 "쓸 수 있는 메모"를
//  만나게 하기 위함. iCloud 자동 복원이 끝난 뒤 호출되어, 실제 데이터(또는
//  복원분)가 있으면 시드하지 않는다 — 더미 중복/실데이터 가림을 방지.
//

import Foundation

enum MacSampleSeeder {
    private static let seededKey = "macDefaultSamplesSeeded_v1"

    /// 첫 실행이고 로컬 메모가 비어있을 때만 더미를 시드한다(1회).
    /// 반드시 CloudKit 자동 복원 이후에 호출할 것.
    @MainActor
    static func seedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        let existing = (try? MemoStore.shared.load(type: .memo)) ?? []
        guard existing.isEmpty else {
            // 이미 데이터가 있으면(복원 포함) 더미를 넣지 않고 플래그만 세운다.
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let isKorean = (Locale.current.language.languageCode?.identifier ?? "en") == "ko"
        let samples = makeSamples(isKorean: isKorean)
        do {
            try MemoStore.shared.save(memos: samples, type: .memo)
            UserDefaults.standard.set(true, forKey: seededKey)
            NotificationCenter.default.post(name: .dataRestored, object: nil)
            print("✅ [MacSampleSeeder] 더미 메모 \(samples.count)개 시드 완료")
        } catch {
            print("❌ [MacSampleSeeder] 시드 실패: \(error)")
        }
    }

    private static func makeSamples(isKorean: Bool) -> [Memo] {
        let work = isKorean ? "업무" : "Work"
        let personal = isKorean ? "개인" : "Personal"

        // 1) 즐겨찾기 메모 — 탭으로 바로 복사되는 핵심 사용감.
        let email = Memo(
            title: isKorean ? "내 이메일" : "My Email",
            value: "example@email.com",
            isFavorite: true,
            category: personal
        )
        // 2) 계좌번호 — "누구의 계좌번호" 처럼 키-값으로 저장해 두는 대표 케이스.
        let account = Memo(
            title: isKorean ? "내 계좌번호" : "My Bank Account",
            value: isKorean
                ? "은행: 카카오뱅크\n예금주: 홍길동\n계좌번호: 3333-00-0000000"
                : "Bank: Example Bank\nName: John Doe\nAccount: 000-000-000000",
            category: personal
        )
        // 3) 템플릿 — {빈칸}을 채워 완성하는 회신 문구.
        let template = Memo(
            title: isKorean ? "회신 템플릿" : "Reply Template",
            value: isKorean
                ? "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드릴게요."
                : "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
            category: work,
            isTemplate: true,
            templateVariables: isKorean ? ["{이름}", "{날짜}"] : ["{name}", "{date}"]
        )
        // 4) 자기소개 — 자주 붙여넣는 소개 문구.
        let intro = Memo(
            title: isKorean ? "자기소개" : "Introduction",
            value: isKorean
                ? "안녕하세요, 홍길동입니다.\n연락처: example@email.com"
                : "Hi, I'm John Doe.\nContact: example@email.com",
            category: work
        )
        return [email, account, template, intro]
    }
}
