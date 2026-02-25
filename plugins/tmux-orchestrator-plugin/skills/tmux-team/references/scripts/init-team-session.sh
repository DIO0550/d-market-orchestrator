#!/bin/bash
# init-team-session.sh
# チームセッションのディレクトリ構造を初期化する
#
# 使用方法:
#   init-team-session.sh <session-dir> <pane-count>
#
# 引数:
#   session-dir  - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   pane-count   - チームメンバー数（ペイン数）
#
# 作成されるディレクトリ:
#   {session-dir}/.config/     - ランタイム設定（pane-registry.json, member-status.json）
#   {session-dir}/.status/     - 完了マーカー（.done, .exit, .ready）
#   {session-dir}/.prompts/    - タスクプロンプトファイル
#   {session-dir}/member-{N}/  - 各メンバーの結果出力先
#   {session-dir}/shared/      - メンバー間共有成果物

set -euo pipefail

SESSION_DIR="${1:-}"
PANE_COUNT="${2:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$PANE_COUNT" ]; then
  echo "Usage: init-team-session.sh <session-dir> <pane-count>"
  echo "Example: init-team-session.sh .orchestrator/0001-feature 3"
  exit 1
fi

if ! [[ "$PANE_COUNT" =~ ^[0-9]+$ ]] || [ "$PANE_COUNT" -lt 1 ] || [ "$PANE_COUNT" -gt 8 ]; then
  echo "Error: pane-count must be a number between 1 and 8"
  exit 1
fi

# メタディレクトリ
mkdir -p "$SESSION_DIR"/{.config,.status,.prompts}

# メンバー結果ディレクトリ
for i in $(seq 1 "$PANE_COUNT"); do
  mkdir -p "$SESSION_DIR/member-${i}"
done

# 共有成果物ディレクトリ
mkdir -p "$SESSION_DIR/shared"

# チーム設定の読み込み（team-config.json が存在する場合）
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
  if [ -n "$TEAM_NAME" ]; then
    echo "Team: ${TEAM_NAME}"
  fi
fi

# メンバー一覧を表示
MEMBERS=""
for i in $(seq 1 "$PANE_COUNT"); do
  if [ -n "$MEMBERS" ]; then
    MEMBERS="${MEMBERS}, "
  fi
  MEMBERS="${MEMBERS}member-${i}"
done

echo "Team session directory initialized: $SESSION_DIR"
echo "Members: ${PANE_COUNT} (${MEMBERS})"
