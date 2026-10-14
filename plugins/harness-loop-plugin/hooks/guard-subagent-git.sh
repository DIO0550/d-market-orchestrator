#!/bin/bash
set -euo pipefail

# harness-loop の run が進行中のセッションで、サブエージェントの中から git の状態を変える操作
# （add / commit / push / stash / reset / checkout / restore / switch / clean / rebase / merge /
# cherry-pick / revert / rm / mv）を走らせるのをブロックする。git 操作は指示役が持ち、implementer が
# 返した変更を計画と突き合わせてからコミットする。サブエージェントがインデックスへ載せると、指示役の
# `git commit` が突き合わせていない変更ごとコミットする。
#
# 親の呼び出しかサブエージェントの中の呼び出しかは、フック入力の agent_id で見分ける（サブエージェントの
# 中の Bash には載り、親の呼び出しには無い。design-composer #1032 の実測）。載っていなければ親として
# 通す（フェイルオープン）。印（マーカー）で実行中かを数える形にはしない。前面で起動しても約 120 秒で
# 背景へ移されると Agent の PostToolUse が来て印が消え、長い implementer ほど守れないため。
#
# 判定は字句の最善努力で、`sh -c` の文字列の中や変数に入れたコマンドまでは追わない。
#
# PreToolUse: Bash
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0
[ "$HOOK_TOOL" = "Bash" ] || exit 0

agent_id=$(printf '%s' "$HOOK_INPUT" | jq -r '.agent_id // empty')
[ -n "$agent_id" ] || exit 0

run=$(latest_session_run "$HOOK_SESSION_ID") || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}
[ "$state" = "done" ] && exit 0

cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
# git の前は行頭・区切り（; & | ( ）・空白だけを認める。引用符の直後（`grep "git add"`）は当たらない。
# git と操作の間の大域オプション（-C <dir> / -c <k=v> / --git-dir=... など）は読み飛ばす。
git_op='(^|[;&|(]|[[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+(add|commit|push|stash|reset|checkout|restore|switch|clean|rebase|merge|cherry-pick|revert|rm|mv)([[:space:]]|$|[;&|)])'
printf '%s' "$cmd" | grep -qE "$git_op" || exit 0

agent_type=$(printf '%s' "$HOOK_INPUT" | jq -r '.agent_type // "サブエージェント"')
cat >&2 <<EOF
【harness-loop: ${state}】サブエージェント（${agent_type}）の中から git の状態を変える操作はできません（run フォルダ ${run_dir}）。
git 操作は指示役が持ちます。変更は作業ツリーに置いたまま、変更したファイルの一覧を返してください。
コマンド: ${cmd:0:200}
EOF
exit 2
