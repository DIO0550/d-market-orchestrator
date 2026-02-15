#!/bin/bash
# tmux-result-collector.sh
# 全エージェントの結果を集約してサマリーファイルを生成する
#
# 使用方法:
#   tmux-result-collector.sh <session-dir>
#
# 出力:
#   {session-dir}/implementation-log.md

set -euo pipefail

SESSION_DIR="${1:-}"

if [ -z "$SESSION_DIR" ]; then
  echo "Usage: tmux-result-collector.sh <session-dir>"
  exit 1
fi

OUTPUT="${SESSION_DIR}/implementation-log.md"
TEAM_CONFIG=".orchestrator/team-config.json"

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

# チーム名の取得
TEAM_NAME=""
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
fi

{
  if [ -n "$TEAM_NAME" ]; then
    echo "# ${TEAM_NAME} - Implementation Log"
  else
    echo "# Implementation Log"
  fi
  echo ""
  echo "Session: $(basename "$SESSION_DIR")"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # Phase 1: 探索・計画
  echo "## Phase 1: 探索・計画"
  echo ""

  for dir in explorer planner plan-reviewer; do
    if [ -d "${SESSION_DIR}/${dir}" ]; then
      echo "### $(get_display_name "$dir")"
      echo ""
      for file in "${SESSION_DIR}/${dir}"/*.md; do
        if [ -f "$file" ]; then
          echo "#### $(basename "$file")"
          echo ""
          echo '```'
          head -30 "$file"
          echo '```'
          echo ""
        fi
      done
    fi
  done

  # Phase 2: 実装（タスクごと）
  echo "## Phase 2: 実装"
  echo ""

  for task_dir in "${SESSION_DIR}"/task-*; do
    if [ -d "$task_dir" ]; then
      TASK_ID=$(basename "$task_dir")
      echo "### ${TASK_ID}"
      echo ""

      for agent_dir in "${task_dir}"/*/; do
        if [ -d "$agent_dir" ]; then
          AGENT=$(basename "$agent_dir")
          AGENT_DISPLAY=$(get_display_name "$AGENT")
          for file in "${agent_dir}"*.md; do
            if [ -f "$file" ]; then
              echo "#### ${AGENT_DISPLAY}: $(basename "$file")"
              echo ""
              echo '```'
              head -20 "$file"
              echo '```'
              echo ""
            fi
          done
        fi
      done
    fi
  done

  # Phase 3: 検証
  echo "## Phase 3: 検証"
  echo ""

  for dir in test-runner linter security-scanner debugger; do
    if [ -d "${SESSION_DIR}/${dir}" ]; then
      echo "### $(get_display_name "$dir")"
      echo ""
      for file in "${SESSION_DIR}/${dir}"/*.md; do
        if [ -f "$file" ]; then
          echo "#### $(basename "$file")"
          echo ""
          echo '```'
          head -20 "$file"
          echo '```'
          echo ""
        fi
      done
    fi
  done

  # Phase 4: Git
  echo "## Phase 4: Git操作"
  echo ""

  for dir in committer pr-creator; do
    if [ -d "${SESSION_DIR}/${dir}" ]; then
      echo "### $(get_display_name "$dir")"
      echo ""
      for file in "${SESSION_DIR}/${dir}"/*.md; do
        if [ -f "$file" ]; then
          echo "#### $(basename "$file")"
          echo ""
          echo '```'
          head -20 "$file"
          echo '```'
          echo ""
        fi
      done
    fi
  done

} > "$OUTPUT"

echo "Results collected to: ${OUTPUT}"
