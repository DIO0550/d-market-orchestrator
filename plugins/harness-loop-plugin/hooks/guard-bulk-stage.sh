#!/bin/bash
set -euo pipefail

# harness-loop の run が進行中のセッションで、変更をまとめてステージする git（git add -A / --all / -u /
# --update / . / :/ / *、git commit -a / --all / .）をブロックする。指示役は implementer が返した変更ファイルを
# git status --porcelain と計画に突き合わせ、一致したものだけを `git add -- <ファイル>` でコミットする。
# まとめてステージすると、run を始めたときからあったユーザーの変更や、返し漏れたファイルが
# 突き合わせを経ずにコミットに載る。
# 由来: design-composer #1437 の block-git-add-all.sh（d-market-git / git-workflow-plugin の
# no-git-add-all.sh）。run の無いセッションには掛けない（リポジトリ全体の方針は git-workflow-plugin 側の役目）。
#
# 判定は bulk-stage-commands.py が字句解析で行う最善努力のガードで、`sh -c` の文字列の中までは追わない。
#
# PreToolUse: Bash
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0
[ "$HOOK_TOOL" = "Bash" ] || exit 0

run=$(latest_session_run "$HOOK_SESSION_ID") || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}
[ "$state" = "done" ] && exit 0

command -v python3 >/dev/null 2>&1 || exit 0
cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
bulk=$(printf '%s' "$cmd" | python3 -B "$(dirname "$0")/bulk-stage-commands.py")
[ -z "$bulk" ] && exit 0

cat >&2 <<EOF
【harness-loop: ${state}】変更をまとめてステージする git はブロックされました（run フォルダ ${run_dir}）: $(printf '%s' "$bulk" | head -3 | tr '\n' ' ')
implementer が返した変更ファイルを git status --porcelain と計画に突き合わせ、一致したものだけを
git add -- <ファイル> で指定してからコミットしてください（git commit -a も使わない）。
EOF
exit 2
