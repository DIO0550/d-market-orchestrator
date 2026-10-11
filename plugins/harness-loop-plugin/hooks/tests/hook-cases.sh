#!/bin/bash
# harness-loop-plugin のフックの判定表。一時ディレクトリに run フォルダを作り、
# フック入力 JSON を流して終了コード・出力を確かめる。
#
# 使い方: bash plugins/harness-loop-plugin/hooks/tests/hook-cases.sh
# 失敗が 1 件でもあれば exit 1

set -u
HOOKS=$(cd "$(dirname "$0")/.." && pwd)
TPL=$(cd "$HOOKS/../skills/harness-loop/assets/templates" && pwd)
PROJECT=$(mktemp -d)
trap 'rm -rf "$PROJECT"' EXIT
export CLAUDE_PROJECT_DIR=$PROJECT

SID=sess-1
RUN=".plugin-workspace/.harness/001-sample"
fail=0
pass=0

set_state() {
  mkdir -p "$PROJECT/$RUN"
  echo "$1" > "$PROJECT/$RUN/STATE"
  echo "$SID" > "$PROJECT/$RUN/SESSION"
}

# @param $1 期待する終了コード  $2 ケース名  $3 フック  $4 入力 JSON
expect_exit() {
  local want=$1 name=$2 hook=$3 input=$4 got
  printf '%s' "$input" | bash "$HOOKS/$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "NG: $name (want exit $want, got $got)"
  fi
}

# @param $1 出力に含まれるべきか（yes/no）  $2 ケース名  $3 フック  $4 入力 JSON  $5 探す文字列
expect_output() {
  local want=$1 name=$2 hook=$3 input=$4 needle=$5 out found=no
  out=$(printf '%s' "$input" | bash "$HOOKS/$hook" 2>/dev/null)
  printf '%s' "$out" | grep -q "$needle" && found=yes
  if [ "$found" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "NG: $name (want output contains '$needle' = $want)"
  fi
}

write_json() { jq -nc --arg s "$SID" --arg t "$1" --arg f "$2" '{session_id:$s, tool_name:$t, tool_input:{file_path:$f}}'; }
bash_json() { jq -nc --arg s "$SID" --arg c "$1" '{session_id:$s, tool_name:"Bash", tool_input:{command:$c}}'; }

# ── guard-phase-writes.sh ─────────────────────────────
G=guard-phase-writes.sh
set_state planning
expect_exit 2 "計画中は src への Write をブロック" $G "$(write_json Write "$PROJECT/src/a.ts")"
expect_exit 0 "計画中でも run フォルダへの Write は通す" $G "$(write_json Write "$PROJECT/$RUN/plan.md")"
expect_exit 2 "計画中は src へのリダイレクトをブロック" $G "$(bash_json 'echo x > src/a.ts')"
expect_exit 0 "STATE の書き換えは通す" $G "$(bash_json "echo goal > $RUN/STATE")"
expect_exit 2 "run フォルダ宛てを混ぜた迂回をブロック" $G "$(bash_json "echo a > $RUN/x.md; rm src/a.ts")"
expect_exit 0 "2>&1 を含む読むだけのコマンドは通す" $G "$(bash_json 'ls src 2>&1 | head -5')"
expect_exit 0 "ヒアドキュメント本文の md 引用は書き込みとみなさない" $G "$(bash_json "cat > $RUN/a.md <<'EOF'
> 引用
EOF")"
expect_exit 0 "mktemp の一時ディレクトリへの書き込みは通す" $G "$(bash_json 'tmp=$(mktemp -d); echo x > "$tmp/a"')"
expect_exit 0 "引用符の中の > は書き込みとみなさない（grep）" $G "$(bash_json 'grep -rn "=> " src')"
expect_exit 0 "引用符の中の > は書き込みとみなさない（awk）" $G "$(bash_json "awk '\$2 > 5' f.txt")"
expect_exit 0 "コメントの中の > は書き込みとみなさない" $G "$(bash_json 'ls src # > note')"
expect_exit 2 "空白無しのリダイレクトもブロック" $G "$(bash_json 'echo x >src/a.ts')"
expect_exit 2 "cp は送り先で判定する（/tmp から src へ）" $G "$(bash_json 'cp /tmp/x src/a.ts')"
expect_exit 0 "cp で mktemp の一時ディレクトリへ写すのは通す" $G "$(bash_json 'd=$(mktemp -d); cp src/a.ts "$d/"')"
expect_exit 0 "mktemp へ cd した先の相対パスへの書き込みは通す" $G "$(bash_json 'cd "$(mktemp -d)" && echo x > a.txt')"
expect_exit 2 "作業ツリーを書き換える git はブロック" $G "$(bash_json 'git checkout -- src')"
expect_exit 2 ".. で run フォルダの外へ抜ける Write はブロック" $G "$(write_json Write "$PROJECT/$RUN/../../../src/a.ts")"
set_state goal
expect_exit 2 "目標確定待ちでも src への Edit をブロック" $G "$(write_json Edit "$PROJECT/src/a.ts")"
expect_exit 2 "目標確定待ちはブランチの切り替えもブロック" $G "$(bash_json 'git switch -c harness/001-sample')"
set_state waiting:goal
expect_exit 2 "目標確定の回答待ちでも src への Write をブロック" $G "$(write_json Write "$PROJECT/src/a.ts")"
set_state looping
expect_exit 0 "ループ中は src への Write を通す" $G "$(write_json Write "$PROJECT/src/a.ts")"
expect_exit 0 "ループ中はコミットを通す" $G "$(bash_json 'git add -- src/a.ts')"
set_state planning
expect_exit 0 "別セッションには掛からない" $G "$(jq -nc '{session_id:"other", tool_name:"Write", tool_input:{file_path:"src/a.ts"}}')"
mkdir -p "$PROJECT/.plugin-workspace/.harness/002-newer"
echo looping > "$PROJECT/.plugin-workspace/.harness/002-newer/STATE"
echo "$SID" > "$PROJECT/.plugin-workspace/.harness/002-newer/SESSION"
expect_exit 0 "同じセッションの新しい run があれば古い run の STATE には反応しない" $G "$(write_json Write "$PROJECT/src/a.ts")"
rm -rf "$PROJECT/.plugin-workspace/.harness/002-newer"

# ── check-goal.sh ─────────────────────────────
C=check-goal.sh
GOAL="$PROJECT/$RUN/goal.md"
cp "$TPL/goal.md" "$GOAL"
expect_exit 0 "未確定のテンプレートは通す（案の段階ではプレースホルダが残ってよい）" $C "$(write_json Write "$GOAL")"
sed -i 's/^- □ C-2: .*/- □ C-2: 一覧に出る/' "$GOAL"
expect_exit 2 "確かめ方の無い完了条件を検出" $C "$(write_json Write "$GOAL")"
cat > "$GOAL" <<'EOF'
# Goal: ログイン回数制限

**ステータス**: ■ 確定

## ゴール

5 回失敗したらロックされる

## 完了条件

- □ C-1: 5 回失敗でロック — 確かめ方: `npm test -- limit`
- □ C-2: 既存の検査が通る — 確かめ方: `npm test`

## スコープ外

- なし

## 未解決の確認事項

□ ロックの解除方法

## 実行設定

- **PR のベースブランチ**: main
- **ループの上限**: 5 回
EOF
expect_exit 2 "確定なのに □ の確認事項が残っていれば止める" $C "$(write_json Write "$GOAL")"
sed -i 's/^□ ロックの解除方法/■ ロックの解除方法（回答: 30 分で自動解除）/' "$GOAL"
expect_exit 0 "確認事項が解消された確定の goal は通す" $C "$(write_json Write "$GOAL")"
sed -i 's/^5 回失敗したらロックされる/{ゴール}/' "$GOAL"
expect_exit 2 "確定なのにプレースホルダが残っていれば止める" $C "$(write_json Write "$GOAL")"
sed -i 's/^{ゴール}/5 回失敗したらロックされる/' "$GOAL"
expect_exit 0 "run フォルダの外の goal.md には掛からない" $C "$(write_json Write "$PROJECT/docs/goal.md")"
mkdir -p "$PROJECT/$RUN/x" && printf '# Goal\n\n**ステータス**: □ 未確定\n' > "$PROJECT/$RUN/x/goal.md"
expect_exit 2 "完了条件が 1 つも無い goal を検出" $C "$(write_json Write "$PROJECT/$RUN/x/goal.md")"

# ── guard-pr.sh ─────────────────────────────
P=guard-pr.sh
mcp_json() { jq -nc --arg s "$SID" '{session_id:$s, tool_name:"mcp__github__create_pull_request", tool_input:{title:"x"}}'; }
set_state looping
expect_exit 2 "ループ中は gh pr create をブロック" $P "$(bash_json 'gh pr create --base main --body-file /tmp/b.md')"
expect_exit 2 "ループ中は MCP の PR 作成もブロック" $P "$(mcp_json)"
expect_exit 0 "PR 作成以外の gh は通す" $P "$(bash_json 'gh pr view 1')"
set_state pr
expect_exit 2 "STATE が pr でも未達の完了条件があればブロック" $P "$(bash_json 'gh pr create --base main')"
sed -i 's/^- □ C-/- ■ C-/' "$GOAL"
expect_exit 0 "完了条件がすべて ■ なら gh pr create を通す" $P "$(bash_json 'gh pr create --base main')"
expect_exit 0 "完了条件がすべて ■ なら MCP の PR 作成を通す" $P "$(mcp_json)"
set_state looping
expect_exit 2 "完了条件がすべて ■ でもループを抜けていなければブロック" $P "$(bash_json 'gh pr create --base main')"
expect_exit 0 "run の無いセッションには掛からない" $P "$(jq -nc '{session_id:"other", tool_name:"Bash", tool_input:{command:"gh pr create"}}')"

# ── continue-until-done.sh ─────────────────────────────
S=continue-until-done.sh
stop_json() { jq -nc --arg s "$SID" --argjson a "$1" '{session_id:$s, stop_hook_active:$a}'; }
set_state looping
expect_output yes "ループ中の停止は引き止める" $S "$(stop_json false)" '"decision": "block"'
expect_output no "引き止めた続きの停止は通す" $S "$(stop_json true)" 'block'
set_state waiting:looping
expect_output no "回答待ち（waiting:*）なら引き止めない" $S "$(stop_json false)" 'block'
set_state goal
expect_output no "目標確定待ち（ユーザーとの対話中）なら引き止めない" $S "$(stop_json false)" 'block'
set_state done
expect_output no "完了後は引き止めない" $S "$(stop_json false)" 'block'

echo "pass: $pass / fail: $fail"
[ "$fail" -eq 0 ]
