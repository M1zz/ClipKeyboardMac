#!/usr/bin/env python3
"""App Store 맥 스크린샷 합성 — 원본 창 그림 위에 카피를 얹어 2880×1800 으로 그린다.

    python3 docs/screenshots/build.py          # 23개 언어 전부
    python3 docs/screenshots/build.py ko ja    # 몇 언어만
    python3 docs/screenshots/build.py --html   # 눈으로 보려고 HTML 만 남긴다

원본은 `raw/<locale>/*.png` — `scripts/shoot_mac.py` 가 Debug 빌드를 촬영 모드로 띄워 그린 창.
결과는 `marketing/<locale>/0N-….png` — DeployBar 가 이 폴더를 그대로 스토어에 올린다.

⚠️ 맥 스크린샷은 1280×800 · 1440×900 · 2560×1600 · 2880×1800 중 하나여야 하고,
   **한 벌 안에서는 크기가 같아야 한다.** 여기서는 2880×1800 로 통일한다.
⚠️ 말(헤드라인·서브카피)은 `headlines.json` 한 곳에만 있다. 언어마다 따로 썼다.
"""
import html as htmllib
import json
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent
RAW = ROOT / "raw"
OUT = ROOT / "marketing"
WORK = ROOT / ".html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

W, H = 2880, 1800
ACCENT = "#494d79"          # 앱 버튼·토글 색을 그대로 가져왔다

# (출력이름, 원본파일) — 스토어에 걸리는 순서 그대로. 말은 headlines.json 의 같은 순서.
LAYOUT = [
    ("01-panel", "03-panel.png"),
    ("02-menubar", "02-popover.png"),
    ("03-list", "01-list.png"),
    ("04-clipboard", "04-clipboard.png"),
    ("05-shortcuts", "05-shortcuts.png"),
    ("06-icloud", "06-icloud.png"),
]
HEADLINES = json.loads((ROOT / "headlines.json").read_text(encoding="utf-8"))

# 배경 색조를 장마다 조금씩 달리해 여섯 장이 한 벌로 보이되 단조롭지 않게.
TINTS = ["#eef0f8", "#f1eef6", "#eef4f6", "#f3f1ec", "#eef0f8", "#eff2f5"]

PAGE = """<!doctype html><html lang="{lang}"><meta charset="utf-8">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  body {{
    background:
      radial-gradient(120% 90% at 50% -10%, #ffffff 0%, {tint} 55%, {tint2} 100%);
    font-family: -apple-system, "SF Pro Display", "Helvetica Neue", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", sans-serif;
    display:flex; flex-direction:column; align-items:center;
    padding:150px 120px 130px;
  }}
  h1 {{
    font-size:{hsize}px; font-weight:700; letter-spacing:-3px; line-height:1.14;
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


def render(cmd, out, limit=60):
    """Chrome 을 띄워 out 이 다 써질 때까지 기다린다.
    요즘 Chrome 은 그림을 저장하고도 끝나지 않을 때가 있어, 파일 크기가 멈추면 직접 끝낸다."""
    out.unlink(missing_ok=True)
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sizes = []
    try:
        for _ in range(limit * 4):
            time.sleep(0.25)
            sizes.append(out.stat().st_size if out.exists() else 0)
            if len(sizes) > 3 and sizes[-1] > 0 and sizes[-1] == sizes[-2] == sizes[-3]:
                return True
            if proc.poll() is not None and not out.exists():
                return False
        return False
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        # 죽은 Chrome 이 남긴 프로필 잠금이 있으면 다음 실행이 곧바로 실패한다
        for lock in (WORK / "chrome").glob("Singleton*"):
            lock.unlink(missing_ok=True)


def build(locale, html_only=False):
    src_dir = RAW / locale
    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)

    for i, ((name, src), (headline, sub)) in enumerate(zip(LAYOUT, HEADLINES[locale])):
        img = src_dir / src
        if not img.exists():
            print(f"  ✗ {name} — 원본 없음: {img}")
            continue
        # 긴 헤드라인은 글씨를 줄여 한 줄에 둔다 (두 줄이면 창이 작아진다)
        hsize = 112 if len(headline) <= 26 else max(84, int(112 * 26 / len(headline)))
        html = WORK / f"{locale}-{name}.html"
        html.write_text(PAGE.format(
            W=W, H=H, tint=TINTS[i], tint2=TINTS[i], accent=ACCENT, lang=locale, hsize=hsize,
            headline=htmllib.escape(headline), sub=htmllib.escape(sub), img=img.as_uri()), encoding="utf-8")
        if html_only:
            print(f"  · {html}")
            continue
        out = out_dir / f"{name}.png"
        cmd = [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
               f"--user-data-dir={WORK / 'chrome'}",   # 다른 Chrome 과 섞이지 않게
               f"--screenshot={out}", f"--window-size={W},{H}",
               "--default-background-color=00000000", html.as_uri()]
        for attempt in range(3):              # 헤드리스 Chrome 이 가끔 그냥 실패한다
            if render(cmd, out):
                break
        else:
            sys.exit(f"Chrome 렌더링 실패: {out}")
        print(f"  ✓ {locale}/{name}.png")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    html_only = "--html" in sys.argv
    if not pathlib.Path(CHROME).exists():
        sys.exit(f"Chrome 이 없다: {CHROME}")
    for loc in (args or list(HEADLINES)):
        print(f"── {loc} ──")
        build(loc, html_only)
