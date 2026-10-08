#!/usr/bin/env python3
"""맥 앱스토어 스크린샷 원본 촬영 — Debug 빌드를 촬영 모드로 띄워 창만 찍는다.

    python3 scripts/shoot_mac.py <Debug 빌드 ClipKeyboard.tap.app> ko en ja …   # 언어마다 6장

앱은 `-ClipShotScreen <화면>` 촬영 모드로 뜬다(`MacShotMode`, Debug 빌드에만 있다).
- 단축어·클립보드 기록은 make_demo_data.py 의 데모를 **실행 인자로** 넘긴다. 앱은 실제 App Group
  파일을 읽지도 쓰지도 않는다. 그래서 shoot_prepare.py 의 백업·바꿔 끼우기가 필요 없다
  (macOS 가 다른 앱의 그룹 컨테이너 접근을 막아 터미널에서는 그 방법을 쓸 수도 없다).
- 카테고리 구성도 실행 인자(인자 도메인 — 읽을 때만 덮고 저장하지 않는다)로 준다.
- 동기화·백업·통계·클립보드 감시는 아예 세우지 않는다. 메뉴바 아이콘·다른 앱 창을 건드리지 않는다.
결과: docs/screenshots/raw/<언어>/0N-<화면>.png  (창만, 그림자 없음)

Debug 빌드:
    xcodebuild -project ClipKeyboard.tap.xcodeproj -scheme ClipKeyboard.tap -configuration Debug \
      -destination 'platform=macOS' -derivedDataPath <dd> -allowProvisioningUpdates build
"""
import base64
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_demo_data  # noqa: E402  (데모 단축어 · 클립보드 · 카테고리)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "screenshots", "raw")

# (파일 이름, 촬영 모드 화면, 창 크기(pt) — None 이면 앱이 정한 크기)
SCREENS = [
    ("01-list", "list", "460x530"),
    ("02-popover", "popover", None),
    ("03-panel", "panel", None),
    ("04-clipboard", "clipboard", "600x560"),
    ("05-shortcuts", "prefs", "612x400"),
    ("06-icloud", "backup", "560x620"),
]


def plist_value(v):
    """인자 도메인용 옛 plist 표기."""
    if isinstance(v, bool):
        return "<true/>" if v else "<false/>"   # 옛 표기 YES 는 문자열로 읽혀 `as? Bool` 이 실패한다
    if isinstance(v, list):
        return "(" + ",".join(plist_value(x) for x in v) + ")"
    if isinstance(v, dict):
        return "{" + "".join(f"{plist_value(k)}={plist_value(x)};" for k, x in v.items()) + "}"
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def demo_args(locale):
    memos, clips, cats = make_demo_data.SETS[locale]
    prefs = {
        # 촬영 화면 구성 — shoot_prepare.py 의 demo 와 같은 값
        "category.feature.enabled.v1": True,
        "mac.category.followPhoneTabs.v1": True,
        "userDefinedCategories_v1": cats,
        "enabledBuiltInCategories_v1": ["templates"],
        "hiddenCategoryTabs_v1": [],
        "userCategoryIcons_v1": dict(zip(cats, ["briefcase.fill", "person.fill", "airplane"])),
        "memoManualOrderActive_v1": False,
        # '동기화가 꺼져 있습니다' 배너를 가린다. 촬영 모드는 엔진을 세우지 않으니 실제로 돌지는 않는다.
        "memoSyncEnabled": True,
    }
    b64 = lambda x: base64.b64encode(json.dumps(x, ensure_ascii=False).encode()).decode()
    args = ["-ClipShotDemoMemos", b64(memos), "-ClipShotDemoClips", b64(clips)]
    for k, v in prefs.items():
        args += ["-" + k, plist_value(v)]
    return args


def shoot(app, locale):
    out_dir = os.path.join(RAW, locale)
    os.makedirs(out_dir, exist_ok=True)
    binary = os.path.join(app, "Contents", "MacOS", "ClipKeyboard.tap")
    base = [binary, "-AppleLanguages", f"({locale})"] + demo_args(locale)
    for name, screen, size in SCREENS:
        args = base + ["-ClipShotScreen", screen]
        if size:
            args += ["-ClipShotSize", size]
        # 앱이 자기 창을 찍어 `CLIPSHOT:<base64>` 로 내보내고 스스로 끝난다 (MacShotMode.captureAndQuit)
        try:
            out = subprocess.run(args, capture_output=True, text=True, timeout=30).stdout
        except subprocess.TimeoutExpired:
            out = ""
        line = next((l for l in out.splitlines() if l.startswith("CLIPSHOT:")), "CLIPSHOT:FAIL")
        data = line[len("CLIPSHOT:"):]
        if data == "FAIL" or not data:
            print(f"  ✗ {locale}/{name} — 찍지 못했다")
            continue
        with open(os.path.join(out_dir, name + ".png"), "wb") as f:
            f.write(base64.b64decode(data))
        print(f"  ✓ {locale}/{name}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    app = sys.argv[1]
    for loc in sys.argv[2:]:
        print(f"── {loc} ──")
        shoot(app, loc)
