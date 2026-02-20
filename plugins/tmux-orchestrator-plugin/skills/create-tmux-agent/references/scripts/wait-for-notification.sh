#!/bin/bash
# wait-for-notification.sh
# エージェントの完了通知を待機する（イベント駆動、ポーリングなし）
#
# 使用方法:
#   wait-for-notification.sh <session-dir> <agent-name> <tmux-session> [timeout-seconds]
#
# 引数:
#   session-dir     - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name      - 待機対象のエージェント名（explorer, planner, etc.）
#   tmux-session    - tmux セッション名（orch-{SESSION_ID}）
#   timeout-seconds - タイムアウト秒数（デフォルト: 600秒 = 10分）
#
# 終了コード:
#   0 - エージェントが正常に完了
#   1 - タイムアウト
#   2 - エージェントがエラーで終了（終了コード != 0）

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
TMUX_SESSION="${3:-}"
TIMEOUT="${4:-600}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ] || [ -z "$TMUX_SESSION" ]; then
  echo "Usage: wait-for-notification.sh <session-dir> <agent-name> <tmux-session> [timeout-seconds]"
  exit 1
fi

STATUS_DIR="${SESSION_DIR}/.status"
DONE_FILE="${STATUS_DIR}/${AGENT_NAME}.done"
EXIT_FILE="${STATUS_DIR}/${AGENT_NAME}.exit"
CHANNEL="orch-done-${TMUX_SESSION}-${AGENT_NAME}"

# 既に完了している場合はシグナル待ちをスキップ
if [ -f "$DONE_FILE" ]; then
  echo "ALREADY_DONE: ${AGENT_NAME}"
else
  echo "Waiting for ${AGENT_NAME} on channel: ${CHANNEL} (timeout: ${TIMEOUT}s)..."

  # tmux wait-for でブロック（タイムアウト付き）
  # tmux wait-for 自体にはタイムアウト機能がないため、バックグラウンド + wait で実装
  (tmux wait-for "$CHANNEL" 2>/dev/null) &
  WAIT_PID=$!

  (sleep "$TIMEOUT" && kill "$WAIT_PID" 2>/dev/null) &
  TIMEOUT_PID=$!

  if wait "$WAIT_PID" 2>/dev/null; then
    kill "$TIMEOUT_PID" 2>/dev/null || true
    wait "$TIMEOUT_PID" 2>/dev/null || true
  else
    kill "$TIMEOUT_PID" 2>/dev/null || true
    wait "$TIMEOUT_PID" 2>/dev/null || true
    echo "TIMEOUT: ${AGENT_NAME} did not complete within ${TIMEOUT}s"
    exit 1
  fi
fi

# 終了コードを確認
if [ -f "$EXIT_FILE" ]; then
  AGENT_EXIT_CODE=$(grep 'AGENT_EXIT_CODE=' "$EXIT_FILE" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
  echo "COMPLETED: ${AGENT_NAME} (exit code: ${AGENT_EXIT_CODE})"

  if [ "$AGENT_EXIT_CODE" != "0" ] && [ "$AGENT_EXIT_CODE" != "unknown" ]; then
    exit 2
  fi
else
  echo "COMPLETED: ${AGENT_NAME} (no exit code file)"
fi

exit 0
