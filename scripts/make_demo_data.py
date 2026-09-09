#!/usr/bin/env python3
"""앱스토어 촬영용 데모 데이터 생성기.

실제 App Group 컨테이너에는 주민번호·카드번호·계좌번호 같은 **진짜 개인정보**가 들어 있어
그대로 찍으면 안 된다. 이 스크립트는 컨테이너의 `memos.data` · `clipboard.history.data` 를
**전부 가짜인** 데모 데이터로 덮는다. 원본을 비켜 두고 되돌리는 일은 shoot_prepare.py 가 한다.

    python3 scripts/make_demo_data.py ko    # 한국어 데모
    python3 scripts/make_demo_data.py en    # 영어 데모

여기 담긴 값은 하나도 빠짐없이 지어낸 것이다. 실존하는 계좌·카드·여권 번호가 아니고,
example.com / example.org 처럼 문서용으로 예약된 도메인만 쓴다(RFC 2606).
"""
import json
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone

CONTAINER = os.path.expanduser("~/Library/Group Containers/group.com.Ysoup.TokenMemo")

# Foundation 의 기준 시각(2001-01-01 UTC). JSONEncoder 기본 전략이 이 값 기준 초를 쓴다.
REFERENCE = datetime(2001, 1, 1, tzinfo=timezone.utc)


def ts(days_ago: float) -> float:
    """지금부터 days_ago 일 전을 Foundation 기준 초로."""
    return (datetime.now(timezone.utc) - timedelta(days=days_ago) - REFERENCE).total_seconds()


def memo(title, value, *, category, favorite=False, template=False,
         variables=None, secure=False, clips=0, edited=1.0, hint=None):
    """Memo 한 건. 키 이름은 Models.swift 의 CodingKeys 와 정확히 같아야 한다."""
    return {
        "id": str(uuid.uuid4()).upper(),
        "title": title,
        "value": value,
        "isChecked": False,
        "lastEdited": ts(edited),
        "isFavorite": favorite,
        "clipCount": clips,
        "category": category,
        "isSecure": secure,
        "isTemplate": template,
        "templateVariables": variables or [],
        "placeholderValues": {},
        "isCombo": False,
        "comboValues": [],
        "currentComboIndex": 0,
        "childMemoIds": [],
        "comboInterval": 2.0,
        "imageFileNames": [],
        "contentType": "text",
        "hintShownOnKeyboard": True,
        **({"hint": hint} if hint else {}),
    }


def clip(content, *, minutes_ago):
    return {
        "id": str(uuid.uuid4()).upper(),
        "content": content,
        "copiedAt": ts(minutes_ago / 1440.0),
        "isTemporary": True,
        "imageFileNames": [],
        "contentType": "text",
    }


# ── 한국어 ──────────────────────────────────────────────────────────────────
# 카테고리 이름은 userDefinedCategories_v1 에 넣는 값과 글자 그대로 같아야 탭이 선다.
# ⚠️ "기본" 은 번역하지 않는다 — MacCategoryName.basicSentinel(아이폰과의 계약)이고,
#    화면에는 그 언어의 이름("기본"/"General")으로 뜬다.
# ⚠️ 즐겨찾기는 **즐겨찾기 탭으로 빠져 기본 탭에 안 보인다**
#    (CategoryBucketRule.belongsToBasicBucket). 첫 화면이 허전해 보이지 않도록
#    즐겨찾기가 아닌 "기본" 단축어를 넉넉히 둔다.
KO_CATEGORIES = ["업무", "개인", "여행"]
KO_MEMOS = [
    # 즐겨찾기
    memo("회사 이메일", "gildong.hong@example.com",
         category="기본", favorite=True, clips=142, edited=0.2),
    memo("개인 이메일", "hong.gildong@example.org",
         category="기본", favorite=True, clips=98, edited=0.5),
    memo("휴대폰 번호", "010-0000-0000",
         category="기본", favorite=True, clips=76, edited=0.6),
    # 기본 탭
    memo("자주 쓰는 인사", "확인했습니다. 감사합니다!",
         category="기본", clips=88, edited=0.8),
    memo("자기소개",
         "안녕하세요, 홍길동입니다.\n제품팀에서 기획을 맡고 있습니다.\n연락처 hong.gildong@example.org",
         category="기본", clips=23, edited=3.0),
    memo("메일 서명",
         "홍길동 · 제품팀\n예시컴퍼니\nhong.gildong@example.com",
         category="기본", clips=64, edited=1.1),
    memo("화상회의 링크", "https://meet.example.com/gildong",
         category="기본", clips=41, edited=1.4),
    memo("깃허브 프로필", "https://github.com/example",
         category="기본", clips=15, edited=8.0),
    memo("부재중 안내",
         "지금은 자리를 비웠습니다. 남겨 주시면 확인 후 연락드리겠습니다.",
         category="기본", clips=11, edited=9.0),
    # 업무
    memo("회신 템플릿",
         "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드리겠습니다.\n\n홍길동 드림",
         category="업무", template=True, variables=["{이름}", "{날짜}"],
         clips=57, edited=1.2, hint="고객 문의 회신할 때"),
    memo("회의록 머리말",
         "[{날짜}] {주제}\n참석: {참석자}\n\n논의\n- \n\n결정\n- ",
         category="업무", template=True, variables=["{날짜}", "{주제}", "{참석자}"],
         clips=34, edited=2.0),
    memo("견적 안내",
         "{이름}님, 요청하신 견적 보내드립니다.\n검토 후 편하게 말씀 주세요.",
         category="업무", template=True, variables=["{이름}"], clips=26, edited=2.2),
    memo("사무실 와이파이", "네트워크 Example-Guest\n비밀번호 example1234",
         category="업무", clips=29, edited=4.0),
    memo("사업자 정보", "예시컴퍼니 / 000-00-00000\n서울특별시 중구 세종대로 000",
         category="업무", clips=18, edited=6.5),
    # 개인
    memo("계좌번호", "예시은행 000-0000-000000\n예금주 홍길동",
         category="개인", clips=61, edited=1.8),
    memo("집 주소", "서울특별시 중구 세종대로 000\n예시빌딩 0층 (00000)",
         category="개인", clips=45, edited=2.5),
    memo("배송지 메모", "부재 시 경비실에 맡겨 주세요.",
         category="개인", clips=19, edited=7.0),
    # 여행
    memo("여권 정보", "여권번호 M00000000\n영문이름 HONG GILDONG",
         category="여행", secure=True, clips=8, edited=6.0),
    memo("항공 예약번호", "ABC000 / 인천 → 도쿄 나리타",
         category="여행", clips=12, edited=5.0),
    memo("숙소 주소", "Example Hotel Tokyo\n0-0-0 Example, Shibuya, Tokyo",
         category="여행", clips=7, edited=5.5),
]
KO_CLIPS = [
    clip("gildong.hong@example.com", minutes_ago=2),
    clip("확인했습니다. 감사합니다!", minutes_ago=11),
    clip("https://meet.example.com/gildong", minutes_ago=26),
    clip("예시은행 000-0000-000000", minutes_ago=48),
    clip("[2026-09-09] 9월 스프린트 점검\n참석: 홍길동, 김예시", minutes_ago=95),
    clip("서울특별시 중구 세종대로 000", minutes_ago=140),
    clip("ABC000 / 인천 → 도쿄 나리타", minutes_ago=220),
    clip("Example-Guest / example1234", minutes_ago=310),
    clip("hong.gildong@example.org", minutes_ago=420),
]

# ── English ─────────────────────────────────────────────────────────────────
EN_CATEGORIES = ["Work", "Personal", "Travel"]
EN_MEMOS = [
    memo("Work Email", "jordan.reyes@example.com",
         category="기본", favorite=True, clips=142, edited=0.2),
    memo("Personal Email", "jordan.reyes@example.org",
         category="기본", favorite=True, clips=98, edited=0.5),
    memo("Mobile Number", "+1 555-000-0000",
         category="기본", favorite=True, clips=76, edited=0.6),
    memo("Quick Thanks", "Got it — thanks so much!",
         category="기본", clips=88, edited=0.8),
    memo("Introduction",
         "Hi, I'm Jordan Reyes.\nProduct manager on the platform team.\nReach me at jordan.reyes@example.org",
         category="기본", clips=23, edited=3.0),
    memo("Email Signature",
         "Jordan Reyes · Product\nExample Company\njordan.reyes@example.com",
         category="기본", clips=64, edited=1.1),
    memo("Meeting Link", "https://meet.example.com/jordan",
         category="기본", clips=41, edited=1.4),
    memo("GitHub Profile", "https://github.com/example",
         category="기본", clips=15, edited=8.0),
    memo("Away Message",
         "I'm away from my desk. Leave a note and I'll follow up.",
         category="기본", clips=11, edited=9.0),
    memo("Reply Template",
         "Hi {name}, thanks for reaching out.\nI'll get back to you by {date}.\n\nBest,\nJordan",
         category="Work", template=True, variables=["{name}", "{date}"],
         clips=57, edited=1.2, hint="Answering customer email"),
    memo("Meeting Notes Header",
         "[{date}] {topic}\nAttendees: {people}\n\nDiscussion\n- \n\nDecisions\n- ",
         category="Work", template=True, variables=["{date}", "{topic}", "{people}"],
         clips=34, edited=2.0),
    memo("Quote Follow-up",
         "Hi {name}, here's the quote you asked for.\nLet me know what you think.",
         category="Work", template=True, variables=["{name}"], clips=26, edited=2.2),
    memo("Office Wi-Fi", "Network Example-Guest\nPassword example1234",
         category="Work", clips=29, edited=4.0),
    memo("Company Details", "Example Company / 00-0000000\n000 Example Street, Springfield",
         category="Work", clips=18, edited=6.5),
    memo("Bank Account", "Example Bank 000-0000-000000\nJordan Reyes",
         category="Personal", clips=61, edited=1.8),
    memo("Home Address", "000 Example Street, Apt 0\nSpringfield, CA 00000",
         category="Personal", clips=45, edited=2.5),
    memo("Delivery Note", "Please leave the package with the front desk.",
         category="Personal", clips=19, edited=7.0),
    memo("Passport Details", "Passport M00000000\nJORDAN REYES",
         category="Travel", secure=True, clips=8, edited=6.0),
    memo("Flight Confirmation", "ABC000 / SFO → NRT",
         category="Travel", clips=12, edited=5.0),
    memo("Hotel Address", "Example Hotel Tokyo\n0-0-0 Example, Shibuya, Tokyo",
         category="Travel", clips=7, edited=5.5),
]
EN_CLIPS = [
    clip("jordan.reyes@example.com", minutes_ago=2),
    clip("Got it — thanks so much!", minutes_ago=11),
    clip("https://meet.example.com/jordan", minutes_ago=26),
    clip("Example Bank 000-0000-000000", minutes_ago=48),
    clip("[2026-09-09] Sprint check-in\nAttendees: Jordan, Alex", minutes_ago=95),
    clip("000 Example Street, Apt 0", minutes_ago=140),
    clip("ABC000 / SFO → NRT", minutes_ago=220),
    clip("Example-Guest / example1234", minutes_ago=310),
    clip("jordan.reyes@example.org", minutes_ago=420),
]

SETS = {
    "ko": (KO_MEMOS, KO_CLIPS, KO_CATEGORIES),
    "en": (EN_MEMOS, EN_CLIPS, EN_CATEGORIES),
}


def main():
    locale = sys.argv[1] if len(sys.argv) > 1 else "ko"
    if locale not in SETS:
        sys.exit(f"모르는 로케일: {locale} (ko | en)")
    memos, clips, categories = SETS[locale]

    if not os.path.isdir(CONTAINER):
        sys.exit(f"App Group 컨테이너가 없다: {CONTAINER}")

    for name, payload in (("memos.data", memos), ("clipboard.history.data", clips)):
        path = os.path.join(CONTAINER, name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        print(f"✅ {name} — {len(payload)}건")

    # 카테고리 탭 구성은 파일이 아니라 App Group UserDefaults 에 있다(shoot_prepare.py 가 쓴다).
    print("CATEGORIES=" + "\t".join(categories))


if __name__ == "__main__":
    main()
