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

# ステータスディレクトリがなければ作成
mkdir -p "$STATUS_DIR"

while true; do
  clear
  echo "========================================"
  echo "  Orchestration Status Monitor"
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

      if [ -f "$EXIT_FILE" ]; then
        EXIT_CODE=$(grep 'AGENT_EXIT_CODE=' "$EXIT_FILE" 2>/dev/null | cut -d'=' -f2 || echo "?")
        if [ "$EXIT_CODE" = "0" ]; then
          echo "  ✅ [DONE] ${AGENT}"
          DONE_COUNT=$((DONE_COUNT + 1))
        else
          echo "  ❌ [FAIL] ${AGENT} (exit: ${EXIT_CODE})"
          FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
      else
        echo "  ✅ [DONE] ${AGENT}"
        DONE_COUNT=$((DONE_COUNT + 1))
      fi
    done
  fi

  # 実行中のエージェント（プロンプトファイルがあるが .done がないもの）
  if ls "${PROMPTS_DIR}"/*-prompt.md 1>/dev/null 2>&1; then
    for prompt_file in "${PROMPTS_DIR}"/*-prompt.md; do
      AGENT=$(basename "$prompt_file" -prompt.md)
      if [ ! -f "${STATUS_DIR}/${AGENT}.done" ]; then
        echo "  🔄 [RUNNING] ${AGENT}"
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
