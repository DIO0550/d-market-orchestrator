# フェーズ 0〜1: 初期化と計画

`SKILL.md` から、このフェーズに入るときに 1 回だけ読む。記号（`{dir}` `{TPL}` `{REF}` `{ISSUE}`）の意味とエスカレーション条件（A〜D、[../escalation-and-resume.md](../escalation-and-resume.md)）は `SKILL.md` から辿る。

## フェーズ 0: 初期化

引数が `--resume` なら [escalation-and-resume.md](../escalation-and-resume.md) の「再開」へ。それ以外は前提を確かめる（1 つずつ走らせる）。

```bash
git rev-parse --show-toplevel
git rev-parse HEAD
command -v jq
command -v gh
```

- **git のリポジトリでない・コミットが無い**なら止めてユーザーに伝える（コミットと PR がこのハーネスの出力なので成り立たない）
- **jq が無い**ならフックが動かないことを伝えて続けるかを聞く。**gh も GitHub の MCP も無い**なら、PR は作れずブランチの push までになることを伝える
- 以降のコマンドは**リポジトリのルートで**走らせる

```bash
ls -1d .plugin-workspace/.harness/[0-9][0-9][0-9]-* 2>/dev/null | sort -r | head -1
mkdir -p .plugin-workspace/.harness/{nnn}-{name}
echo planning > .plugin-workspace/.harness/{nnn}-{name}/STATE
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.harness/{nnn}-{name}/SESSION
```

- `{nnn}` は既存の最大番号 + 1（無ければ `001`）、`{name}` はケバブケース
- `git check-ignore -q .plugin-workspace` が失敗するなら `.git/info/exclude` に `.plugin-workspace/` を足す（run フォルダをコミットと差分に混ぜない。リポジトリの共有設定は変えない）
- 依頼が `#123` を含むなら Issue 番号として控える（`{ISSUE}`）
- `git status --porcelain` が空でなければ、目標確定のときに扱いを聞く（ユーザーの変更をループのコミットに混ぜない）

## フェーズ 1: 計画（自律）

1. `harness-loop-plugin:explorer` を起動する。渡すもの: 依頼文（要約しない）・`{ISSUE}`・`{dir}`・`{TPL}`。explorer は関連ファイル・類似実装・規約ファイルの場所・検査コマンド・プロジェクトのレビュアーを `{dir}/exploration.md` に書き、10 行以内の要約を返す
2. `harness-loop-plugin:planner` を起動する。渡すもの: 依頼文（要約しない）・`{ISSUE}`・`{dir}`・`{TPL}`・`{REF}`。planner は exploration.md から読み始め、コードを調べて d-market-spec の書式で `{dir}/implementation-plan.md`・`{dir}/tasks.md` と `{dir}/goal.md`（案。ステータス `□ 未確定`）を書き（`check-plan-format.sh` が形を検査する）、確かめた事実と、ユーザーにしか決められない分岐を返す
3. `harness-loop-plugin:plan-reviewer` に `{dir}` と共通の指示のパスを渡して検証させる（プロジェクトに計画のレビュアーがあれば並列で加える）
4. 採用した指摘があれば planner に直させる（1 回まで。2 回目も残る指摘は `goal.md` の目標確定で一緒に見せる）。採否は `loop-log.md` の冒頭に「計画レビュー」として書く
5. `echo goal > {dir}/STATE`
