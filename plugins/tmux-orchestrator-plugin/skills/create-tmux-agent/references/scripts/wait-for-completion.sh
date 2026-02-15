#!/bin/bash
# wait-for-completion.sh
# エージェントの完了を .done マーカーファイルのポーリングで待機する
#
# 使用方法:
#   wait-for-completion.sh <session-dir> <agent-name> [timeout-seconds]
#
# 引数:
#   session-dir     - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name      - エージェント名（explorer, planner, etc.）
#   timeout-seconds - タイムアウト秒数（デフォルト: 600秒 = 10分）
#
# 終了コード:
#   0 - エージェントが正常に完了
#   1 - タイムアウト
#   2 - エージェントがエラーで終了（終了コード != 0）

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
TIMEOUT="${3:-600}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ]; then
  echo "Usage: wait-for-completion.sh <session-dir> <agent-name> [timeout-seconds]"
  exit 1
fi

DONE_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.done"
EXIT_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.exit"

ELAPSED=0
INTERVAL=2

echo "Waiting for ${AGENT_NAME} to complete (timeout: ${TIMEOUT}s)..."

while [ ! -f "$DONE_FILE" ]; do
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "TIMEOUT: ${AGENT_NAME} did not complete within ${TIMEOUT}s"
    exit 1
  fi

  # 進捗表示（30秒ごと）
  if [ $((ELAPSED % 30)) -eq 0 ]; then
    echo "  Still waiting for ${AGENT_NAME}... (${ELAPSED}s elapsed)"
  fi
done

# 終了コードを確認
if [ -f "$EXIT_FILE" ]; then
  AGENT_EXIT_CODE=$(grep 'AGENT_EXIT_CODE=' "$EXIT_FILE" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
  echo "COMPLETED: ${AGENT_NAME} (exit code: ${AGENT_EXIT_CODE}, elapsed: ${ELAPSED}s)"

  if [ "$AGENT_EXIT_CODE" != "0" ] && [ "$AGENT_EXIT_CODE" != "unknown" ]; then
    exit 2
  fi
else
  echo "COMPLETED: ${AGENT_NAME} (no exit code file, elapsed: ${ELAPSED}s)"
fi

exit 0
