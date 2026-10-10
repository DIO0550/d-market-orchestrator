#!/bin/bash
set -euo pipefail

# requirements.md がユーザーに承認されるまで、計画（implementation-plan.md / tasks.md / test-cases.md）を書かせない。
# 承認後はユーザーに確認を取らずに進むワークフローなので、要件の確定を唯一の人間のゲートとして
# 機械的に守る。次のどれかに当たるとブロックする。
#   - 同じ run フォルダに requirements.md が無い
#   - 「未解決の確認事項」に未確認（行頭 □）が残っている
#   - 「**ステータス**:」が ■（承認済み）になっていない
#
# PreToolUse: Write, Edit, MultiEdit
# exit 0 = 許可, exit 2 = ブロック

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
is_orchestrate_path "$file" || exit 0
case "$file" in
  */implementation-plan.md | */tasks.md | */test-cases.md) ;;
  *) exit 0 ;;
esac

dir=$(dirname "$file")
req="${dir}/requirements.md"

if [ ! -f "$req" ]; then
  cat >&2 <<EOF
【spec-orchestrate: requirements】計画（${file##*/}）はまだ書けません。
先に ${req} を作り、ユーザーと要件を確定して承認を得てください（requirements → plan の順）。
EOF
  exit 2
fi

# 凡例は引用（"> "）なので行頭 □ にならず、誤検出しない
unresolved=$(sed -n '/^#\{1,4\}.*未解決の確認事項/,/^#\{1,4\} /p' "$req" | grep -E '^[[:space:]]*-?[[:space:]]*□' || true)
if [ -n "$unresolved" ]; then
  cat >&2 <<EOF
【spec-orchestrate: requirements】未解決の確認事項が残っています: ${req}
${unresolved}
AskUserQuestion でユーザーに確認し、回答を併記して □ → ■ にしてから計画へ進んでください。
EOF
  exit 2
fi

if ! grep -qE '^\*\*ステータス\*\*:[[:space:]]*■' "$req"; then
  cat >&2 <<EOF
【spec-orchestrate: requirements】requirements がまだ承認されていません: ${req}
承認ゲート（AskUserQuestion）でユーザーの承認を得て、「**ステータス**: ■ 承認済み」にしてから計画へ進んでください。
EOF
  exit 2
fi

exit 0
