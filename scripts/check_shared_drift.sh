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

# iOS 원본이 큰 파일 안에 들어 있는 것들 — 선언 블록만 뽑아 비교한다.
for triple in "${EMBEDDED_MAP[@]}"; do
  mac_rel="${triple%%|*}"
  rest="${triple#*|}"
  ios_rel="${rest%%|*}"
  pattern="${rest#*|}"
  mac_file="$MAC_REPO/$mac_rel"
  ios_file="$IOS_REPO/$ios_rel"

  if [ ! -f "$ios_file" ]; then
    echo "❌ [drift-check] iOS 원본 없음: $ios_file"
    drift=1; continue
  fi

  ios_block="$(extract_block "$ios_file" "$pattern")"
  mac_block="$(extract_block "$mac_file" "$pattern")"

  if [ -z "$ios_block" ] || [ -z "$mac_block" ]; then
    echo "❌ [drift-check] 선언 블록을 찾지 못함: '$pattern' ($mac_rel ↔ iOS $ios_rel)"
    drift=1; continue
  fi
  if [ "$ios_block" != "$mac_block" ]; then
    echo "❌ [drift-check] 드리프트(블록): $mac_rel ↔ iOS $ios_rel 의 '$pattern'"
    drift=1
  fi
done

if [ "$drift" -ne 0 ]; then
  echo ""
  echo "🛑 공유 파일이 iOS 앱과 어긋났습니다. iOS를 원본으로 동기화하세요:"
  echo "    sh scripts/sync_shared.sh"
  echo "   (또는 Mac 쪽 변경을 iOS에도 반영한 뒤 재배포)"
  echo "   ⚠️ 블록 드리프트는 sync_shared.sh 가 못 고칩니다 — 직접 맞추세요."
  exit 1
fi

echo "✅ [drift-check] 공유 파일 ${#SHARED_MAP[@]}개 + 블록 ${#EMBEDDED_MAP[@]}개 모두 iOS 앱과 일치"
