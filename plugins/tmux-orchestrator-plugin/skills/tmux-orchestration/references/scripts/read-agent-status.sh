#!/bin/bash
# read-agent-status.sh
# エージェントの完了ステータスと終了コードを読み取る
#
# 使用方法:
#   read-agent-status.sh <session-dir> <agent-name>
#
# 引数:
#   session-dir - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name  - エージェント名（explorer, planner, task-1-task-manager 等）
#
# 出力:
#   STATUS={状態値}         (.done ファイルの内容、未完了なら "pending")
#   AGENT_EXIT_CODE={code}  (.exit ファイルの内容、存在しなければ空行)
#
# 例:
#   read-agent-status.sh .orchestrator/0001-user-auth explorer
#   → STATUS=done
#   → AGENT_EXIT_CODE=0

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ]; then
  echo "Usage: read-agent-status.sh <session-dir> <agent-name>"
  exit 1
fi

DONE_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.done"
EXIT_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.exit"

if [ -f "$DONE_FILE" ]; then
  STATUS=$(cat "$DONE_FILE")
else
  STATUS="pending"
fi

EXIT_CODE=""
if [ -f "$EXIT_FILE" ]; then
  EXIT_CODE=$(grep -oP '(?<=AGENT_EXIT_CODE=)\d+' "$EXIT_FILE" 2>/dev/null || cat "$EXIT_FILE")
fi

echo "STATUS=${STATUS}"
echo "AGENT_EXIT_CODE=${EXIT_CODE}"
