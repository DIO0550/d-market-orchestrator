#!/bin/bash
# tmux-orchestrator-plugin: PermissionRequest hook
# スキルで定義されたコマンドパターンに一致する場合のみ自動許可する

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Bash以外のツールはスキップ
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# 空コマンドはスキップ
if [ -z "$COMMAND" ]; then
  exit 0
fi

allow() {
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PermissionRequest",
      decision: {
        behavior: "allow"
      }
    }
  }'
  exit 0
}

# ============================================================
# 許可対象スクリプト（ホワイトリスト）
# スキルの references/scripts/ に定義されたもののみ
# ============================================================
ALLOWED_SCRIPTS=(
  generate-session-id.sh
  init-session.sh
  init-task.sh
  init-team-session.sh
  create-and-save-session.sh
  get-parent-pane.sh
  tmux-agent-launch.sh
  generate-agent-prompt.sh
  tmux-pane-presplit.sh
  read-agent-status.sh
  check-dependencies.sh
  complete-agent.sh
  notify-parent.sh
  tmux-session-create.sh
  tmux-session-destroy.sh
  tmux-result-collector.sh
  tmux-status-monitor.sh
)

# スクリプト実行: bash "$SCRIPTS_DIR/{script}.sh" ... のパターン
# $SCRIPTS_DIR は tmux-orchestrator-plugin 配下に解決されるため両方チェック
for script in "${ALLOWED_SCRIPTS[@]}"; do
  if echo "$COMMAND" | grep -qE "(bash|sh)[[:space:]]+.*tmux-orchestrator-plugin.*/${script}([[:space:]]|$)"; then
    allow
  fi
done

# ============================================================
# 許可対象 tmux サブコマンド（ホワイトリスト）
# スキルで使用されるサブコマンドのみ
# ============================================================
ALLOWED_TMUX_SUBCMDS=(
  "-V"
  "display-message"
  "split-window"
  "select-layout"
  "select-pane"
  "send-keys"
  "kill-pane"
  "kill-session"
  "has-session"
  "new-session"
  "ls"
  "attach"
  "switch-client"
)

for subcmd in "${ALLOWED_TMUX_SUBCMDS[@]}"; do
  if echo "$COMMAND" | grep -qE "^tmux[[:space:]]+${subcmd}([[:space:]]|$)"; then
    allow
  fi
done

# ============================================================
# .orchestrator/ マーカー削除
# rm -f .orchestrator/... のパターンのみ（-rf は不許可）
# ============================================================
if echo "$COMMAND" | grep -qE '^rm -f \.orchestrator/'; then
  allow
fi

# ============================================================
# mkdir: .orchestrator/ 配下のディレクトリ作成のみ
# ============================================================
if echo "$COMMAND" | grep -qE '^mkdir -p .*\.orchestrator/'; then
  allow
fi

# それ以外は通常のパーミッションフローへ
exit 0
