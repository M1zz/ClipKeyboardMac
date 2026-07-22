#!/bin/bash
# 배포 전 게이트 — Shared/ 의 공유 파일이 iOS 앱 원본과 일치하는지 검사.
# 하나라도 다르면 실패(exit 1)해서 배포를 중단한다.
# fastlane/.env 의 PREDEPLOY_SCRIPT 로 연결됨.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared_files.sh
source "$DIR/shared_files.sh"

if [ ! -d "$IOS_REPO" ]; then
  echo "⚠️  [drift-check] iOS 리포를 찾을 수 없습니다: $IOS_REPO"
  echo "    IOS_REPO 환경변수로 경로를 지정하세요. (검사 건너뜀 → 배포 계속)"
  exit 0
fi

drift=0
for pair in "${SHARED_MAP[@]}"; do
  mac_rel="${pair%%|*}"
  ios_rel="${pair##*|}"
  mac_file="$MAC_REPO/$mac_rel"
  ios_file="$IOS_REPO/$ios_rel"

  if [ ! -f "$ios_file" ]; then
    echo "❌ [drift-check] iOS 원본 없음: $ios_file"
    drift=1; continue
  fi
  if ! diff -q "$ios_file" "$mac_file" >/dev/null 2>&1; then
    echo "❌ [drift-check] 드리프트: $mac_rel ↔ iOS $ios_rel"
    drift=1
  fi
done

if [ "$drift" -ne 0 ]; then
  echo ""
  echo "🛑 공유 파일이 iOS 앱과 어긋났습니다. iOS를 원본으로 동기화하세요:"
  echo "    sh scripts/sync_shared.sh"
  echo "   (또는 Mac 쪽 변경을 iOS에도 반영한 뒤 재배포)"
  exit 1
fi

echo "✅ [drift-check] 공유 파일 7개 모두 iOS 앱과 일치"
