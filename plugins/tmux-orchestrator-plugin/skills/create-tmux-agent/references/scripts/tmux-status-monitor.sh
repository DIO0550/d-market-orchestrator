#!/bin/bash
# tmux-status-monitor.sh
# エージェントの完了状況をリアルタイムで表示するモニター
#
# 使用方法:
#   tmux-status-monitor.sh <session-dir>
#
# Ctrl+C で停止

set -euo pipefail

SESSION_DIR="${1:-}"

if [ -z "$SESSION_DIR" ]; then
  echo "Usage: tmux-status-monitor.sh <session-dir>"
  exit 1
fi

STATUS_DIR="${SESSION_DIR}/.status"
PROMPTS_DIR="${SESSION_DIR}/.prompts"
TEAM_CONFIG=".orchestrator/team-config.json"

# ステータスディレクトリがなければ作成
mkdir -p "$STATUS_DIR"

# チーム設定の読み込み
TEAM_NAME=""
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
fi

# エージェント内部識別子から表示名を取得
get_display_name() {
  local agent_id="$1"
  if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
    local name
    name=$(jq -r ".members.\"${agent_id}\".name // empty" "$TEAM_CONFIG" 2>/dev/null)
    if [ -n "$name" ]; then
      echo "${name} (${agent_id})"
      return
    fi
  fi
  echo "$agent_id"
}

while true; do
  clear
  echo "========================================"
  if [ -n "$TEAM_NAME" ]; then
    echo "  ${TEAM_NAME} - Status Monitor"
  else
    echo "  Orchestration Status Monitor"
  fi
  echo "========================================"
  echo "Session: $(basename "$SESSION_DIR")"
  echo "Time:    $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------"
  echo ""

  DONE_COUNT=0
  FAIL_COUNT=0
  RUNNING_COUNT=0

  # 完了したエージェント
  if ls "${STATUS_DIR}"/*.done 1>/dev/null 2>&1; then
    for done_file in "${STATUS_DIR}"/*.done; do
      AGENT=$(basename "$done_file" .done)
      EXIT_FILE="${STATUS_DIR}/${AGENT}.exit"

      AGENT_DISPLAY=$(get_display_name "$AGENT")
      if [ -f "$EXIT_FILE" ]; then
        EXIT_CODE=$(grep 'AGENT_EXIT_CODE=' "$EXIT_FILE" 2>/dev/null | cut -d'=' -f2 || echo "?")
        if [ "$EXIT_CODE" = "0" ]; then
          echo "  ✅ [DONE] ${AGENT_DISPLAY}"
          DONE_COUNT=$((DONE_COUNT + 1))
        else
          echo "  ❌ [FAIL] ${AGENT_DISPLAY} (exit: ${EXIT_CODE})"
          FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
      else
        echo "  ✅ [DONE] ${AGENT_DISPLAY}"
        DONE_COUNT=$((DONE_COUNT + 1))
      fi
    done
  fi

  # 実行中のエージェント（プロンプトファイルがあるが .done がないもの）
  if ls "${PROMPTS_DIR}"/*-prompt.md 1>/dev/null 2>&1; then
    for prompt_file in "${PROMPTS_DIR}"/*-prompt.md; do
      AGENT=$(basename "$prompt_file" -prompt.md)
      if [ ! -f "${STATUS_DIR}/${AGENT}.done" ]; then
        AGENT_DISPLAY=$(get_display_name "$AGENT")
        echo "  🔄 [RUNNING] ${AGENT_DISPLAY}"
        RUNNING_COUNT=$((RUNNING_COUNT + 1))
      fi
    done
  fi

  echo ""
  echo "----------------------------------------"
  echo "Done: ${DONE_COUNT}  Failed: ${FAIL_COUNT}  Running: ${RUNNING_COUNT}"
  echo "----------------------------------------"
  echo "Press Ctrl+C to stop monitoring"

  sleep 3
done
