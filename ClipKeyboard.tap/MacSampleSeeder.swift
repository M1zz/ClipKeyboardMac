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
        case japanese
        case german
        case spanish
        case french
        case italian
        case portuguese
        case russian
        case czech
        case danish
        case greek
        case finnish
        case indonesian
        case norwegian
        case dutch
        case polish
        case swedish
        case thai
        case turkish
        case vietnamese

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
            case "ja":
                return .japanese
            case "de":
                return .german
            case "es":
                return .spanish
            case "fr":
                return .french
            case "it":
                return .italian
            case "pt":
                return .portuguese
            case "ru":
                return .russian
            case "cs":
                return .czech
            case "da":
                return .danish
            case "el":
                return .greek
            case "fi":
                return .finnish
            case "id", "in":
                return .indonesian
            case "nb", "no", "nn":
                return .norwegian
            case "nl":
                return .dutch
            case "pl":
                return .polish
            case "sv":
                return .swedish
            case "th":
                return .thai
            case "tr":
                return .turkish
            case "vi":
                return .vietnamese
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
        case .japanese:
            return SampleStrings(
                work: "仕事",
                personal: "プライベート",
                emailTitle: "メールアドレス",
                accountTitle: "振込先口座",
                accountValue: "銀行：サンプル銀行 本店\n口座名義：ヤマダ タロウ\n普通 0000000",
                templateTitle: "返信テンプレート",
                templateValue: "{名前}様\nお問い合わせありがとうございます。\n{日付}までにご連絡いたします。",
                templateVariables: ["{名前}", "{日付}"],
                introTitle: "自己紹介",
                introValue: "はじめまして、山田太郎です。\n連絡先：example@email.com"
            )
        case .german:
            return SampleStrings(
                work: "Arbeit",
                personal: "Privat",
                emailTitle: "Meine E-Mail",
                accountTitle: "Meine Bankverbindung",
                accountValue: "Bank: Beispielbank\nKontoinhaber: Max Mustermann\nIBAN: DE00 0000 0000 0000 0000 00",
                templateTitle: "Antwortvorlage",
                templateValue: "Hallo {Name}, danke für deine Nachricht.\nIch melde mich bis {Datum}.",
                templateVariables: ["{Name}", "{Datum}"],
                introTitle: "Vorstellung",
                introValue: "Hallo, ich bin Max Mustermann.\nKontakt: example@email.com"
            )
        case .spanish:
            return SampleStrings(
                work: "Trabajo",
                personal: "Personal",
                emailTitle: "Mi correo",
                accountTitle: "Mi cuenta bancaria",
                accountValue: "Banco: Banco Ejemplo\nTitular: Lucía García\nCuenta: 0000 0000 0000 0000",
                templateTitle: "Plantilla de respuesta",
                templateValue: "Hola, {nombre}. Gracias por escribirnos.\nTe responderé antes del {fecha}.",
                templateVariables: ["{nombre}", "{fecha}"],
                introTitle: "Presentación",
                introValue: "Hola, soy Lucía García.\nContacto: example@email.com"
            )
        case .french:
            return SampleStrings(
                work: "Travail",
                personal: "Perso",
                emailTitle: "Mon e-mail",
                accountTitle: "Mon RIB",
                accountValue: "Banque : Banque Exemple\nTitulaire : Camille Martin\nIBAN : FR00 0000 0000 0000 0000 0000 000",
                templateTitle: "Modèle de réponse",
                templateValue: "Bonjour {nom}, merci pour votre message.\nJe vous réponds d’ici le {date}.",
                templateVariables: ["{nom}", "{date}"],
                introTitle: "Présentation",
                introValue: "Bonjour, je suis Camille Martin.\nContact : example@email.com"
            )
        case .italian:
            return SampleStrings(
                work: "Lavoro",
                personal: "Personale",
                emailTitle: "La mia email",
                accountTitle: "Il mio conto",
                accountValue: "Banca: Banca Esempio\nIntestatario: Giulia Rossi\nIBAN: IT00 X000 0000 0000 0000 0000 000",
                templateTitle: "Modello di risposta",
                templateValue: "Ciao {nome}, grazie per averci scritto.\nTi rispondo entro il {data}.",
                templateVariables: ["{nome}", "{data}"],
                introTitle: "Presentazione",
                introValue: "Ciao, sono Giulia Rossi.\nContatto: example@email.com"
            )
        case .portuguese:
            return SampleStrings(
                work: "Trabalho",
                personal: "Pessoal",
                emailTitle: "Meu e-mail",
                accountTitle: "Minha conta bancária",
                accountValue: "Banco: Banco Exemplo\nTitular: Ana Souza\nAgência 0000 · Conta 00000-0",
                templateTitle: "Modelo de resposta",
                templateValue: "Oi, {nome}! Obrigada pela mensagem.\nRespondo até {data}.",
                templateVariables: ["{nome}", "{data}"],
                introTitle: "Apresentação",
                introValue: "Oi, eu sou a Ana Souza.\nContato: example@email.com"
            )
        case .russian:
            return SampleStrings(
                work: "Работа",
                personal: "Личное",
                emailTitle: "Моя почта",
                accountTitle: "Мой банковский счёт",
                accountValue: "Банк: Пример Банк\nПолучатель: Иван Петров\nСчёт: 00000 000 0 0000 0000000",
                templateTitle: "Шаблон ответа",
                templateValue: "Здравствуйте, {имя}! Спасибо за сообщение.\nОтвечу до {дата}.",
                templateVariables: ["{имя}", "{дата}"],
                introTitle: "О себе",
                introValue: "Здравствуйте, меня зовут Иван Петров.\nКонтакт: example@email.com"
            )
        case .czech:
            return SampleStrings(
                work: "Práce",
                personal: "Osobní",
                emailTitle: "Můj e-mail",
                accountTitle: "Můj bankovní účet",
                accountValue: "Banka: Ukázková banka\nMajitel účtu: Jan Novák\nČíslo účtu: 000000-0000000000/0000",
                templateTitle: "Šablona odpovědi",
                templateValue: "Dobrý den, {jméno}, děkuji za zprávu.\nOdpovím do {datum}.",
                templateVariables: ["{jméno}", "{datum}"],
                introTitle: "Představení",
                introValue: "Dobrý den, jmenuji se Jan Novák.\nKontakt: example@email.com"
            )
        case .danish:
            return SampleStrings(
                work: "Arbejde",
                personal: "Privat",
                emailTitle: "Min e-mail",
                accountTitle: "Min bankkonto",
                accountValue: "Bank: Eksempelbank\nNavn: Jens Hansen\nKonto: 0000 0000000000",
                templateTitle: "Svarskabelon",
                templateValue: "Hej {navn}, tak for din besked.\nJeg vender tilbage senest {dato}.",
                templateVariables: ["{navn}", "{dato}"],
                introTitle: "Præsentation",
                introValue: "Hej, jeg hedder Jens Hansen.\nKontakt: example@email.com"
            )
        case .greek:
            return SampleStrings(
                work: "Δουλειά",
                personal: "Προσωπικά",
                emailTitle: "Το email μου",
                accountTitle: "Ο τραπεζικός μου λογαριασμός",
                accountValue: "Τράπεζα: Παράδειγμα Τράπεζα\nΔικαιούχος: Γιώργος Παπαδόπουλος\nIBAN: GR00 0000 0000 0000 0000 0000 000",
                templateTitle: "Πρότυπο απάντησης",
                templateValue: "Γεια σας {όνομα}, ευχαριστώ για το μήνυμα.\nΘα απαντήσω έως {ημερομηνία}.",
                templateVariables: ["{όνομα}", "{ημερομηνία}"],
                introTitle: "Συστάσεις",
                introValue: "Γεια σας, είμαι ο Γιώργος Παπαδόπουλος.\nΕπικοινωνία: example@email.com"
            )
        case .finnish:
            return SampleStrings(
                work: "Työ",
                personal: "Oma",
                emailTitle: "Sähköpostini",
                accountTitle: "Pankkitilini",
                accountValue: "Pankki: Esimerkkipankki\nNimi: Matti Meikäläinen\nIBAN: FI00 0000 0000 0000 00",
                templateTitle: "Vastauspohja",
                templateValue: "Hei {nimi}, kiitos viestistäsi.\nVastaan viimeistään {päivä}.",
                templateVariables: ["{nimi}", "{päivä}"],
                introTitle: "Esittely",
                introValue: "Hei, olen Matti Meikäläinen.\nYhteystiedot: example@email.com"
            )
        case .indonesian:
            return SampleStrings(
                work: "Kerja",
                personal: "Pribadi",
                emailTitle: "Email Saya",
                accountTitle: "Rekening Saya",
                accountValue: "Bank: Bank Contoh\nAtas nama: Budi Santoso\nNo. rekening: 000-000-0000",
                templateTitle: "Templat Balasan",
                templateValue: "Halo {nama}, terima kasih sudah menghubungi kami.\nSaya akan membalas paling lambat {tanggal}.",
                templateVariables: ["{nama}", "{tanggal}"],
                introTitle: "Perkenalan",
                introValue: "Halo, saya Budi Santoso.\nKontak: example@email.com"
            )
        case .norwegian:
            return SampleStrings(
                work: "Jobb",
                personal: "Privat",
                emailTitle: "Min e-post",
                accountTitle: "Min bankkonto",
                accountValue: "Bank: Eksempelbanken\nNavn: Ola Nordmann\nKonto: 0000 00 00000",
                templateTitle: "Svarmal",
                templateValue: "Hei {navn}, takk for meldingen.\nJeg svarer innen {dato}.",
                templateVariables: ["{navn}", "{dato}"],
                introTitle: "Presentasjon",
                introValue: "Hei, jeg heter Ola Nordmann.\nKontakt: example@email.com"
            )
        case .dutch:
            return SampleStrings(
                work: "Werk",
                personal: "Privé",
                emailTitle: "Mijn e-mail",
                accountTitle: "Mijn bankrekening",
                accountValue: "Bank: Voorbeeldbank\nNaam: Jan Jansen\nIBAN: NL00 BANK 0000 0000 00",
                templateTitle: "Antwoordsjabloon",
                templateValue: "Hoi {naam}, bedankt voor je bericht.\nIk reageer uiterlijk {datum}.",
                templateVariables: ["{naam}", "{datum}"],
                introTitle: "Introductie",
                introValue: "Hoi, ik ben Jan Jansen.\nContact: example@email.com"
            )
        case .polish:
            return SampleStrings(
                work: "Praca",
                personal: "Prywatne",
                emailTitle: "Mój e-mail",
                accountTitle: "Moje konto bankowe",
                accountValue: "Bank: Przykładowy Bank\nOdbiorca: Jan Kowalski\nNumer konta: 00 0000 0000 0000 0000 0000 0000",
                templateTitle: "Szablon odpowiedzi",
                templateValue: "Dzień dobry, {imię}, dziękuję za wiadomość.\nOdpiszę do {data}.",
                templateVariables: ["{imię}", "{data}"],
                introTitle: "O mnie",
                introValue: "Dzień dobry, nazywam się Jan Kowalski.\nKontakt: example@email.com"
            )
        case .swedish:
            return SampleStrings(
                work: "Jobb",
                personal: "Privat",
                emailTitle: "Min e-post",
                accountTitle: "Mitt bankkonto",
                accountValue: "Bank: Exempelbanken\nNamn: Sven Svensson\nKonto: 0000-00 000 00",
                templateTitle: "Svarsmall",
                templateValue: "Hej {namn}, tack för ditt meddelande.\nJag återkommer senast {datum}.",
                templateVariables: ["{namn}", "{datum}"],
                introTitle: "Presentation",
                introValue: "Hej, jag heter Sven Svensson.\nKontakt: example@email.com"
            )
        case .thai:
            return SampleStrings(
                work: "งาน",
                personal: "ส่วนตัว",
                emailTitle: "อีเมลของฉัน",
                accountTitle: "บัญชีธนาคารของฉัน",
                accountValue: "ธนาคาร: ธนาคารตัวอย่าง\nชื่อบัญชี: สมชาย ใจดี\nเลขบัญชี: 000-0-00000-0",
                templateTitle: "เทมเพลตตอบกลับ",
                templateValue: "สวัสดีคุณ{ชื่อ} ขอบคุณที่ติดต่อมา\nจะตอบกลับภายใน {วันที่} นะครับ",
                templateVariables: ["{ชื่อ}", "{วันที่}"],
                introTitle: "แนะนำตัว",
                introValue: "สวัสดีครับ ผมชื่อสมชาย ใจดี\nติดต่อ: example@email.com"
            )
        case .turkish:
            return SampleStrings(
                work: "İş",
                personal: "Kişisel",
                emailTitle: "E-postam",
                accountTitle: "Banka Hesabım",
                accountValue: "Banka: Örnek Bank\nAd Soyad: Ahmet Yılmaz\nIBAN: TR00 0000 0000 0000 0000 0000 00",
                templateTitle: "Yanıt Şablonu",
                templateValue: "Merhaba {ad}, mesajınız için teşekkürler.\n{tarih} tarihine kadar dönüş yapacağım.",
                templateVariables: ["{ad}", "{tarih}"],
                introTitle: "Tanıtım",
                introValue: "Merhaba, ben Ahmet Yılmaz.\nİletişim: example@email.com"
            )
        case .vietnamese:
            return SampleStrings(
                work: "Công việc",
                personal: "Cá nhân",
                emailTitle: "Email của tôi",
                accountTitle: "Tài khoản ngân hàng",
                accountValue: "Ngân hàng: Ngân hàng Mẫu\nChủ tài khoản: Nguyễn Văn An\nSố tài khoản: 0000 0000 0000",
                templateTitle: "Mẫu trả lời",
                templateValue: "Chào {tên}, cảm ơn bạn đã liên hệ.\nMình sẽ phản hồi trước {ngày}.",
                templateVariables: ["{tên}", "{ngày}"],
                introTitle: "Giới thiệu bản thân",
                introValue: "Xin chào, mình là Nguyễn Văn An.\nLiên hệ: example@email.com"
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
