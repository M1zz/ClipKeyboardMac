#!/usr/bin/env python3
"""앱스토어 촬영 준비 / 원복 — 실데이터를 지키면서 데모 상태로 갈아끼운다.

    python3 scripts/shoot_prepare.py backup            # 컨테이너 통째로 백업(체크섬 포함)
    python3 scripts/shoot_prepare.py demo ko|en        # 데모 데이터 + 촬영용 설정 적용
    python3 scripts/shoot_prepare.py verify            # 동기화가 정말 멎었는지 확인
    python3 scripts/shoot_prepare.py restore           # 백업에서 원상복구 + 체크섬 대조

⚠️ 이 앱은 **App Sandbox** 다. 앱이 읽는 설정은 컨테이너 안의
   `Library/Preferences/group.com.Ysoup.TokenMemo.plist` 이고,
   `defaults write group.com.Ysoup.TokenMemo …` 는 **다른 파일**(`~/Library/Preferences/…`)에
   쓴다. 2026-09-09 에 이걸 혼동해 동기화를 못 막았고, 실제 메모 37건에 삭제 표식이 생겨
   iCloud 로 올라갔다. 그래서 이 스크립트는 `defaults` 를 쓰지 않고 plist 를 직접 고친다.

⚠️ 방어가 둘이다:
   1) `memoSyncEnabled = false` — 엔진 자체를 재운다.
   2) `sync.shadow = {}`      — 만에 하나 엔진이 돌아도 삭제는 만들어질 수 없다.
      (MemoSyncCore.computeChanges 는 **shadow 에 있는데 로컬에 없는 id** 만 삭제로 본다)
"""
import json
import os
import plistlib
import shutil
import subprocess
import sys
from datetime import datetime

GROUP = "group.com.Ysoup.TokenMemo"
CONTAINER = os.path.expanduser(f"~/Library/Group Containers/{GROUP}")
PREFS = os.path.join(CONTAINER, "Library/Preferences", f"{GROUP}.plist")
BACKUP_ROOT = os.path.expanduser("~/ClipKeyboard-촬영백업")
DATA_FILES = ("memos.data", "clipboard.history.data")

CATEGORIES = {"ko": ["업무", "개인", "여행"], "en": ["Work", "Personal", "Travel"]}


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True)


def app_running():
    return bool(sh("pgrep", "-f", "ClipKeyboard.tap").stdout.strip())


def require_app_closed():
    if app_running():
        sys.exit("❌ 앱이 실행 중이다. 먼저 종료할 것: pkill -f ClipKeyboard.tap")


def read_prefs():
    xml = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", PREFS],
                         capture_output=True).stdout
    return plistlib.loads(xml)


def write_prefs(pl):
    with open(PREFS, "wb") as f:
        plistlib.dump(pl, f)
    sh("killall", "cfprefsd")


def checksums():
    out = {}
    for root, _, files in os.walk(CONTAINER):
        for name in files:
            if name.endswith((".data", ".plist")):
                p = os.path.join(root, name)
                out[os.path.relpath(p, CONTAINER)] = sh("shasum", p).stdout.split()[0]
    return out


def cmd_backup():
    require_app_closed()
    dest = os.path.join(BACKUP_ROOT, datetime.now().strftime("%Y%m%d-%H%M%S"))
    os.makedirs(dest, exist_ok=True)
    subprocess.run(["ditto", CONTAINER, os.path.join(dest, "container")], check=True)
    with open(os.path.join(dest, "checksums.json"), "w") as f:
        json.dump(checksums(), f, indent=2, ensure_ascii=False)
    with open(os.path.join(BACKUP_ROOT, "LATEST"), "w") as f:
        f.write(dest)
    print(f"✅ 백업: {dest}")
    print(f"   메모 {len(json.load(open(os.path.join(CONTAINER,'memos.data'))))}건")


def latest_backup():
    with open(os.path.join(BACKUP_ROOT, "LATEST")) as f:
        return f.read().strip()


def cmd_demo(locale):
    require_app_closed()
    if not os.path.exists(os.path.join(BACKUP_ROOT, "LATEST")):
        sys.exit("❌ 백업이 없다. 먼저 `shoot_prepare.py backup` 을 실행할 것.")

    here = os.path.dirname(os.path.abspath(__file__))
    subprocess.run([sys.executable, os.path.join(here, "make_demo_data.py"), locale], check=True)

    pl = read_prefs()
    # ── 방어 1·2 ────────────────────────────────────────────────────────────
    pl["memoSyncEnabled"] = False
    pl["memoSync.cloudAdopted.v1"] = True     # iCloud KV 가 다시 켜는 경로를 막는다
    pl["sync.shadow"] = json.dumps({}).encode()
    pl["sync.tombstones"] = json.dumps({}).encode()
    # ── 촬영용 화면 구성 ────────────────────────────────────────────────────
    pl["category.feature.enabled.v1"] = True
    pl["mac.category.followPhoneTabs.v1"] = True
    pl["userDefinedCategories_v1"] = CATEGORIES[locale]
    pl["enabledBuiltInCategories_v1"] = ["templates"]
    pl["hiddenCategoryTabs_v1"] = []
    pl["userCategoryIcons_v1"] = dict(zip(
        CATEGORIES[locale], ["briefcase.fill", "person.fill", "airplane"]))
    write_prefs(pl)
    print(f"✅ {locale} 데모 적용 · 동기화 차단(memoSyncEnabled=false, shadow 비움)")


def cmd_verify():
    """앱을 띄운 뒤 실행할 것 — 동기화가 실제로 멎었는지 본다."""
    pl = read_prefs()
    push, pull = pl.get("sync.lastPushAt"), pl.get("sync.lastPullAt")
    shadow = json.loads(pl.get("sync.shadow", b"{}"))
    print(f"memoSyncEnabled = {pl.get('memoSyncEnabled')}")
    print(f"shadow          = {len(shadow)}건")
    print(f"lastPushAt      = {push}")
    print(f"lastPullAt      = {pull}")
    if pl.get("memoSyncEnabled"):
        sys.exit("❌ 동기화가 켜져 있다. 즉시 앱을 종료할 것.")
    print("✅ 동기화 꺼짐 — 촬영해도 된다. (촬영 중 lastPushAt 이 움직이면 즉시 중단)")


def cmd_restore():
    require_app_closed()
    src = os.path.join(latest_backup(), "container")
    for name in DATA_FILES:
        shutil.copy2(os.path.join(src, name), os.path.join(CONTAINER, name))
    shutil.copy2(os.path.join(src, "Library/Preferences", f"{GROUP}.plist"), PREFS)
    sh("killall", "cfprefsd")

    expected = json.load(open(os.path.join(latest_backup(), "checksums.json")))
    actual = checksums()
    bad = {k: (v, actual.get(k)) for k, v in expected.items() if actual.get(k) != v}
    if bad:
        print("❌ 체크섬 불일치:", json.dumps(bad, indent=2, ensure_ascii=False))
        sys.exit(1)
    print(f"✅ 원상복구 완료 · 체크섬 {len(expected)}개 전부 일치")
    print(f"   메모 {len(json.load(open(os.path.join(CONTAINER,'memos.data'))))}건")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "backup":
        cmd_backup()
    elif cmd == "demo":
        cmd_demo(sys.argv[2] if len(sys.argv) > 2 else "ko")
    elif cmd == "verify":
        cmd_verify()
    elif cmd == "restore":
        cmd_restore()
    else:
        sys.exit(__doc__)
