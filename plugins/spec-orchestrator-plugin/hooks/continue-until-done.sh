#!/bin/bash
set -euo pipefail

# 要件の承認後（STATE が planning / implementing / verifying）に応答を終えようとしたら、1 度だけ
# 引き止めて続行を促す。承認後は止まらずに完了まで進むワークフローなので、確認のつもりで
# 途中で手を止める・「次へ進みますか」と聞いて終える、を防ぐ。
# 本当に止まる必要があるとき（エスカレーションで回答待ち）は STATE を waiting にしてから終える。
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

run=$(find_session_run "$HOOK_SESSION_ID" planning implementing verifying) || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

reason="spec-orchestrate の run フォルダ ${run_dir} は STATE=${state} のままです。
要件は承認済みなので、エスカレーション条件（要件が揺らぐ / 不可逆・外部に影響する / 行き詰まり / 権限が無い）に当たらない限り、ユーザーに確認せずに次の手順へ進んでください。
- 当たるなら AskUserQuestion で選択肢と推奨を示して聞く
- 応答を終えて回答を待つなら、decisions.md にエスカレーションを書き、echo waiting > ${run_dir}/STATE にしてから終える
- ユーザーの指示で中断したなら、echo waiting > ${run_dir}/STATE にしてから終える"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
