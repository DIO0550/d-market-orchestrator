#!/bin/bash
set -uo pipefail

# run フォルダの implementation-plan.md / tasks.md / test-cases.md の形式を機械検証し、
# 不備があれば exit 2 + stderr で書いた本人（planner / implementer / 指示役）に直させる。
# d-market-spec の exp-plan-format.sh を、このプラグインの md 書式に合わせたもの。
# 承認後は人が計画を読まずに実装まで進むので、レビュアーに回す前に形の崩れをここで止める。
#
# 検証項目:
#   implementation-plan.md:
#     - 必須セクション / テンプレートのプレースホルダ（{日本語…}）の残留
#     - [NEW] / [MODIFY] エントリのコードブロックと **理由**:
#     - コードブロック内の実装の省略（... / 省略 / TODO 等）
#   tasks.md:
#     - 実装グループ（## T{n}）とタスク行（□ / ■）の有無 / プレースホルダの残留
#   test-cases.md:
#     - プレースホルダの残留 / ケース ID の重複 / 分類の値
#     - requirements.md の UC がトレース表にあるか（UC の丸ごとの漏れ）
#
# PostToolUse: Write, Edit, MultiEdit

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
[ -f "$file" ] || exit 0

dir=$(dirname "$file")
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
    printf '%s\n' "$content" | grep -qE '^## T[0-9]+' || problems+=("実装グループ（## T1: ...）がありません。implementer を起動する単位で切ってください")
    printf '%s\n' "$content" | grep -qE '^[[:space:]]*-?[[:space:]]*[□■]' || problems+=("タスク行（行頭 □ / ■）が 1 つもありません")
    ;;

  */test-cases.md)
    ids=$(printf '%s\n' "$content" | grep -oE '^\|[[:space:]]*TC-[0-9]+' | grep -oE 'TC-[0-9]+')
    add_lines "ケース ID が重複しています:" "$(printf '%s\n' "$ids" | sort | uniq -d | sed '/^$/d')"

    # ケース一覧の 3 列目（分類）が決まった語彙か
    add_lines "分類の値が不正です（正常系 / 境界値 / 異常系 / エッジケース のみ）:" "$(printf '%s\n' "$content" | awk -F'|' '
      $2 ~ /^[[:space:]]*TC-[0-9]+/ {
        cat = $4; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cat)
        if (cat != "正常系" && cat != "境界値" && cat != "異常系" && cat != "エッジケース") { id = $2; gsub(/[[:space:]]/, "", id); print id ": " cat }
      }')"

    # requirements.md はユーザーが承認した文書なので、自己申告どうしの照合にならない
    req="${dir}/requirements.md"
    if [ -f "$req" ]; then
      trace=$(printf '%s\n' "$content" | sed -n '/^#\{1,4\}.*トレース/,/^#\{1,4\} /p')
      untraced=""
      while IFS= read -r uc; do
        [ -n "$uc" ] || continue
        printf '%s\n' "$trace" | grep -qE "^\|[[:space:]]*${uc}[[:space:]]*\|" || untraced="${untraced}${uc} "
      done < <(grep -oE '^#{2,4}[[:space:]]+UC-[0-9]+' "$req" | grep -oE 'UC-[0-9]+' | sort -u)
      if [ -n "$untraced" ]; then
        problems+=("requirements の UC がトレース表にありません: ${untraced}")
        problems+=("    カバーしないなら状態を gap にして、理由を「意図的な未カバー」に書いてください（黙って落とさない）")
      fi
    fi
    ;;
esac

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "=== 【spec-orchestrate】形式の検証: ${file} ==="
    for p in "${problems[@]}"; do echo "  - $p"; done
    echo "テンプレート（skills/spec-orchestrate/assets/templates/）の構成に合わせて直してから次へ進んでください。"
  } >&2
  exit 2
fi

exit 0
