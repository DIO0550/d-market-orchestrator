#!/bin/bash
# tmux-session-create.sh
# オーケストレーション用のtmuxセッションとウィンドウを作成する
#
# 使用方法:
#   tmux-session-create.sh <session-name>
#
# 作成されるウィンドウ:
#   control  - ステータスモニター表示用
#   phase1   - 探索・計画・レビュー
#   phase2   - 実装（タスクごとのpane）
#   phase3   - 検証（テスト・Lint・セキュリティ）
#   phase4   - Git操作（コミット・PR）

set -euo pipefail

SESSION_NAME="${1:-}"

if [ -z "$SESSION_NAME" ]; then
  echo "Usage: tmux-session-create.sh <session-name>"
  echo "Example: tmux-session-create.sh orch-0001-user-auth"
  exit 1
fi

# tmux がインストールされているか確認
if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is not installed."
  echo "Install with: brew install tmux (macOS) or apt install tmux (Ubuntu)"
  exit 1
fi

# 既存セッションがあれば削除
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Warning: Session '$SESSION_NAME' already exists. Killing it."
  tmux kill-session -t "$SESSION_NAME"
fi

# セッション作成（最初のウィンドウは control）
tmux new-session -d -s "$SESSION_NAME" -n "control"

# Phase ウィンドウを作成
tmux new-window -t "$SESSION_NAME" -n "phase1"
tmux new-window -t "$SESSION_NAME" -n "phase2"
tmux new-window -t "$SESSION_NAME" -n "phase3"
tmux new-window -t "$SESSION_NAME" -n "phase4"

# control ウィンドウを選択
tmux select-window -t "${SESSION_NAME}:control"

echo "tmux session '$SESSION_NAME' created."
echo "Windows: control, phase1, phase2, phase3, phase4"
echo ""
echo "Attach with: tmux attach -t $SESSION_NAME"
