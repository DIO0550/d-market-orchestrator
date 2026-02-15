#!/bin/bash
# init-task.sh
# タスクごとのディレクトリ構造を初期化する
#
# 使用方法:
#   init-task.sh <session-dir> <task-id>
#
# 作成されるディレクトリ:
#   {session-dir}/task-{id}/implementer/
#   {session-dir}/task-{id}/test-runner/
#   {session-dir}/task-{id}/linter/
#   {session-dir}/task-{id}/code-reviewer/
#   {session-dir}/task-{id}/refactorer/
#   {session-dir}/task-{id}/debugger/
#   {session-dir}/task-{id}/task-manager/

set -euo pipefail

SESSION_DIR="${1:-}"
TASK_ID="${2:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$TASK_ID" ]; then
  echo "Usage: init-task.sh <session-dir> <task-id>"
  echo "Example: init-task.sh .orchestrator/0001-user-auth 1"
  exit 1
fi

TASK_DIR="${SESSION_DIR}/task-${TASK_ID}"

mkdir -p "$TASK_DIR"/{implementer,test-runner,linter,code-reviewer,refactorer,debugger,task-manager}

echo "Task directory initialized: $TASK_DIR"
