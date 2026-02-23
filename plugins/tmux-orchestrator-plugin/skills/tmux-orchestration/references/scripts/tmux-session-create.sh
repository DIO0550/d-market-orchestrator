#!/bin/bash
# tmux-session-create.sh
# オーケストレーション用の tmux セッション名を返す
#
# 使用方法:
#   tmux-session-create.sh <session-name> [team-config-path]
#
# 動作:
#   tmux 内で実行 → 現在のセッション名を返す（ウィンドウ作成不要）
#   tmux 外で実行 → 新しいセッションを作成しセッション名を返す

set -euo pipefail

SESSION_NAME="${1:-}"
TEAM_CONFIG="${2:-.orchestrator/team-config.json}"

if [ -z "$SESSION_NAME" ]; then
  echo "Usage: tmux-session-create.sh <session-name> [team-config-path]"
  echo "Example: tmux-session-create.sh orch-0001-user-auth"
  exit 1
fi

# チーム設定からセッション名プレフィックスを上書き
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
  if [ -n "$TEAM_NAME" ]; then
    SESSION_NAME=$(echo "$SESSION_NAME" | sed "s/^orch-/${TEAM_NAME}-/")
  fi
fi

# tmux がインストールされているか確認
if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is not installed."
  echo "Install with: brew install tmux (macOS) or apt install tmux (Ubuntu)"
  exit 1
fi

if [ -n "${TMUX:-}" ]; then
  # ===== tmux 内: 現在のセッション名を返す =====
  CURRENT_SESSION=$(tmux display-message -p '#{session_name}')

  echo "TMUX_SESSION=${CURRENT_SESSION}"
  echo "Using current session '${CURRENT_SESSION}'."

else
  # ===== tmux 外: 新しいセッションを作成 =====
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Warning: Session '$SESSION_NAME' already exists. Killing it."
    tmux kill-session -t "$SESSION_NAME"
  fi

  # セッション作成（デフォルトウィンドウ）
  tmux new-session -d -s "$SESSION_NAME"

  echo "TMUX_SESSION=${SESSION_NAME}"
  echo "tmux session '$SESSION_NAME' created."
  echo "Attach with: tmux attach -t $SESSION_NAME"
fi
