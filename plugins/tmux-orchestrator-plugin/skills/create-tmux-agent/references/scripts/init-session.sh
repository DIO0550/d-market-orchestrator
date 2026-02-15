#!/bin/bash
# init-session.sh
# オーケストレーションセッションのディレクトリ構造を初期化する
#
# 使用方法:
#   init-session.sh <session-dir>
#
# 作成されるディレクトリ:
#   {session-dir}/.config/     - ランタイム設定
#   {session-dir}/.status/     - 完了マーカー
#   {session-dir}/.prompts/    - 生成プロンプトファイル
#   {session-dir}/.deps/       - 依存関係管理
#   {session-dir}/{agent}/     - 各エージェントの結果出力先

set -euo pipefail

SESSION_DIR="${1:-}"

if [ -z "$SESSION_DIR" ]; then
  echo "Usage: init-session.sh <session-dir>"
  echo "Example: init-session.sh .orchestrator/0001-user-auth"
  exit 1
fi

# tmux固有のメタディレクトリ
mkdir -p "$SESSION_DIR"/{.config,.status,.prompts,.deps}

# エージェント結果ディレクトリ
mkdir -p "$SESSION_DIR"/{explorer,planner,plan-reviewer}
mkdir -p "$SESSION_DIR"/{test-runner,linter,debugger,security-scanner}
mkdir -p "$SESSION_DIR"/{committer,pr-creator}

echo "Session directory initialized: $SESSION_DIR"
