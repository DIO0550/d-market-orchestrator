#!/bin/bash
# tmux-agent-launch.sh
# 指定されたCLIツールでエージェントをtmuxペインに起動する
#
# 使用方法:
#   tmux-agent-launch.sh <session> <window> <agent-name> <cli-tool> <prompt-file> <session-dir> [working-dir]
#
# 引数:
#   session     - tmuxセッション名（通知チャネル名にも使用）
#   window      - tmuxウィンドウ名（phase1, phase2, etc.）
#   agent-name  - エージェント名（explorer, planner, etc.）
#   cli-tool    - CLIツール名（claude, codex, copilot, またはカスタムコマンド）
#   prompt-file - プロンプトファイルのパス
#   session-dir - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   working-dir - 作業ディレクトリ（省略時はカレントディレクトリ）
#
# 完了時の動作:
#   1. {session-dir}/.status/{agent-name}.done - 完了マーカー作成
#   2. {session-dir}/.status/{agent-name}.exit - 終了コード記録
#   3. notify-parent.sh でオーケストレーターに完了を通知（ロック付き）

set -euo pipefail

SESSION="${1:-}"
WINDOW="${2:-}"
AGENT_NAME="${3:-}"
CLI_TOOL="${4:-}"
PROMPT_FILE="${5:-}"
SESSION_DIR="${6:-}"
WORKING_DIR="${7:-$(pwd)}"

if [ -z "$SESSION" ] || [ -z "$WINDOW" ] || [ -z "$AGENT_NAME" ] || [ -z "$CLI_TOOL" ] || [ -z "$PROMPT_FILE" ] || [ -z "$SESSION_DIR" ]; then
  echo "Usage: tmux-agent-launch.sh <session> <window> <agent-name> <cli-tool> <prompt-file> <session-dir> [working-dir]"
  exit 1
fi

# プロンプトファイルの存在確認
if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: Prompt file not found: $PROMPT_FILE"
  exit 1
fi

# ステータスディレクトリの確認
mkdir -p "${SESSION_DIR}/.status"

# 現在のペイン数を取得
PANE_COUNT=$(tmux list-panes -t "${SESSION}:${WINDOW}" 2>/dev/null | wc -l | tr -d ' ')

# 最初のペインが空（シェルプロンプトのみ）なら再利用、そうでなければ新しいペインを作成
if [ "$PANE_COUNT" -eq 1 ]; then
  # 最初のペインのコマンドを確認
  FIRST_PANE_CMD=$(tmux display-message -t "${SESSION}:${WINDOW}.0" -p '#{pane_current_command}' 2>/dev/null || echo "")
  if [ "$FIRST_PANE_CMD" = "zsh" ] || [ "$FIRST_PANE_CMD" = "bash" ] || [ "$FIRST_PANE_CMD" = "sh" ]; then
    TARGET_PANE="${SESSION}:${WINDOW}.0"
  else
    tmux split-window -t "${SESSION}:${WINDOW}" -v
    TARGET_PANE=$(tmux list-panes -t "${SESSION}:${WINDOW}" -F '#{pane_id}' | tail -1)
  fi
else
  tmux split-window -t "${SESSION}:${WINDOW}" -v
  TARGET_PANE=$(tmux list-panes -t "${SESSION}:${WINDOW}" -F '#{pane_id}' | tail -1)
fi

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

# CLIツールに応じたコマンドを構築
PROMPT_FILE_ABS=$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")
SESSION_DIR_ABS=$(cd "$(dirname "$SESSION_DIR")" && pwd)/$(basename "$SESSION_DIR")
STATUS_DIR_ABS="${SESSION_DIR_ABS}/.status"
SCRIPTS_DIR_ABS=$(cd "$(dirname "$0")" && pwd)

# 完了後の共通処理: .exit/.done 作成 → notify-parent.sh で親に通知
COMPLETION_SUFFIX="EXIT_CODE=\$?; echo \"AGENT_EXIT_CODE=\${EXIT_CODE}\" > '${STATUS_DIR_ABS}/${AGENT_NAME}.exit'; [ -f '${STATUS_DIR_ABS}/${AGENT_NAME}.done' ] || echo 'done' > '${STATUS_DIR_ABS}/${AGENT_NAME}.done'; echo '[${AGENT_NAME}] Completed (exit: '\${EXIT_CODE}')'; bash '${SCRIPTS_DIR_ABS}/notify-parent.sh' '${SESSION_DIR_ABS}' '${AGENT_NAME}' '${SESSION}'"

case "$CLI_TOOL" in
  claude)
    CMD="cd '${WORKING_DIR}' && claude --print --prompt-file '${PROMPT_FILE_ABS}' 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  codex)
    # Codex はプロンプトを引数として受け取る
    CMD="cd '${WORKING_DIR}' && codex --approval-mode full-auto --quiet \"\$(cat '${PROMPT_FILE_ABS}')\" 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  copilot)
    # GitHub Copilot CLI
    CMD="cd '${WORKING_DIR}' && cat '${PROMPT_FILE_ABS}' | gh copilot suggest -t shell 2>&1; ${COMPLETION_SUFFIX}"
    ;;
  *)
    # 汎用CLI: コマンドをそのまま使用
    CMD="cd '${WORKING_DIR}' && ${CLI_TOOL} '${PROMPT_FILE_ABS}' 2>&1; ${COMPLETION_SUFFIX}"
    ;;
esac

# ペインにコマンドを送信
tmux send-keys -t "$TARGET_PANE" "$CMD" C-m

echo "Agent '${AGENT_NAME}' launched in ${SESSION}:${WINDOW} using ${CLI_TOOL}"
echo "Prompt: ${PROMPT_FILE}"
echo "Completion marker: ${SESSION_DIR}/.status/${AGENT_NAME}.done"
