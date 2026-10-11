#!/bin/bash
set -uo pipefail

# goal.md を書いたら形を検査し、崩れていれば exit 2 + stderr で書いた本人に直させる。
# 完了条件はループの終了条件と PR のゲート（guard-pr.sh）になるので、確かめられない条件・
# ユーザーが決めていない分岐を残したまま確定させない。
#
# 検査項目:
#   - 完了条件（- □/■ C-n: ...）が 1 つ以上あり、すべてに「確かめ方:」が付いている
#   - 「**ステータス**: ■」（確定）なのに、未解決の確認事項に □ が残っている
#   - 確定なのに、テンプレートのプレースホルダ（{日本語…}）が残っている
#
# PostToolUse: Write, Edit, MultiEdit

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
require_jq || exit 0

hook_read_input

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
is_run_path "$file" || exit 0
case "$file" in
  */goal.md) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# HTML コメントはテンプレートの記入例なので検査の対象から外す
content=$(awk '
  { line = $0 }
  in_comment { if (index(line, "-->")) { line = substr(line, index(line, "-->") + 3); in_comment = 0 } else next }
  { while (index(line, "<!--")) {
      pre = substr(line, 1, index(line, "<!--") - 1); rest = substr(line, index(line, "<!--") + 4)
      if (index(rest, "-->")) line = pre substr(rest, index(rest, "-->") + 3)
      else { line = pre; in_comment = 1; break }
    }
    print line }
' "$file")
problems=()

criteria=$(printf '%s\n' "$content" | grep -E '^[[:space:]]*-[[:space:]]*(□|■)[[:space:]]*C-[0-9]+' || true)
if [ -z "$criteria" ]; then
  problems+=("完了条件（「- □ C-1: 満たすべき状態 — 確かめ方: ...」）が 1 つもありません")
else
  no_check=$(printf '%s\n' "$criteria" | grep -v '確かめ方' || true)
  if [ -n "$no_check" ]; then
    problems+=("確かめ方の無い完了条件があります（コマンドか「レビュー: 何を見れば満たすと言えるか」を書く）:")
    while IFS= read -r l; do problems+=("    $l"); done <<< "$no_check"
  fi
fi

if printf '%s\n' "$content" | grep -qE '^\*\*ステータス\*\*:[[:space:]]*■'; then
  unresolved=$(printf '%s\n' "$content" | sed -n '/^#\{1,4\}.*未解決の確認事項/,/^#\{1,4\} /p' | grep -E '^[[:space:]]*-?[[:space:]]*□' || true)
  if [ -n "$unresolved" ]; then
    problems+=("確定（■）にしたのに、未解決の確認事項が残っています。AskUserQuestion で解消し、回答を併記して ■ にしてから確定してください:")
    while IFS= read -r l; do problems+=("    $l"); done <<< "$unresolved"
  fi
  placeholders=$(printf '%s\n' "$content" | grep -nE "\\{[^{}\"'\`]*[ぁ-んァ-ヶ一-龠][^{}\"'\`]*\\}" | head -5 || true)
  if [ -n "$placeholders" ]; then
    problems+=("確定（■）にしたのに、テンプレートのプレースホルダが残っています:")
    while IFS= read -r l; do problems+=("    $l"); done <<< "$placeholders"
  fi
fi

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "=== 【harness-loop】goal.md の検査: ${file} ==="
    for p in "${problems[@]}"; do echo "  - $p"; done
  } >&2
  exit 2
fi

exit 0
