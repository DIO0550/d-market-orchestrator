#!/bin/bash
# tmux-agent-launch.sh
# 指定されたCLIツールでエージェントをtmuxペインに起動する
#
# 使用方法:
#   tmux-agent-launch.sh <session> <agent-name> <cli-tool> <task-spec-file> <session-dir> <parent-pane> [working-dir]
#
# 引数:
#   session        - tmuxセッション名
#   agent-name     - エージェント名（explorer, planner, etc.）
#   cli-tool       - CLIツール名（claude, codex, copilot, またはカスタムコマンド）
#   task-spec-file - タスクスペックファイルのパス（generate-agent-prompt.sh でプロンプトに変換）
#   session-dir    - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   parent-pane    - 通知先の親ペインID（オーケストレーターのペイン）
#   working-dir    - 作業ディレクトリ（省略時はカレントディレクトリ）
#
# 動作:
#   セッションの現在アクティブなウィンドウでペインを分割し、エージェントを起動する
#
# 完了時の動作:
#   1. {session-dir}/.status/{agent-name}.done - 完了マーカー作成
#   2. {session-dir}/.status/{agent-name}.exit - 終了コード記録
#   3. tmux send-keys で親ペインに完了通知を送信
#   4. ペインのシェルを終了（ペインが閉じる）

set -euo pipefail

SESSION="${1:-}"
AGENT_NAME="${2:-}"
CLI_TOOL="${3:-}"
TASK_SPEC_FILE="${4:-}"
SESSION_DIR="${5:-}"
PARENT_PANE="${6:-}"
WORKING_DIR="${7:-$(pwd)}"

if [ -z "$SESSION" ] || [ -z "$AGENT_NAME" ] || [ -z "$CLI_TOOL" ] || [ -z "$TASK_SPEC_FILE" ] || [ -z "$SESSION_DIR" ] || [ -z "$PARENT_PANE" ]; then
  echo "Usage: tmux-agent-launch.sh <session> <agent-name> <cli-tool> <task-spec-file> <session-dir> <parent-pane> [working-dir]"
  exit 1
fi

# タスクスペックファイルの存在確認
if [ ! -f "$TASK_SPEC_FILE" ]; then
  echo "Error: Task spec file not found: $TASK_SPEC_FILE"
  exit 1
fi

# ステータスディレクトリの確認
mkdir -p "${SESSION_DIR}/.status"

# 現在のウィンドウでペインを分割し、tiled レイアウトで均等配置
# -d: フォーカスを移動しない  -P -F: 新ペインIDを直接取得
TARGET_PANE=$(tmux split-window -t "${SESSION}" -v -d -P -F '#{pane_id}')
tmux select-layout -t "${SESSION}" tiled

# チーム設定からメンバー表示名を取得
DISPLAY_NAME="$AGENT_NAME"
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  MEMBER_NAME=$(jq -r ".members.\"${AGENT_NAME}\".name // empty" "$TEAM_CONFIG" 2>/dev/null)
  if [ -n "$MEMBER_NAME" ]; then
    DISPLAY_NAME="${MEMBER_NAME} (${AGENT_NAME})"
  fi
fi

# ペインのタイトルを設定
tmux select-pane -t "$TARGET_PANE" -T "$DISPLAY_NAME"

# task-spec からフルプロンプトを生成
PROMPT_FILE="${SESSION_DIR}/.prompts/${AGENT_NAME}-prompt.md"
GENERATE_SCRIPT="$(dirname "$0")/generate-agent-prompt.sh"
if [ -f "$GENERATE_SCRIPT" ]; then
  bash "$GENERATE_SCRIPT" "$AGENT_NAME" "$TASK_SPEC_FILE" "$PROMPT_FILE" "$(dirname "$0")"
else
  echo "Warning: generate-agent-prompt.sh not found, using task-spec as prompt" >&2
  mkdir -p "$(dirname "$PROMPT_FILE")"
  cp "$TASK_SPEC_FILE" "$PROMPT_FILE"
fi

# CLIツールに応じたコマンドを構築
PROMPT_FILE_ABS=$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")
SESSION_DIR_ABS=$(cd "$(dirname "$SESSION_DIR")" && pwd)/$(basename "$SESSION_DIR")
STATUS_DIR_ABS="${SESSION_DIR_ABS}/.status"
SCRIPTS_DIR="$(dirname "$SESSION_DIR_ABS")/scripts"

# team-config.json からシステムプロンプトを構築
SYSTEM_PROMPT=""
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
  MEMBER_CUSTOM_NAME=$(jq -r ".members.\"${AGENT_NAME}\".name // empty" "$TEAM_CONFIG" 2>/dev/null)
  MEMBER_PERSONALITY=$(jq -r ".members.\"${AGENT_NAME}\".personality // empty" "$TEAM_CONFIG" 2>/dev/null)

  if [ -n "$MEMBER_CUSTOM_NAME" ] && [ -n "$TEAM_NAME" ]; then
    SYSTEM_PROMPT="あなたは **${TEAM_NAME}** の **${MEMBER_CUSTOM_NAME}**（${AGENT_NAME}）エージェントです。"
  elif [ -n "$MEMBER_CUSTOM_NAME" ]; then
    SYSTEM_PROMPT="あなたは **${MEMBER_CUSTOM_NAME}**（${AGENT_NAME}）エージェントです。"
  else
    SYSTEM_PROMPT="あなたは ${AGENT_NAME} エージェントです。"
  fi

  if [ -n "$MEMBER_PERSONALITY" ]; then
    SYSTEM_PROMPT="${SYSTEM_PROMPT} あなたの性格・話し方: ${MEMBER_PERSONALITY}"
  fi
else
  SYSTEM_PROMPT="あなたは ${AGENT_NAME} エージェントです。"
fi

# 完了後の共通処理: .exit/.done 作成 → notify-parent.sh で排他的に通知 → ペイン終了
COMPLETION_SUFFIX="EXIT_CODE=\$?; echo \"AGENT_EXIT_CODE=\${EXIT_CODE}\" > '${STATUS_DIR_ABS}/${AGENT_NAME}.exit'; [ -f '${STATUS_DIR_ABS}/${AGENT_NAME}.done' ] || echo 'done' > '${STATUS_DIR_ABS}/${AGENT_NAME}.done'; bash '${SCRIPTS_DIR}/notify-parent.sh' '${SESSION_DIR_ABS}' '${AGENT_NAME}' '${PARENT_PANE}'; tmux kill-pane -t '${TARGET_PANE}' 2>/dev/null; exit"

case "$CLI_TOOL" in
  claude)
    # --append-system-prompt で組み込みシステムプロンプトを保持しつつ性格情報を追加
    CMD="cd '${WORKING_DIR}' && claude --permission-mode acceptEdits --append-system-prompt '${SYSTEM_PROMPT}' \"\$(cat '${PROMPT_FILE_ABS}')\" 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  codex)
    CMD="cd '${WORKING_DIR}' && codex --approval-mode full-auto --quiet \"\$(cat '${PROMPT_FILE_ABS}')\" 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  copilot)
    CMD="cd '${WORKING_DIR}' && cat '${PROMPT_FILE_ABS}' | gh copilot suggest -t shell 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  *)
    CMD="cd '${WORKING_DIR}' && ${CLI_TOOL} '${PROMPT_FILE_ABS}' 2>&1; ${COMPLETION_SUFFIX}"
    ;;
esac

# ペインにコマンドを送信
tmux send-keys -t "$TARGET_PANE" "$CMD" C-m

echo "Agent '${AGENT_NAME}' launched in ${SESSION} using ${CLI_TOOL}"
echo "Parent pane: ${PARENT_PANE}"
echo "Task spec: ${TASK_SPEC_FILE}"
echo "Generated prompt: ${PROMPT_FILE}"
echo "Completion marker: ${SESSION_DIR}/.status/${AGENT_NAME}.done"
