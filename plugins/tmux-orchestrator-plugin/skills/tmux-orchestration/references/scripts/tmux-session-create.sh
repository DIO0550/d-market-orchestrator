#!/bin/bash
# tmux-session-create.sh
# オーケストレーション用のウィンドウを作成する
#
# 使用方法:
#   tmux-session-create.sh <session-name> [team-config-path]
#
# 動作:
#   tmux 内で実行 → 現在のセッションに "agents" ウィンドウを1つ追加
#   tmux 外で実行 → 新しいセッションを作成し "agents" ウィンドウを追加
#
# エージェントは全て "agents" ウィンドウにペイン分割（tiled レイアウト）で起動される

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

AGENTS_WINDOW="agents"

if [ -n "${TMUX:-}" ]; then
  # ===== tmux 内: 現在のセッションに agents ウィンドウを追加 =====
  CURRENT_SESSION=$(tmux display-message -p '#{session_name}')

  if ! tmux list-windows -t "$CURRENT_SESSION" -F '#{window_name}' | grep -qx "$AGENTS_WINDOW"; then
    tmux new-window -t "$CURRENT_SESSION" -n "$AGENTS_WINDOW"
  fi

  # 元のウィンドウに戻る（オーケストレーターが動作中のウィンドウ）
  tmux last-window -t "$CURRENT_SESSION"

  echo "TMUX_SESSION=${CURRENT_SESSION}"
  echo "Window '${AGENTS_WINDOW}' added to session '${CURRENT_SESSION}'."

else
  # ===== tmux 外: 新しいセッションを作成 =====
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Warning: Session '$SESSION_NAME' already exists. Killing it."
    tmux kill-session -t "$SESSION_NAME"
  fi

  # セッション作成（最初のウィンドウを agents にする）
  tmux new-session -d -s "$SESSION_NAME" -n "$AGENTS_WINDOW"

  echo "TMUX_SESSION=${SESSION_NAME}"
  echo "tmux session '$SESSION_NAME' created with window '${AGENTS_WINDOW}'."
  echo "Attach with: tmux attach -t $SESSION_NAME"
fi
