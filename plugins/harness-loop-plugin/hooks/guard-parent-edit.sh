#!/bin/bash
set -euo pipefail

# 目標の確定後（STATE が looping / pr とその回答待ち）に、指示役（親セッション）がリポジトリの中の
# run フォルダ以外のファイルを Write / Edit するのをブロックする。実装と修正は implementer が持ち、
# 修正の小ささは理由にしない（SKILL.md「絶対厳守事項」4）。線引きを毎回判断すると分担が崩れるので、
# 指示に頼らずフックで止める。
#
# 通すもの: サブエージェントの中の呼び出し・run フォルダ（goal.md / loop-log.md / decisions.md と印）・
# リポジトリの外（PR 本文の一時ファイルなど）。目標の確定前は guard-phase-writes.sh が全員の
# run フォルダの外への書き込みを止めているので、ここでは見ない。
#
# 親とサブエージェントは、フック入力の agent_id で見分ける（サブエージェントの中のツール呼び出しには
# 載り、親の呼び出しには無い。design-composer #1032 の実測）。guard-subagent-git.sh と同じ見分け方。
#
# Bash のリダイレクトなどで書く経路は追わない（Write / Edit の経路だけを止める）。
#
# PreToolUse: Write, Edit, MultiEdit, NotebookEdit
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

agent_id=$(printf '%s' "$HOOK_INPUT" | jq -r '.agent_id // empty')
[ -z "$agent_id" ] || exit 0

run=$(find_session_run "$HOOK_SESSION_ID" looping pr waiting:looping waiting:pr) || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
is_run_path "$file" && exit 0

# hook_read_input がリポジトリのルートへ移っているので、相対パスと $PWD 配下の絶対パスがリポジトリの中。
case "$file" in
  /*) [[ "$file" == "$PWD"/* ]] || exit 0 ;;
esac

cat >&2 <<EOF
【harness-loop: ${state}】指示役（親セッション）は ${file} を編集できません（run フォルダ ${run_dir}）。
実装と修正は implementer が持ちます。1 行の修正でも、新しい Agent 呼び出しで implementer に渡してください。
指示役が書いてよいのは run フォルダの goal.md / loop-log.md / decisions.md と印（STATE / SESSION / BASE）です。
EOF
exit 2
