#!/bin/bash
# notify-parent.sh
# エージェント完了時に親ペインへ send-keys で通知する
#
# 使用方法:
#   notify-parent.sh <session-dir> <agent-name> <parent-pane>
#
# 引数:
#   session-dir   - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name    - エージェント名（explorer, planner, etc.）
#   parent-pane   - 通知先の親ペインID
#
# 動作:
#   .done ファイルの状態値を読み取り、親ペインに [AGENT_COMPLETE] メッセージを送信する。
#   オーケストレーター（Claude Code）はこのメッセージを入力として受け取り、次のアクションに進む。

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
PARENT_PANE="${3:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ] || [ -z "$PARENT_PANE" ]; then
  echo "Usage: notify-parent.sh <session-dir> <agent-name> <parent-pane>"
  exit 1
fi

DONE_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.done"
STATUS=$(cat "$DONE_FILE" 2>/dev/null || echo "done")

tmux send-keys -t "$PARENT_PANE" "[AGENT_COMPLETE] ${AGENT_NAME} ${STATUS}" Enter

echo "[${AGENT_NAME}] Notification sent to pane ${PARENT_PANE}: ${STATUS}"
