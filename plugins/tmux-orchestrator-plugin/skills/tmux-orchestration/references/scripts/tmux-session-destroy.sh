#!/bin/bash
# tmux-session-destroy.sh
# オーケストレーション用のtmuxセッションを破棄する
#
# 使用方法:
#   tmux-session-destroy.sh <session-name>

set -euo pipefail

SESSION_NAME="${1:-}"

if [ -z "$SESSION_NAME" ]; then
  echo "Usage: tmux-session-destroy.sh <session-name>"
  exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SESSION_NAME"
  echo "tmux session '$SESSION_NAME' destroyed."
else
  echo "Session '$SESSION_NAME' does not exist."
fi
