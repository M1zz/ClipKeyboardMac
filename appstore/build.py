#!/usr/bin/env python3
"""App Store 맥 스크린샷 합성 — 원본 창 캡처 위에 카피를 얹어 2880×1800 으로 그린다.

    python3 appstore/build.py          # ko, en 전부
    python3 appstore/build.py ko       # 한 언어만
    python3 appstore/build.py --html   # 눈으로 보려고 HTML 만 남긴다

원본은 `appstore/raw/<locale>/*.png` (앱을 실제로 띄워 `screencapture -l` 로 찍은 창).
다시 만들 때는 원본만 새로 찍고 이 스크립트를 그대로 재실행하면 된다.

⚠️ 맥 스크린샷은 1280×800 · 1440×900 · 2560×1600 · 2880×1800 중 하나여야 하고,
   **한 벌 안에서는 크기가 같아야 한다.** 여기서는 2880×1800 로 통일한다.
⚠️ 말은 SHOTS 한 곳에만 있다. 한국어를 기계번역하지 않고 각 언어로 따로 썼다.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
RAW = ROOT / "raw"
WORK = ROOT / ".html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

W, H = 2880, 1800
ACCENT = "#494d79"          # 앱 버튼·토글 색을 그대로 가져왔다

# (출력이름, 원본파일, 헤드라인, 서브카피) — 스토어에 걸리는 순서 그대로.
SHOTS = {
    "ko": [
        ("01-panel",     "03-panel.png",     "어디서나 ⌃⇧V",        "쓰던 앱 위에 떠서, 고르면 곧바로 복사됩니다"),
        ("02-menubar",   "02-popover.png",   "메뉴바에서 바로",       "검색하거나 ⌘1~9 로 골라 꺼냅니다"),
        ("03-list",      "01-list.png",      "자주 쓰는 말을 모아 둡니다", "카테고리로 나누고, 손이 자주 가는 것은 위로"),
        ("04-clipboard", "04-clipboard.png", "복사한 것이 사라지지 않게", "지나간 클립보드를 다시 꺼내 씁니다"),
        ("05-shortcuts", "05-shortcuts.png", "손이 기억하는 단축키",   "패널·목록·기록을 한 손으로 엽니다"),
        ("06-icloud",    "06-icloud.png",    "아이폰과 같은 단축어",   "iCloud 로 백업하고 어느 기기에서나 씁니다"),
    ],
    "en": [
        ("01-panel",     "03-panel.png",     "⌃⇧V, anywhere",          "It floats over your app — click once to copy"),
        ("02-menubar",   "02-popover.png",   "Right from the menu bar", "Search, or press ⌘1–9 to grab one"),
        ("03-list",      "01-list.png",      "Keep what you type often", "Sort into categories, star the ones you reach for"),
        ("04-clipboard", "04-clipboard.png", "Nothing you copy is lost", "Reach back for anything you copied earlier"),
        ("05-shortcuts", "05-shortcuts.png", "Shortcuts your hands learn", "Panel, list and history — all one-handed"),
        ("06-icloud",    "06-icloud.png",    "The same shortcuts as your iPhone", "Back them up to iCloud and use them anywhere"),
    ],
}

# 배경 색조를 장마다 조금씩 달리해 여섯 장이 한 벌로 보이되 단조롭지 않게.
TINTS = ["#eef0f8", "#f1eef6", "#eef4f6", "#f3f1ec", "#eef0f8", "#eff2f5"]

PAGE = """<!doctype html><meta charset="utf-8">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  body {{
    background:
      radial-gradient(120% 90% at 50% -10%, #ffffff 0%, {tint} 55%, {tint2} 100%);
    font-family: -apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Helvetica Neue", sans-serif;
    display:flex; flex-direction:column; align-items:center;
    padding:150px 120px 130px;
  }}
  h1 {{
    font-size:112px; font-weight:700; letter-spacing:-3px; line-height:1.14;
    color:#1b1c24; text-align:center; max-width:2200px;
  }}
  p.sub {{
    margin-top:40px; font-size:52px; font-weight:400; letter-spacing:-0.8px;
    color:#6d6f80; text-align:center; max-width:1900px;
  }}
  .stage {{ flex:1; display:flex; align-items:center; justify-content:center;
            margin-top:70px; width:100%; min-height:0; }}
  /* 창 캡처는 크기가 제각각이다. 무대 높이에 맞춰 키워 여섯 장의 창이
     비슷한 덩치로 보이게 한다(원본이 2x 레티나라 1.4배까지는 뭉개지지 않는다). */
  .stage img {{
    height:100%; width:auto; max-width:1750px;
    border-radius:22px;
    box-shadow: 0 60px 120px rgba(28,30,58,.26), 0 18px 40px rgba(28,30,58,.16);
  }}
  .rule {{ width:132px; height:9px; border-radius:9px; background:{accent};
           opacity:.85; margin-top:46px; }}
</style>
<h1>{headline}</h1>
<p class="sub">{sub}</p>
<div class="rule"></div>
<div class="stage"><img src="{img}"></div>
"""


def build(locale, html_only=False):
    src_dir = RAW / locale
    out_dir = ROOT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)

    for i, (name, src, headline, sub) in enumerate(SHOTS[locale]):
        img = src_dir / src
        if not img.exists():
            print(f"  ✗ {name} — 원본 없음: {img}")
            continue
        html = WORK / f"{locale}-{name}.html"
        html.write_text(PAGE.format(
            W=W, H=H, tint=TINTS[i], tint2=TINTS[i], accent=ACCENT,
            headline=headline, sub=sub, img=img.as_uri()), encoding="utf-8")
        if html_only:
            print(f"  · {html}")
            continue
        out = out_dir / f"{name}.png"
        subprocess.run([
            CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
            f"--screenshot={out}", f"--window-size={W},{H}",
            "--default-background-color=00000000", html.as_uri(),
        ], check=True, capture_output=True)
        print(f"  ✓ {locale}/{name}.png")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    html_only = "--html" in sys.argv
    if not pathlib.Path(CHROME).exists():
        sys.exit(f"Chrome 이 없다: {CHROME}")
    for loc in (args or ["ko", "en"]):
        print(f"── {loc} ──")
        build(loc, html_only)
