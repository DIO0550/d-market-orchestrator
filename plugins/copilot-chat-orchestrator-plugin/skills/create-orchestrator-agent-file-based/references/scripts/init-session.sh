#!/bin/bash
# セッション初期化スクリプト
# Usage: init-session.sh <feature-name>
# Output: SESSION_DIR パスを標準出力に返す（例: .orchestrator/0001-user-auth）

FEATURE_NAME="$1"
if [ -z "$FEATURE_NAME" ]; then
  echo "Usage: init-session.sh <feature-name>" >&2
  exit 1
fi

ORCH_DIR=".orchestrator"
mkdir -p "$ORCH_DIR"

# 最大連番を取得（なければ 0000）
max=$(ls -d "$ORCH_DIR"/[0-9][0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/||;s/-.*//' | sort -n | tail -1)
next=$(printf "%04d" $(( ${max:-0} + 1 )))

SESSION_DIR="$ORCH_DIR/$next-$FEATURE_NAME"
mkdir -p "$SESSION_DIR"/{explorer,planner,plan-reviewer,test-runner,linter,debugger,security-scanner,committer,pr-creator}

echo "$SESSION_DIR"
