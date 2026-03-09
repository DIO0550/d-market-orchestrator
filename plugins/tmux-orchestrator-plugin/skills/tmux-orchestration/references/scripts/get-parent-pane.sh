#!/bin/bash
# get-parent-pane.sh
# 現在のペインIDを取得し、オプションで設定ファイルに保存する
#
# 使用方法:
#   get-parent-pane.sh [session-dir]
#
# 引数:
#   session-dir - セッションディレクトリ（省略可。指定時は .config/parent-pane.txt に保存）
#
# 出力:
#   PARENT_PANE={pane-id}
#
# 例:
#   get-parent-pane.sh
#   get-parent-pane.sh .orchestrator/0001-user-auth

set -euo pipefail

SESSION_DIR="${1:-}"

PARENT_PANE=$(tmux display-message -p '#{pane_id}')

if [ -z "$PARENT_PANE" ]; then
  echo "Error: Failed to get pane ID. Are you running inside tmux?"
  exit 1
fi

if [ -n "$SESSION_DIR" ]; then
  mkdir -p "${SESSION_DIR}/.config"
  echo "$PARENT_PANE" > "${SESSION_DIR}/.config/parent-pane.txt"
fi

echo "PARENT_PANE=${PARENT_PANE}"
