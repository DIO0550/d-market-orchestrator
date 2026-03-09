#!/bin/bash
# tmux-orchestrator-plugin: PermissionRequest hook
# Orchestrator関連のBashコマンドを自動許可する

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

# tmux コマンド
if echo "$COMMAND" | grep -qE '^tmux '; then
  allow
fi

# オーケストレータープラグインのスクリプト実行
if echo "$COMMAND" | grep -q 'tmux-orchestrator-plugin'; then
  allow
fi

# .orchestrator/ マーカー削除
if echo "$COMMAND" | grep -qE '^rm -f \.orchestrator/'; then
  allow
fi

# それ以外は通常のパーミッションフローへ
exit 0
