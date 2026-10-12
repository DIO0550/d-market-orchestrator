#!/bin/bash
set -uo pipefail

# run フォルダの implementation-plan.md / tasks.md の形式を機械検証し、不備があれば exit 2 + stderr で
# 書いた本人（planner / implementer）に直させる。d-market-spec の exp-plan-format.sh / enforce-diagrams.sh /
# enforce-code-examples.sh と同じ書式を守らせるもの。目標の確定後は人が計画を読まずにループへ進むので、
# レビュアーに回す前に形の崩れをここで止める。
#
# 検証項目:
#   implementation-plan.md:
#     - 必須セクション / テンプレートのプレースホルダ（{日本語…}）の残留
#     - システム図のセクションに図（コードブロック）があるか
#     - [NEW] / [MODIFY] エントリのコードブロックと **理由**:
#     - コードブロック内の実装の省略（... / 省略 / TODO 等）
#   tasks.md:
#     - 「## Implementation」とタスク行（□ / ■）の有無 / プレースホルダの残留
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
  */implementation-plan.md | */tasks.md) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# HTML コメントはテンプレートの記入例なので検証の対象から外す
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

add_lines() {
  local title=$1 body=$2
  [ -n "$body" ] || return 0
  problems+=("$title")
  while IFS= read -r l; do problems+=("    $l"); done <<< "$body"
}

# テンプレートのプレースホルダ（{…} の中に日本語を含むもの）。コードブロックの外は引用符を含まない波括弧を、
# コードブロックの中は行全体がプレースホルダの行（`// {…}` を含む）だけを見る。コードの中の
# `${件数}` や JSX の `{/* 見出し */}`、日本語の doc コメントを誤検出しないため
add_lines "テンプレートのプレースホルダが残っています:" "$(printf '%s\n' "$content" | awk '
  /^```/ { in_block = !in_block; next }
  !in_block && /\{[^{}"\x27]*[ぁ-んァ-ヶ一-龠][^{}"\x27]*\}/ { print NR ": " $0; next }
  in_block && /^[[:space:]]*(\/\/[[:space:]]*)?\{[^{}\/*][^{}]*[ぁ-んァ-ヶ一-龠][^{}]*\}[[:space:]]*$/ { print NR ": " $0 }
' | head -5)"

case "$file" in
  */implementation-plan.md)
    for sec in "概要" "背景" "設計判断" "システム図" "変更案" "影響範囲" "検証計画" "未決の判断" "Definition of Done"; do
      printf '%s\n' "$content" | grep -qE "^#{1,4} .*${sec}" || problems+=("必須セクション「## ${sec}」がありません")
    done

    # システム図のセクション（次の ## まで）にコードブロックで図があるか
    diagram=$(printf '%s\n' "$content" | sed -n '/^## .*システム図/,/^## /p' | grep -c '^```' || true)
    [ "${diagram:-0}" -ge 2 ] || problems+=("システム図のセクションに図（状態遷移 / フローとデータフローの ASCII 図をコードブロックで）がありません")

    # ##### は before / after のサブ見出しなのでエントリの区切りとして扱わない
    add_lines "コードブロック（シグネチャ・骨格・before/after）の無い変更案エントリ:" "$(printf '%s\n' "$content" | awk '
      /^#### \[(NEW|MODIFY)\]/ { if (entry != "" && !has) print entry; entry = $0; has = 0; next }
      /^#/ && !/^#####/ { if (entry != "" && !has) print entry; entry = "" }
      /^```/ { if (entry != "") has = 1 }
      END { if (entry != "" && !has) print entry }')"

    add_lines "**理由**: の無い変更案エントリ:" "$(printf '%s\n' "$content" | awk '
      /^#### \[(NEW|MODIFY|DELETE)\]/ { if (entry != "" && !has) print entry; entry = $0; has = 0; next }
      /^#/ && !/^#####/ { if (entry != "" && !has) print entry; entry = "" }
      /\*\*理由\*\*/ { if (entry != "") has = 1 }
      END { if (entry != "" && !has) print entry }')"

    # 行全体が省略の印になっているコメント行だけを見る（「省略時は」のような doc の言い回しは対象外）。
    # ##### before は既存コードの引用なので、そこにある TODO は計画の省略ではない
    add_lines "コードブロック内で実装が省略されています（骨格まで書く）:" "$(printf '%s\n' "$content" | awk '
      /^#####/ { in_before = ($0 ~ /^#####[[:space:]]*before/) }
      /^#{1,4} / { in_before = 0 }
      /^```/ { in_block = !in_block; next }
      in_block && !in_before {
        if ($0 ~ /^[[:space:]]*(\.\.\.|…)[[:space:]]*$/ ||
            $0 ~ /^[[:space:]]*(\{?\/\*+|\/\/|#|\*|--)[[:space:]]*(\.\.\.|…|TODO|FIXME)/ ||
            $0 ~ /^[[:space:]]*(\{?\/\*+|\/\/|#|\*|--)[[:space:]]*(省略|中略|以下省略|以下略|割愛)[[:space:]]*(\*\/\}?|。|:|：|[(（]|$)/)
          print "L" NR ": " $0
      }' | head -5)"
    ;;

  */tasks.md)
    printf '%s\n' "$content" | grep -qE '^## Implementation' || problems+=("「## Implementation」がありません（ループの 1 回目に implementer が上から実装する順番）")
    printf '%s\n' "$content" | grep -qE '^[[:space:]]*-?[[:space:]]*(□|■)' || problems+=("タスク行（行頭 □ / ■）が 1 つもありません")
    ;;
esac

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "=== 【harness-loop】形式の検証: ${file} ==="
    for p in "${problems[@]}"; do echo "  - $p"; done
    echo "テンプレート（skills/harness-loop/assets/templates/）の構成に合わせて直してから次へ進んでください。"
  } >&2
  exit 2
fi

exit 0
