#!/bin/bash
# iOS 앱(원본) → Mac Shared/ 로 공유 파일을 재복사해 드리프트를 해소한다.
# check_shared_drift.sh 가 실패했을 때 이걸 돌려 맞춘다.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared_files.sh
source "$DIR/shared_files.sh"

if [ ! -d "$IOS_REPO" ]; then
  echo "❌ iOS 리포를 찾을 수 없습니다: $IOS_REPO (IOS_REPO 환경변수로 지정)"
  exit 1
fi

changed=0
for pair in "${SHARED_MAP[@]}"; do
  mac_rel="${pair%%|*}"
  ios_rel="${pair##*|}"
  if ! diff -q "$IOS_REPO/$ios_rel" "$MAC_REPO/$mac_rel" >/dev/null 2>&1; then
    cp "$IOS_REPO/$ios_rel" "$MAC_REPO/$mac_rel"
    echo "🔄 갱신: $mac_rel ← iOS $ios_rel"
    changed=1
  fi
done

[ "$changed" -eq 0 ] && echo "✅ 이미 모두 일치 — 변경 없음" || echo "✅ 동기화 완료 — 변경사항을 커밋하세요"

# 블록 단위 공유분은 자동 복사 대상이 아니다 — iOS 원본이 큰 파일 안에 있어
# 통째로 덮어쓰면 Mac 파일이 망가진다. 어긋났을 때만 알려 주고 손으로 맞추게 한다.
for triple in "${EMBEDDED_MAP[@]}"; do
  mac_rel="${triple%%|*}"
  rest="${triple#*|}"
  ios_rel="${rest%%|*}"
  pattern="${rest#*|}"

  if [ "$(extract_block "$IOS_REPO/$ios_rel" "$pattern")" \
     != "$(extract_block "$MAC_REPO/$mac_rel" "$pattern")" ]; then
    echo "⚠️  수동 조정 필요: $mac_rel 의 '$pattern' 이 iOS $ios_rel 와 다릅니다(자동 복사 불가)."
  fi
done
