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
  "Shared/AppGroup.swift|ClipKeyboard/AppGroup.swift"
  "Shared/AppSymbol.swift|ClipKeyboard/AppSymbol.swift"
  "Shared/DefaultsKey.swift|ClipKeyboard/DefaultsKey.swift"
  "Shared/AppNotification.swift|ClipKeyboard/AppNotification.swift"
  "Shared/StorageFile.swift|ClipKeyboard/StorageFile.swift"
  "Shared/MemoSyncCore.swift|ClipKeyboard/Service/MemoSyncCore.swift"
  "Shared/MemoSyncEngine.swift|ClipKeyboard/Service/MemoSyncEngine.swift"
)
