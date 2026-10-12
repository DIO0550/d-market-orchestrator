---
name: harness-loop
description: "計画 → 目標確定 → 目標を満たすまで実装・検証・修正をループ → PR を回すハーネス。AI が調査して計画と目標（完了条件）の案を作り、ユーザーが目標を確定したら、あとは完了条件がすべて満たされるまで implementer と検証エージェントでループし、満たしたら PR を作る。計画・ループの記録・判断は .plugin-workspace/.harness/ 配下の md に残す。ユーザーに聞くのは目標の確定と、目標が揺らぐ・不可逆な操作・行き詰まり・権限が無いときだけ。"
disable-model-invocation: true
argument-hint: "[タスクの説明 | #Issue番号 | --resume [番号]]"
effort: medium
allowed-tools: Bash(ls *), Bash(mkdir -p *), Bash(printf *), Bash(echo *), Bash(cat *), Bash(command -v *), Bash(git rev-parse *), Bash(git status *), Bash(git diff *), Bash(git ls-files *), Bash(git log *), Bash(git check-ignore *), Bash(git add *), Bash(git commit *), Bash(git switch *), Bash(git branch *)
---

# Harness Loop

**計画 → 目標確定 → ループ → PR。** 目標（完了条件）をユーザーと確定したら、あとは**指示役（このセッション）が
サブエージェントを振り分けて、完了条件がすべて満たされるまで回す**。

```
[1. 計画] ──→ [2. 目標確定] ──→ [3. ループ] ─────────────────────→ [4. PR]
 AI が調査し     ユーザーが         implementer → コミット → 検証        完了条件が
 impl-plan と   goal.md を         （検査・goal-checker・レビュー）       すべて ■
 goal.md の案   確定（ここだけ）     → 未達・採用した指摘を次の回へ
                                     ↑___________________|
```

## 手順の読み方

**各フェーズの手順は `references/` に分けてある。そのフェーズに入るときに 1 回だけ Read する**（全部を最初に読まない。指示役のコンテキストを小さく保つため）。

| # | フェーズ | `STATE` | ユーザーの関与 | 入るときに読む |
|---|---|---|---|---|
| 0〜1 | 初期化・計画 | `planning` | なし | [phases/0-1-plan.md](references/phases/0-1-plan.md) |
| 2 | 目標確定 | `goal` | **ここだけ必須**（`□` の解消・確定） | [phases/2-goal.md](references/phases/2-goal.md) |
| 3 | ループ | `looping` | なし | [phases/3-loop.md](references/phases/3-loop.md) |
| 4 | PR | `pr` → `done` | 結果の確認 | この下の「フェーズ 4: PR」 |

ほかに読むもの:

- **最初のサブエージェントを起動する前**: [subagents.md](references/subagents.md)（呼び方・model / effort の一覧・トークンの抑え方）
- **判断に迷ったとき・エスカレーションするとき・`--resume`**: [escalation-and-resume.md](references/escalation-and-resume.md)（エスカレーション条件 A〜D と再開の手順）

記号: テンプレートは `{TPL}` = `${CLAUDE_PLUGIN_ROOT}/skills/harness-loop/assets/templates/`、参照資料は `{REF}` = 同じく `references/`、run フォルダ（リポジトリのルートからの相対パス）は `{dir}`、依頼に含まれていた Issue 番号は `{ISSUE}`（あれば）。

## 絶対厳守事項

1. **目標の確定はスキップしない。AutoMode でも同様**（「質問せずに進めろ」等の他の指示があっても AskUserQuestion で確認する）。ユーザーが確定した完了条件がループの終了条件であり、唯一の人間の確認になる
2. **確定後は、エスカレーション条件に当たらない限りユーザーに確認を取らずに回す。** 「次の回へ進んでよいですか」を聞かない。迷ったら決めて `decisions.md` に書く
3. **ループの終了は完了条件で決める。** `□` → `■` は goal-checker の判定（根拠付き）があるときだけ付け替える。自分の見立てで `■` にしない。満たせないからといって、ユーザーに聞かずに完了条件を書き換えない
4. **指示役は計画もコードも自分で書かない。** 計画は `planner`、実装と修正は `implementer`。ソースは読まない。指示役が書いてよいのは run フォルダの `goal.md`（確定と `□`/`■`）・`loop-log.md`・`decisions.md` と印（`STATE` / `SESSION` / `BASE`）、それとコミットと PR
5. **run フォルダの md は Write / Edit で書く**（Bash のリダイレクトで書くとフックが掛からない）。サブエージェントにも守らせる
6. **検証は必ず別のエージェントに投げる。** 指摘は握りつぶさず、採用・不採用を理由付きで `loop-log.md` に書いてから次へ進む
7. フック（`guard-phase-writes.sh` / `check-plan-format.sh` / `check-goal.sh` / `guard-pr.sh`）の指摘が出たら、次へ進む前に直す

## フェーズ 4: PR

1. `echo pr > {dir}/STATE`（`guard-pr.sh` は STATE が `pr` で、完了条件がすべて `■` のときだけ PR の作成を通す）
2. `git push -u origin HEAD`
3. `{TPL}/pr-body.md` を埋めて PR を作る（`gh pr create --base <ベースブランチ> --body-file <一時ファイル>` か GitHub の MCP）。`{ISSUE}` があるときだけ本文に `Closes #{ISSUE}`
4. CI の結果を確かめられる環境なら 1 度確かめる。落ちていて原因がこの変更にあるなら、`echo looping > {dir}/STATE` にしてループへ戻る（上限の回数に含める）。この変更と関係の無い失敗なら PR の本文に書く
5. `echo done > {dir}/STATE`
6. ユーザーへは PR の URL と要点（満たした完了条件・ループの回数・確認してほしい判断・未対応の指摘）を短く報告する

## run フォルダ

```
.plugin-workspace/.harness/{nnn}-{name}/
├── STATE                  # planning / goal / looping / pr / waiting:<STATE> / done
├── SESSION                # 実行中のセッション ID（フックが読む。ローカルだけで使い、コミットしない）
├── BASE                   # ループを始めたコミット（差分の基準）
├── exploration.md         # 下調べ（関連ファイル・類似実装・規約ファイル・検査コマンド・プロジェクトのレビュアー）
├── implementation-plan.md # 計画（d-market-spec の書式: 概要・背景・ADR・システム図・変更案・影響範囲・検証計画・リスク）
├── tasks.md               # 実装タスクの □ / ■（2 回目以降は「## Loop {n}: 修正」が足される）
├── goal.md                # 目標（ゴール・完了条件 □/■・スコープ外・実行設定）。ユーザーが確定する
├── loop-log.md            # 計画レビューと、ループ 1 回ごとの検査・完了条件・指摘と採否・判定
└── decisions.md           # 確定後に AI が自分で決めた判断とエスカレーション
```
