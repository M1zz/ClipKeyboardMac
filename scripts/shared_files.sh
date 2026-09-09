#!/bin/bash
# 공유 파일 매핑 — Mac(Shared/) ↔ iOS(ClipKeyboard/) 단일 출처 정의.
# check_shared_drift.sh / sync_shared.sh 가 공통으로 읽는다.
#
# iOS 앱을 "원본(source of truth)"으로 취급한다.
# 형식: "Mac상대경로|iOS상대경로"

# iOS 앱 리포 경로 (환경변수로 덮어쓸 수 있음)
IOS_REPO="${IOS_REPO:-$HOME/Documents/workspace/Auto/클립키보드}"
# 이 Mac 리포 경로 (스크립트 위치 기준 = scripts/의 부모)
MAC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SHARED_MAP=(
  "Shared/AppGroup.swift|ClipKeyboard/App/AppGroup.swift"
  "Shared/AppLog.swift|ClipKeyboard/App/AppLog.swift"
  "Shared/AppSymbol.swift|ClipKeyboard/App/AppSymbol.swift"
  "Shared/DefaultsKey.swift|ClipKeyboard/App/DefaultsKey.swift"
  "Shared/AppNotification.swift|ClipKeyboard/App/AppNotification.swift"
  "Shared/StorageFile.swift|ClipKeyboard/App/StorageFile.swift"
  "Shared/CategorySnapshot.swift|ClipKeyboard/Service/CategorySnapshot.swift"
  "Shared/CategoryBucketRule.swift|ClipKeyboard/App/CategoryBucketRule.swift"
  "Shared/RemoteFlagsService.swift|ClipKeyboard/Service/RemoteFlagsService.swift"
  # CloudKit 컨테이너를 메인 스레드 밖에서 만드는 관문. 위 두 파일이 이걸 부른다.
  # ⚠️ 빠뜨리면 맥만 `CKContainer(identifier:)` 를 메인에서 직접 불러 4.4.6 과 같은
  #    자리에서 멈춘다(iOS: docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md).
  "Shared/CloudKitContainerGate.swift|ClipKeyboard/Service/CloudKitContainerGate.swift"
  "Shared/MemoSyncCore.swift|ClipKeyboard/Service/MemoSyncCore.swift"
  "Shared/MemoSyncEngine.swift|ClipKeyboard/Service/MemoSyncEngine.swift"
)

# 파일 1:1 매핑이 불가능한 공유 코드.
# iOS 쪽 선언이 **더 큰 파일 안에** 들어 있어 파일째 비교하면 항상 드리프트로 뜬다.
# → 선언 블록(시작패턴 ~ 열 0의 `}`)만 뽑아서 비교한다.
#
# ⚠️ 이것도 엄연한 동기화 계약이다. `SampleMemoStorage` 의 키가 어긋나면 샘플 메모를
#    "사용자 데이터"로 오인해 기기 간에 퍼뜨린다(= 모르는 단축어가 섞여 보이는 그 버그).
#    맵에 없으면 아무도 안 지켜본다는 뜻이라 여기 넣어 둔다.
#
# 형식: "Mac상대경로|iOS상대경로|시작패턴"
EMBEDDED_MAP=(
  "Shared/SampleMemoStorage.swift|ClipKeyboard/App/Tips.swift|enum SampleMemoStorage {"
  # 카테고리 탭 구성 — 맥이 아이폰과 "같은 탭"을 보여주려면 이 두 선언이 같아야 한다.
  # 어긋나면 같은 계정인데 기기마다 탭 목록·순서·소속이 달라진다(사용자에겐 단축어가 사라진 것으로 보인다).
  "ClipKeyboard.tap/MacCategoryTabs.swift|ClipKeyboard/Screens/List/ClipKeyboardListViewModel.swift|enum BuiltInCategory: String, CaseIterable, Hashable {"
  "ClipKeyboard.tap/MacCategoryTabs.swift|ClipKeyboard/Screens/List/ClipKeyboardListViewModel.swift|enum CategoryTab: Hashable, Equatable {"
)

# 파일째 비교도, 선언 블록 비교도 불가능한 **쌍둥이 구현**.
# iOS 와 맥이 서로 다른 코드로 **같은 CloudKit 레코드**를 읽고 쓴다. 구현이 다른 건
# 괜찮지만 **레코드 필드 목록은 계약**이다. 한쪽에만 있는 필드가 생기면 그 데이터는
# 조용히 사라진다.
#
# ⚠️ 실제로 이 일이 있었다. 맥 CloudKitBackupService 에 `categoriesAsset` 이 없어서
#    맥에서 복원하면 카테고리 설정이 통째로 날아갔고(탭이 전부 사라짐), 맥이 올린
#    백업으로 아이폰이 복원하면 아이폰도 아이콘·순서·숨김을 잃었다.
#    이 파일이 어느 감시망에도 없어서 212줄이 벌어질 때까지 아무도 몰랐다.
#
# 형식: "Mac상대경로|iOS상대경로|설명"
CONTRACT_MAP=(
  "ClipKeyboard.tap/CloudKitBackupService.swift|ClipKeyboard/Service/CloudKitBackupService.swift|CloudKit 백업 레코드 필드"
)

# 맥에 아직 없는 것이 **의도된** 필드. 여기 적힌 것만 봐주고, 나머지는 실패시킨다.
# 줄일 때마다 하나씩 지워 나가는 목록이지 늘리는 목록이 아니다.
# (현재 비어 있다 — 맥이 iOS 백업 레코드의 모든 필드를 다룬다)
CONTRACT_IGNORE=()

# 소스에서 CloudKit 레코드 필드 이름만 뽑아 정렬해 낸다.  $1=파일
extract_record_fields() {
  grep -oE 'record\["[a-zA-Z]+"\]' "$1" | sed -E 's/record\["(.*)"\]/\1/' | sort -u
}

# 선언 블록만 뽑아 stdout 으로 낸다.  $1=파일  $2=시작패턴
extract_block() {
  awk -v start="$2" '
    !inblock && index($0, start) == 1 { inblock = 1; print; next }
    inblock { print; if ($0 ~ /^}/) exit }
  ' "$1"
}
