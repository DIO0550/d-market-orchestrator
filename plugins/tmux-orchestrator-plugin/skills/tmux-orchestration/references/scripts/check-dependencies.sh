#!/bin/bash
# check-dependencies.sh
# タスク依存グラフと完了マーカーを照合して、実行可能なタスクを出力する
#
# 使用方法:
#   check-dependencies.sh <session-dir>
#
# 入力:
#   {session-dir}/.deps/tasks.json - タスク依存グラフ
#   {session-dir}/.status/*.done   - 完了マーカーファイル
#
# 出力:
#   実行可能なタスクのIDを1行ずつ出力
#
# tasks.json のフォーマット:
#   {
#     "tasks": [
#       {
#         "id": "1",
#         "subject": "タスクの件名",
#         "status": "pending",
#         "blockedBy": [],
#         "cli": "claude"
#       }
#     ]
#   }

set -euo pipefail

SESSION_DIR="${1:-}"

if [ -z "$SESSION_DIR" ]; then
  echo "Usage: check-dependencies.sh <session-dir>"
  exit 1
fi

TASKS_FILE="${SESSION_DIR}/.deps/tasks.json"
STATUS_DIR="${SESSION_DIR}/.status"

if [ ! -f "$TASKS_FILE" ]; then
  echo "Error: Tasks file not found: $TASKS_FILE" >&2
  exit 1
fi

# jq がインストールされているか確認
if ! command -v jq &>/dev/null; then
  echo "Error: jq is not installed. Install with: brew install jq" >&2
  exit 1
fi

# 各タスクについて実行可能性を判定
TASK_COUNT=$(jq '.tasks | length' "$TASKS_FILE")

for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".tasks[$i].id" "$TASKS_FILE")
  STATUS=$(jq -r ".tasks[$i].status" "$TASKS_FILE")

  # pending でないタスクはスキップ
  if [ "$STATUS" != "pending" ]; then
    continue
  fi

  # blockedBy のタスクがすべて完了しているか確認
  BLOCKED_BY_COUNT=$(jq ".tasks[$i].blockedBy | length" "$TASKS_FILE")
  ALL_DONE=true

  for j in $(seq 0 $((BLOCKED_BY_COUNT - 1))); do
    BLOCKER_ID=$(jq -r ".tasks[$i].blockedBy[$j]" "$TASKS_FILE")
    DONE_FILE="${STATUS_DIR}/task-${BLOCKER_ID}-task-manager.done"

    if [ ! -f "$DONE_FILE" ]; then
      ALL_DONE=false
      break
    fi
  done

  if [ "$ALL_DONE" = true ]; then
    echo "$TASK_ID"
  fi
done
