#!/bin/bash
set -euo pipefail

# 目標の確定後（STATE が looping / pr）に応答を終えようとしたら、1 度だけ引き止めて続行を促す。
# 確定後は完了条件を満たして PR を作るまで止まらずに回すハーネスなので、確認のつもりで途中で
# 手を止める・「次の回へ進みますか」と聞いて終える、を防ぐ。
# 本当に止まる必要があるとき（エスカレーションで回答待ち・ユーザーの指示で中断）は、
# STATE を waiting:<STATE> にしてから終える。
#
# Stop
# 続行させるときは {"decision":"block"} を出力する

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

# 既にこのフックで引き止めた続きなら止める（無限に引き止めない）
active=$(printf '%s' "$HOOK_INPUT" | jq -r '.stop_hook_active // false')
[ "$active" = "true" ] && exit 0

run=$(find_session_run "$HOOK_SESSION_ID" looping pr) || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

reason="harness-loop の run フォルダ ${run_dir} は STATE=${state} のままです。
目標は確定済みなので、エスカレーション条件（目標が揺らぐ / 不可逆・外部に影響する / 行き詰まり / 権限が無い）に当たらない限り、ユーザーに確認せずに次の回（または PR）へ進んでください。
- 当たるなら AskUserQuestion で選択肢と推奨を示して聞く
- 応答を終えて回答を待つ・ユーザーの指示で中断するなら、decisions.md に書き、echo waiting:${state} > ${run_dir}/STATE にしてから終える"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
