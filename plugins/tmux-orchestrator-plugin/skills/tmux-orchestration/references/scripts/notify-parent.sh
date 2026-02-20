#!/bin/bash
# notify-parent.sh
# エージェント完了時に待機側へシグナルを送信する
#
# 使用方法:
#   notify-parent.sh <session-dir> <agent-name> <tmux-session>
#
# 引数:
#   session-dir   - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name    - エージェント名（explorer, planner, etc.）
#   tmux-session  - tmux セッション名（orch-{SESSION_ID}）
#
# 動作:
#   エージェント固有の tmux wait-for チャネルにシグナルを送信する。
#   待機側（wait-for-notification.sh）が同じチャネルでブロックしており、
#   シグナル受信後に .done/.exit を読み取って処理する。
#
#   チャネルはエージェント単位で分離されるため、
#   複数エージェントが同時に完了しても他のチャネルに干渉しない。

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
TMUX_SESSION="${3:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ] || [ -z "$TMUX_SESSION" ]; then
  echo "Usage: notify-parent.sh <session-dir> <agent-name> <tmux-session>"
  exit 1
fi

CHANNEL="orch-done-${TMUX_SESSION}-${AGENT_NAME}"

# tmux wait-for シグナルを送信
tmux wait-for -S "$CHANNEL" 2>/dev/null || true

echo "[${AGENT_NAME}] Notification sent on channel: ${CHANNEL}"
