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

    /// 샘플 문구를 고를 언어. 기기 언어를 따르되, 지원하지 않는 언어는 영어로 떨어진다.
    enum SampleLanguage {
        case korean
        case simplifiedChinese
        case traditionalChinese
        case english

        /// 중국어는 languageCode 만으로는 간·번체를 구분할 수 없어 script/region 까지 본다.
        static var current: SampleLanguage {
            let language = Locale.current.language
            switch language.languageCode?.identifier {
            case "ko":
                return .korean
            case "zh":
                if let script = language.script?.identifier {
                    return script == "Hant" ? .traditionalChinese : .simplifiedChinese
                }
                // script 가 비어 있으면 지역으로 판단 (TW/HK/MO 는 번체).
                let region = Locale.current.region?.identifier ?? ""
                return ["TW", "HK", "MO"].contains(region) ? .traditionalChinese : .simplifiedChinese
            default:
                return .english
            }
        }
    }

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

        let samples = makeSamples(language: SampleLanguage.current)
        do {
            try MemoStore.shared.save(memos: samples, type: .memo)
            // 어떤 메모가 시드인지 기억해 둔다 — 동기화에서 제외하기 위해서.
            // 샘플은 기기 언어를 따라 새 UUID 로 심기므로, 표식이 없으면 아이폰의 샘플과
            // 서로 다른 사용자 메모로 취급돼 양쪽에 섞인다.
            SampleMemoStorage.save(ids: samples.map { $0.id })
            UserDefaults.standard.set(true, forKey: seededKey)
            NotificationCenter.default.post(name: .dataRestored, object: nil)
            print("✅ [MacSampleSeeder] 더미 메모 \(samples.count)개 시드 완료")
        } catch {
            print("❌ [MacSampleSeeder] 시드 실패: \(error)")
        }
    }

    /// 언어별 문구 묶음. 새 언어를 지원할 땐 여기에 한 줄씩 추가하면 된다.
    private struct SampleStrings {
        let work: String
        let personal: String
        let emailTitle: String
        let accountTitle: String
        let accountValue: String
        let templateTitle: String
        let templateValue: String
        let templateVariables: [String]
        let introTitle: String
        let introValue: String
    }

    private static func strings(for language: SampleLanguage) -> SampleStrings {
        switch language {
        case .korean:
            return SampleStrings(
                work: "업무",
                personal: "개인",
                emailTitle: "내 이메일",
                accountTitle: "내 계좌번호",
                accountValue: "은행: 카카오뱅크\n예금주: 홍길동\n계좌번호: 3333-00-0000000",
                templateTitle: "회신 템플릿",
                templateValue: "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드릴게요.",
                templateVariables: ["{이름}", "{날짜}"],
                introTitle: "자기소개",
                introValue: "안녕하세요, 홍길동입니다.\n연락처: example@email.com"
            )
        case .simplifiedChinese:
            return SampleStrings(
                work: "工作",
                personal: "个人",
                emailTitle: "我的邮箱",
                accountTitle: "我的银行账号",
                accountValue: "银行：示例银行\n户名：张三\n账号：0000-0000-0000",
                templateTitle: "回复模板",
                templateValue: "{姓名}你好，感谢你的来信。\n我会在 {日期} 前回复你。",
                templateVariables: ["{姓名}", "{日期}"],
                introTitle: "自我介绍",
                introValue: "你好，我是张三。\n联系方式：example@email.com"
            )
        case .traditionalChinese:
            return SampleStrings(
                work: "工作",
                personal: "個人",
                emailTitle: "我的電子郵件",
                accountTitle: "我的銀行帳號",
                accountValue: "銀行：範例銀行\n戶名：王小明\n帳號：0000-0000-0000",
                templateTitle: "回覆範本",
                templateValue: "{姓名}你好，感謝你的來信。\n我會在 {日期} 前回覆你。",
                templateVariables: ["{姓名}", "{日期}"],
                introTitle: "自我介紹",
                introValue: "你好，我是王小明。\n聯絡方式：example@email.com"
            )
        case .english:
            return SampleStrings(
                work: "Work",
                personal: "Personal",
                emailTitle: "My Email",
                accountTitle: "My Bank Account",
                accountValue: "Bank: Example Bank\nName: John Doe\nAccount: 000-000-000000",
                templateTitle: "Reply Template",
                templateValue: "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
                templateVariables: ["{name}", "{date}"],
                introTitle: "Introduction",
                introValue: "Hi, I'm John Doe.\nContact: example@email.com"
            )
        }
    }

    private static func makeSamples(language: SampleLanguage) -> [Memo] {
        let s = strings(for: language)

        // 1) 즐겨찾기 메모 — 탭으로 바로 복사되는 핵심 사용감.
        let email = Memo(
            title: s.emailTitle,
            value: "example@email.com",
            isFavorite: true,
            category: s.personal
        )
        // 2) 계좌번호 — "누구의 계좌번호" 처럼 키-값으로 저장해 두는 대표 케이스.
        let account = Memo(
            title: s.accountTitle,
            value: s.accountValue,
            category: s.personal
        )
        // 3) 템플릿 — {빈칸}을 채워 완성하는 회신 문구.
        let template = Memo(
            title: s.templateTitle,
            value: s.templateValue,
            category: s.work,
            isTemplate: true,
            templateVariables: s.templateVariables
        )
        // 4) 자기소개 — 자주 붙여넣는 소개 문구.
        let intro = Memo(
            title: s.introTitle,
            value: s.introValue,
            category: s.work
        )
        return [email, account, template, intro]
    }
}
