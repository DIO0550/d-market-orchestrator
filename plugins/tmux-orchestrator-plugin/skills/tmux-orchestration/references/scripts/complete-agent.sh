#!/bin/bash
# complete-agent.sh
# エージェントの完了手順を1コマンドで実行する
#
# 使用方法:
#   complete-agent.sh <session-dir> <agent-name> <parent-pane> [status]
#
# 引数:
#   session-dir   - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name    - エージェント名（explorer, launcher, member-1, etc.）
#   parent-pane   - 通知先の親ペインID
#   status        - 状態値（省略時: done）
#
# 動作:
#   1. .done ファイルに状態値を書き出す
#   2. notify-parent.sh で親に完了を通知する
#   3. tmux kill-pane で自分のペインを終了する

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
PARENT_PANE="${3:-}"
STATUS="${4:-done}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ] || [ -z "$PARENT_PANE" ]; then
  echo "Usage: complete-agent.sh <session-dir> <agent-name> <parent-pane> [status]"
  exit 1
fi

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Step 1: 状態値を .done ファイルに書き出す
echo "$STATUS" > "${SESSION_DIR}/.status/${AGENT_NAME}.done"

# Step 2: 親に完了を通知する
bash "${SCRIPTS_DIR}/notify-parent.sh" "$SESSION_DIR" "$AGENT_NAME" "$PARENT_PANE"

# Step 3: 自分のペインを終了する
tmux kill-pane
