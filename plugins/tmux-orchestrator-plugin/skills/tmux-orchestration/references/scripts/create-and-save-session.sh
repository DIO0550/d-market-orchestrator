#!/bin/bash
# create-and-save-session.sh
# tmux セッションを作成し、セッション名を設定ファイルに保存する
#
# 使用方法:
#   create-and-save-session.sh <session-id> <session-dir>
#
# 引数:
#   session-id    - セッション ID（例: 0001-feature-name）
#   session-dir   - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#
# 動作:
#   1. tmux-session-create.sh でセッションを作成
#   2. セッション名を .config/tmux-session.txt に保存
#   3. セッション名を標準出力に表示

set -euo pipefail

SESSION_ID="${1:-}"
SESSION_DIR="${2:-}"

if [ -z "$SESSION_ID" ] || [ -z "$SESSION_DIR" ]; then
  echo "Usage: create-and-save-session.sh <session-id> <session-dir>"
  exit 1
fi

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

OUTPUT=$(bash "${SCRIPTS_DIR}/tmux-session-create.sh" "orch-${SESSION_ID}")
TMUX_SESSION=$(echo "$OUTPUT" | grep "^TMUX_SESSION=" | cut -d= -f2)

echo "$TMUX_SESSION" > "${SESSION_DIR}/.config/tmux-session.txt"
echo "TMUX_SESSION=${TMUX_SESSION}"
