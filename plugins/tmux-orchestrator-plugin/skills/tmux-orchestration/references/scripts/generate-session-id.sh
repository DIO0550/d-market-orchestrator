#!/bin/bash
# generate-session-id.sh
# .orchestrator/ 内の既存セッションをスキャンして次のセッションIDを生成する
#
# 使用方法:
#   generate-session-id.sh <feature-name>
#
# 引数:
#   feature-name - 機能名（英小文字ハイフン区切り、例: user-auth）
#
# 出力:
#   SESSION_ID={nnnn}-{feature-name}
#
# 例:
#   generate-session-id.sh user-auth
#   → SESSION_ID=0001-user-auth

set -euo pipefail

FEATURE_NAME="${1:-}"

if [ -z "$FEATURE_NAME" ]; then
  echo "Usage: generate-session-id.sh <feature-name>"
  echo "Example: generate-session-id.sh user-auth"
  exit 1
fi

# 既存セッションから最大連番を取得（なければ 0）
MAX_NUM=$(ls -d .orchestrator/????-* 2>/dev/null | sed 's/.*\///' | cut -d'-' -f1 | sort -n | tail -1 || echo "0")
MAX_NUM=${MAX_NUM:-0}

# ゼロ埋め除去して算術計算
NEXT_NUM=$((10#$MAX_NUM + 1))
NEXT_ID=$(printf "%04d" "$NEXT_NUM")

SESSION_ID="${NEXT_ID}-${FEATURE_NAME}"

echo "SESSION_ID=${SESSION_ID}"
