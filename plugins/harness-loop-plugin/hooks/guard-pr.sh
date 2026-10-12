#!/bin/bash
set -euo pipefail

# harness-loop の run が進行中のセッションで、目標を満たす前に PR を作るのをブロックする。
# ループの出口は「完了条件がすべて ■」で、PR はその出口の先にしか無い、を機械的に守る。
# 通すのは、セッションの最新の run の STATE が pr（または done）で、goal.md の完了条件に □ が無いときだけ。
# harness-loop の run が無いセッションには掛からない。
#
# PreToolUse: Bash（gh pr create）, mcp__*__create_pull_request
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

case "$HOOK_TOOL" in
  Bash)
    cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
    printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+create' || exit 0
    ;;
  *create_pull_request*) ;;
  *) exit 0 ;;
esac

run=$(latest_session_run "$HOOK_SESSION_ID") || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

case "$state" in
  pr | done) ;;
  *)
    cat >&2 <<EOF
【harness-loop: ${state}】PR はまだ作れません（run フォルダ ${run_dir}）。
完了条件がすべて ■ になってループを抜け、STATE を pr にしてから作ってください。
EOF
    exit 2
    ;;
esac

goal="${run_dir}/goal.md"
if [ ! -f "$goal" ]; then
  echo "【harness-loop】${goal} がありません。目標を確定してから PR を作ってください。" >&2
  exit 2
fi
unmet=$(unmet_criteria "$goal")
if [ -n "$unmet" ]; then
  cat >&2 <<EOF
【harness-loop】未達の完了条件が残っているので PR は作れません: ${goal}
${unmet}
ループへ戻る（echo looping > ${run_dir}/STATE）か、満たせない理由をユーザーに確認してください。
EOF
  exit 2
fi

exit 0
