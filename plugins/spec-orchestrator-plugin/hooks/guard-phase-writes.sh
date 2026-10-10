#!/bin/bash
set -euo pipefail

# 要件の確定中・計画中（STATE が requirements / planning）は、run フォルダの外への書き込みをブロックする。
# 要件が承認される前に実装へ進む・計画が固まる前にコードを書く、を止めるためのゲート。
# 判定はセッション単位（run フォルダの SESSION と一致するセッションだけ）で、サブエージェントの
# ツール呼び出しにも掛かる。
#
# PreToolUse: Write, Edit, MultiEdit, NotebookEdit, Bash
# exit 0 = 許可, exit 2 = ブロック

command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# 書き込み系コマンドの検出パターン（コマンド名は行頭 / 区切り文字の直後のみマッチ）
WRITE_PAT='((^|[;&|[:space:]])(rm|cp|mv|mkdir|tee|touch|install|ln)[[:space:]]|>>|>[[:space:]]|>$|sed[[:space:]]+-i)'
# 書き込んでよい先: run フォルダの置き場と、挙動を確かめるための一時ディレクトリ
ALLOWED_TARGET_PAT='(\.plugin-workspace/\.orchestrate/|/tmp/|/dev/null|mktemp|\$\{?TMPDIR|\$\{?tmp)'

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

run=$(find_session_run "$HOOK_SESSION_ID" requirements planning) || exit 0
run_dir=${run%%$'\t'*}
state=${run#*$'\t'}

block() {
  cat >&2 <<EOF
【spec-orchestrate: ${state}】$1
run フォルダ ${run_dir} が STATE=${state} の間は、run フォルダ（.plugin-workspace/.orchestrate/）の外へは書き込めません。
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
    cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
    # ヒアドキュメントの本文は書き込み先ではない（md の引用 "> " を誤検出する）ので、
    # 最初の << の行までだけを見る。2>&1 のような fd の複製は区切り文字で割れて ">" だけが
    # 残るので、先に取り除く
    checked=$(printf '%s\n' "$cmd" | awk '{ print } /<</ { exit }' | sed -E 's/[0-9]*>&[0-9-]+//g')
    # 書き込み系の各セグメントが、すべて許可された先を対象にしている場合だけ通す
    # （1 つのコマンドに run フォルダ宛てを混ぜて外へ書く迂回を防ぐ）
    while IFS= read -r seg; do
      [ -n "$seg" ] || continue
      printf '%s' "$seg" | grep -qE "$WRITE_PAT" || continue
      printf '%s' "$seg" | grep -qE "$ALLOWED_TARGET_PAT" && continue
      block "ファイルを変更するコマンドはブロックされました: ${cmd:0:200}"
    done < <(printf '%s\n' "$checked" | tr ';&|' '\n')
    ;;
esac

exit 0
