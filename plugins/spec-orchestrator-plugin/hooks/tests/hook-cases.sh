#!/bin/bash
# spec-orchestrator-plugin のフックの判定表。一時ディレクトリに run フォルダを作り、
# フック入力 JSON を流して終了コード・出力を確かめる。
#
# 使い方: bash plugins/spec-orchestrator-plugin/hooks/tests/hook-cases.sh
# 失敗が 1 件でもあれば exit 1

set -u
HOOKS=$(cd "$(dirname "$0")/.." && pwd)
TPL=$(cd "$HOOKS/../skills/spec-orchestrate/assets/templates" && pwd)
PROJECT=$(mktemp -d)
trap 'rm -rf "$PROJECT"' EXIT
export CLAUDE_PROJECT_DIR=$PROJECT

SID=sess-1
RUN=".plugin-workspace/.orchestrate/001-sample"
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
set_state requirements
expect_exit 2 "requirements 中は src への Write をブロック" $G "$(write_json Write "$PROJECT/src/a.ts")"
expect_exit 0 "requirements 中でも run フォルダへの Write は通す" $G "$(write_json Write "$PROJECT/$RUN/requirements.md")"
expect_exit 2 "requirements 中は src へのリダイレクトをブロック" $G "$(bash_json 'echo x > src/a.ts')"
expect_exit 0 "STATE の書き換えは通す" $G "$(bash_json "echo planning > $RUN/STATE")"
expect_exit 2 "run フォルダ宛てを混ぜた迂回をブロック" $G "$(bash_json "echo a > $RUN/x.md; rm src/a.ts")"
expect_exit 0 "2>&1 を含む読むだけのコマンドは通す" $G "$(bash_json 'ls src 2>&1 | head -5')"
expect_exit 0 "ヒアドキュメント本文の md 引用は書き込みとみなさない" $G "$(bash_json "cat > $RUN/a.md <<'EOF'
> 引用
EOF")"
expect_exit 0 "mktemp の一時ディレクトリへの書き込みは通す" $G "$(bash_json 'tmp=$(mktemp -d); echo x > "$tmp/a"')"
set_state planning
expect_exit 2 "planning 中も src への Edit をブロック" $G "$(write_json Edit "$PROJECT/src/a.ts")"
set_state implementing
expect_exit 0 "implementing 中は src への Write を通す" $G "$(write_json Write "$PROJECT/src/a.ts")"
set_state planning
expect_exit 0 "別セッションには掛からない" $G "$(jq -nc '{session_id:"other", tool_name:"Write", tool_input:{file_path:"src/a.ts"}}')"

# ── guard-requirements.sh ─────────────────────────────
R=guard-requirements.sh
rm -f "$PROJECT/$RUN/requirements.md"
expect_exit 2 "requirements が無ければ plan をブロック" $R "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
cp "$TPL/requirements.md" "$PROJECT/$RUN/requirements.md"
expect_exit 2 "□ が残っていれば plan をブロック" $R "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
sed -i 's/^□ .*/■ 確認済み（回答: A）/' "$PROJECT/$RUN/requirements.md"
expect_exit 2 "□ が解消済みでも未承認ならブロック" $R "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
sed -i 's/^\*\*ステータス\*\*: □ 未承認/**ステータス**: ■ 承認済み/' "$PROJECT/$RUN/requirements.md"
expect_exit 0 "承認済みなら plan を通す" $R "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"
expect_exit 0 "plan 以外のファイルには掛からない" $R "$(write_json Write "$PROJECT/$RUN/tasks.md")"

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
x
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
printf '\n#### [NEW] `src/x.ts`\n- **理由**: y\n```ts\n// 以下省略\n```\n' >> "$PROJECT/$RUN/implementation-plan.md"
expect_exit 2 "コードブロック内の省略を検出" $C "$(write_json Write "$PROJECT/$RUN/implementation-plan.md")"

printf '# Tasks: x\n\n- □ a\n' > "$PROJECT/$RUN/tasks.md"
expect_exit 2 "実装グループの無い tasks を検出" $C "$(write_json Write "$PROJECT/$RUN/tasks.md")"
printf '# Tasks: x\n\n## T1: a\n\n- □ a\n' > "$PROJECT/$RUN/tasks.md"
expect_exit 0 "形の揃った tasks は通す" $C "$(write_json Write "$PROJECT/$RUN/tasks.md")"

cat > "$PROJECT/$RUN/test-cases.md" <<'EOF'
# Test Cases: x
## ケース一覧
| ID | UC | 分類 | ケース | 入力 | 期待 | ファイル |
|---|---|---|---|---|---|---|
| TC-01 | UC-1 | 正常系 | a | b | c | d |
| TC-02 | UC-1 | 異常系 | a | b | c | d |
## トレース
| UC | ケース | 状態 |
|---|---|---|
| UC-1 | TC-01, TC-02 | ok |
## 意図的な未カバー（gap）
- なし
EOF
expect_exit 2 "requirements の UC-2 がトレースに無いことを検出" $C "$(write_json Write "$PROJECT/$RUN/test-cases.md")"
sed -i 's/^| UC-1 | TC-01, TC-02 | ok |/| UC-1 | TC-01, TC-02 | ok |\n| UC-2 | - | gap |/' "$PROJECT/$RUN/test-cases.md"
expect_exit 0 "全 UC がトレースにあれば通す" $C "$(write_json Write "$PROJECT/$RUN/test-cases.md")"
sed -i 's/^| TC-02 | UC-1 | 異常系/| TC-01 | UC-1 | 失敗系/' "$PROJECT/$RUN/test-cases.md"
expect_exit 2 "ID の重複と分類の不正値を検出" $C "$(write_json Write "$PROJECT/$RUN/test-cases.md")"
expect_exit 0 "run フォルダの外の md には掛からない" $C "$(write_json Write "$PROJECT/docs/tasks.md")"

# ── continue-until-done.sh ─────────────────────────────
S=continue-until-done.sh
stop_json() { jq -nc --arg s "$SID" --argjson a "$1" '{session_id:$s, stop_hook_active:$a}'; }
set_state implementing
expect_output yes "implementing 中の停止は引き止める" $S "$(stop_json false)" '"decision": "block"'
expect_output no "引き止めた続きの停止は通す" $S "$(stop_json true)" 'block'
set_state waiting
expect_output no "waiting なら引き止めない" $S "$(stop_json false)" 'block'
set_state requirements
expect_output no "requirements（ユーザーとの対話中）なら引き止めない" $S "$(stop_json false)" 'block'

echo "pass: $pass / fail: $fail"
[ "$fail" -eq 0 ]
