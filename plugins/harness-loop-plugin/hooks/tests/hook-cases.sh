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
expect_exit 0 "計画中でも run フォルダへの Write は通す" $G "$(write_json Write "$PROJECT/$RUN/notes.md")"
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

# ── check-plan-format.sh ─────────────────────────────
C=check-plan-format.sh
cp "$TPL/implementation-plan.md" "$PROJECT/$RUN/implementation-plan.md"
expect_exit 2 "テンプレートのままの plan はプレースホルダで落ちる" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
cat > "$PROJECT/$RUN/implementation-plan.md" <<'EOF'
# ログイン失敗の回数制限
## 概要
x
## 背景
x
## 設計判断（ADR）
x
## システム図
```
入力 -> 判定 -> ロック
```
```
Login -> Limit -> Store
```
## 変更案
#### [NEW] `src/limit.ts`
- **理由**: 既存に無い
```ts
export function limit(n: number): boolean { return n < 5 }
```
#### [MODIFY] `src/login.ts`
- **理由**: 呼び出しを足す
## 影響範囲の確認
x
## 検証計画
x
## 未決の判断
- なし
## Definition of Done
- [ ] x
EOF
expect_exit 2 "コードブロックの無い MODIFY を検出" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
sed -i 's/^- \*\*理由\*\*: 呼び出しを足す/- **理由**: 呼び出しを足す\n```ts\nif (!limit(count)) return\n```/' "$PROJECT/$RUN/implementation-plan.md"
expect_exit 0 "形の揃った plan は通す" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
cp "$PROJECT/$RUN/implementation-plan.md" "$PROJECT/$RUN/plan.bak"
awk '/^## システム図/{print; print "図は後で"; skip=1; next} skip && /^## /{skip=0} !skip' "$PROJECT/$RUN/plan.bak" > "$PROJECT/$RUN/implementation-plan.md"
expect_exit 2 "システム図のセクションに図が無ければ検出" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
mv "$PROJECT/$RUN/plan.bak" "$PROJECT/$RUN/implementation-plan.md"
printf '\n#### [NEW] `src/x.ts`\n- **理由**: y\n```ts\n// 以下省略\n```\n' >> "$PROJECT/$RUN/implementation-plan.md"
expect_exit 2 "コードブロック内の省略を検出" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"

cat >> "$PROJECT/$RUN/implementation-plan.md" <<'PLAN'
#### [MODIFY] `src/y.tsx`
- **理由**: 日本語の doc・JSX・テンプレートリテラルを含む
```tsx
/** @param opts 省略時は既定値を使う */
{/* ヘッダー */}
const label = `${件数}件`
```
##### before
```ts
// TODO: 既存コードに元からある TODO
```
PLAN
sed -i '/以下省略/d' "$PROJECT/$RUN/implementation-plan.md"
expect_exit 0 "日本語の doc・JSX コメント・テンプレートリテラル・before の TODO は誤検出しない" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
printf '\n#### [NEW] `src/z.ts`\n- **理由**: y\n```ts\n// {ファイルパス}\n```\n' >> "$PROJECT/$RUN/implementation-plan.md"
expect_exit 2 "コードブロック内に残ったテンプレートのプレースホルダを検出" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"

printf '# Task: x\n\n- □ a\n' > "$PROJECT/$RUN/tasks.md"
expect_exit 2 "## Implementation の無い tasks を検出" $C "$(write_json Write "$PROJECT/$RUN/tasks.md")"
printf '# Task: x\n\n## Implementation\n\n- □ a\n' > "$PROJECT/$RUN/tasks.md"
expect_exit 0 "形の揃った tasks は通す" $C "$(write_json Write "$PROJECT/$RUN/tasks.md")"

cp "$TPL/tasks.md" "$PROJECT/$RUN/tasks.md"
expect_exit 2 "テンプレートのままの tasks はプレースホルダで落ちる" $C "$(write_json Write "$PROJECT/$RUN/tasks.md")"
expect_exit 0 "run フォルダの外の plan には掛からない" $C "$(write_json Write "$PROJECT/docs/implementation-plan.md")"

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

# ── guard-subagent-git.sh ─────────────────────────────
A=guard-subagent-git.sh
sub_bash_json() { jq -nc --arg s "$SID" --arg c "$1" '{session_id:$s, tool_name:"Bash", agent_id:"a-1", agent_type:"harness-loop-plugin:implementer", tool_input:{command:$c}}'; }
set_state looping
expect_exit 2 "サブエージェントの中の git add をブロック" $A "$(sub_bash_json 'git add -- src/a.ts')"
expect_exit 2 "サブエージェントの中の git commit をブロック" $A "$(sub_bash_json 'npm test && git commit -m x')"
expect_exit 2 "大域オプションを挟んだ git -C <dir> stash もブロック" $A "$(sub_bash_json 'git -C . stash')"
expect_exit 2 "大域オプション --git-dir=... を挟んだ git add もブロック" $A "$(sub_bash_json 'git --git-dir=.git add src/a.ts')"
expect_exit 2 "サブエージェントの中の git mv をブロック（インデックスに載る）" $A "$(sub_bash_json 'git mv src/a.ts src/b.ts')"
expect_exit 0 "サブエージェントの中でも読むだけの git は通す" $A "$(sub_bash_json 'git status --porcelain; git diff --stat')"
expect_exit 0 "引用符の中の git add は操作とみなさない" $A "$(sub_bash_json 'grep -rn "git add -- " docs')"
expect_exit 0 "親（agent_id の無い呼び出し）の git add は通す" $A "$(bash_json 'git add -- src/a.ts')"
set_state planning
expect_exit 2 "計画中もサブエージェントの中の git checkout をブロック" $A "$(sub_bash_json 'git checkout -b x')"
set_state done
expect_exit 0 "完了した run ではサブエージェントの git も通す" $A "$(sub_bash_json 'git add -- src/a.ts')"
set_state looping
expect_exit 0 "run の無いセッションには掛からない" $A "$(jq -nc '{session_id:"other", tool_name:"Bash", agent_id:"a-1", tool_input:{command:"git add -A"}}')"

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
