#!/bin/bash
set -euo pipefail

# 要件の確定中・計画中（STATE が requirements / planning、およびその回答待ち）は、run フォルダの外への
# 書き込みをブロックする。要件が承認される前に実装へ進む・計画が固まる前にコードを書く、を止める。
# 判定はセッション単位（run フォルダの SESSION と一致するセッションだけ）で、サブエージェントの
# ツール呼び出しにも掛かる。
#
# Bash の判定は bash-write-targets.py が字句解析で行う最善努力のガードで、`python -c` の中で
# 開くファイルのようにコマンドの中身で書き込むものまでは追わない。
#
# PreToolUse: Write, Edit, MultiEdit, NotebookEdit, Bash
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

run=$(find_session_run "$HOOK_SESSION_ID" requirements planning waiting:requirements waiting:planning) || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

block() {
  cat >&2 <<EOF
【spec-orchestrate: ${state}】$1
run フォルダ ${run_dir} が STATE=${state} の間は、run フォルダ（${ORCH_BASE}/）と一時ディレクトリ（mktemp）の外へは書き込めません。
- requirements: ユーザーの承認ゲートを通してから計画へ進んでください
- planning: 計画レビューを終えて STATE を implementing にしてから実装してください
EOF
  exit 2
}

case "$HOOK_TOOL" in
  Write | Edit | MultiEdit | NotebookEdit)
    file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -n "$file" ] || exit 0
    is_orchestrate_path "$file" && exit 0
    block "${file} への書き込みはブロックされました。"
    ;;
  Bash)
    command -v python3 >/dev/null 2>&1 || exit 0
    cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
    denied=$(printf '%s' "$cmd" | python3 "$(dirname "$0")/bash-write-targets.py" "$ORCH_BASE")
    [ -z "$denied" ] && exit 0
    block "書き換え先が許可されていないコマンドはブロックされました: $(printf '%s' "$denied" | tr '\n' ' ')
コマンド: ${cmd:0:200}"
    ;;
esac

exit 0
