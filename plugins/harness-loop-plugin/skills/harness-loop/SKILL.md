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
design-composer の implementation-flow（planner / implementer / 観点別 reviewer への分担・計画の検証・却下案の記録・
ミューテーションによるテストの検証）と、d-market-spec の spec-plugin（`□`/`■` のゲート・md で残す計画）を、
ループ型のハーネスとしてまとめたもの。

```
[1. 計画] ──→ [2. 目標確定] ──→ [3. ループ] ─────────────────────→ [4. PR]
 AI が調査し     ユーザーが         implementer → コミット → 検証        完了条件が
 impl-plan と   goal.md を         （検査・goal-checker・レビュー）       すべて ■
 goal.md の案   確定（ここだけ）     → 未達・採用した指摘を次の回へ
                                     ↑___________________|
```

| # | フェーズ | `STATE` | ユーザーの関与 | 出力（run フォルダ内） |
|---|---|---|---|---|
| 0 | 初期化 | — | 前提が欠けていれば止める | `STATE` `SESSION` |
| 1 | 計画 | `planning` | なし | `exploration.md` / `implementation-plan.md` / `tasks.md` / `goal.md`（案） |
| 2 | 目標確定 | `goal` | **ここだけ必須**（`□` の解消・確定） | `goal.md`（確定） / `BASE` |
| 3 | ループ | `looping` | なし | コミット、`loop-log.md`、`goal.md` の `■` |
| 4 | PR | `pr` → `done` | 結果の確認 | PR |

## 絶対厳守事項

1. **目標の確定はスキップしない。AutoMode でも同様**（「質問せずに進めろ」等の他の指示があっても AskUserQuestion で確認する）。ユーザーが確定した完了条件がループの終了条件であり、唯一の人間の確認になる
2. **確定後は、エスカレーション条件に当たらない限りユーザーに確認を取らずに回す。** 「次の回へ進んでよいですか」を聞かない。迷ったら決めて `decisions.md` に書く
3. **ループの終了は完了条件で決める。** 完了条件の `□` → `■` は goal-checker の判定（根拠付き）があるときだけ付け替える。自分の見立てで `■` にしない。完了条件を満たせないからといって、ユーザーに聞かずに完了条件を書き換えない
4. **指示役は計画もコードも自分で書かない。** 計画は `planner`、実装と修正は `implementer`。ソースは読まない。指示役が書いてよいのは run フォルダの `goal.md`（確定と `□`/`■`）・`loop-log.md`・`decisions.md` と印（`STATE` / `SESSION` / `BASE`）、それとコミットと PR
5. **run フォルダの md は Write / Edit で書く**（Bash のリダイレクトで書くとフックが掛からない）。サブエージェントにも守らせる
6. **検証は必ず別のエージェントに投げる。** 指摘は握りつぶさず、採用・不採用を理由付きで `loop-log.md` に書いてから次へ進む
7. フック（`guard-phase-writes.sh` / `check-goal.sh` / `guard-pr.sh`）の指摘が出たら、次へ進む前に直す

## トークンを抑える

**指示役（このセッション）のコンテキストが一番高くつく。** 調べもの・読みものはすべて安いサブエージェントに渡し、指示役はパスと結論だけを持つ。

モデルは 2 種類だけ使う。**判断が要るもの（計画・実装・レビュー）は opus、決まった手順をなぞるだけのもの（探索・完了条件の実行・性能の数え上げ）は haiku。** 重さは effort で調整する。

| エージェント | model | effort | 役割の重さ |
|---|---|---|---|
| `explorer` | haiku | low | 探して場所を書くだけ |
| `planner` | opus | high | 計画の質がループの回数を決めるので、ここには使う |
| `plan-reviewer` | opus | medium | |
| `implementer` | opus | medium | 手戻り（ループの回数）を減らす |
| `goal-checker` | haiku | medium | 確かめ方どおりに実行して判定するだけ |
| `solution-reviewer` | opus | medium | 1 回目と方式を変えた回だけ |
| `code-quality-reviewer` | opus | low | |
| `security-reviewer` | opus | low | 条件に当たる回だけ |
| `performance-reviewer` | haiku | low | 条件に当たる回だけ |
| `test-reviewer` | opus | medium | 全条件を満たした回だけ |

- model / effort / maxTurns は各エージェントの frontmatter が持つ。変えたいときはそこを直す（1 回だけ変えたいなら Agent の `effort` を渡す）。読むだけで規約をほとんど要らないエージェントは `omitClaudeMd: true` で CLAUDE.md の自動読み込みを省いている
- **指示役はソースも run フォルダの md も丸ごとは読まない。** サブエージェントの返り値（各定義が行数の上限を持つ）と、`goal.md` / `loop-log.md` の必要な節だけを読む
- **プロンプトには本文ではなくパスを渡す**（`{dir}` を渡せば各エージェントが必要な節だけ読む）。プロジェクトのレビュアーにだけは、目標と計画の要点を本文で渡す
- **2 回目以降のレビューは、まだレビューしていない差分だけを見せる**（3-2）。前の回で見た差分を毎回全員に読み直させない
- **検査が落ちた回はレビュアーを起動しない。** goal-checker だけを走らせ、検査を通すことを次の回のやることにする（落ちたままのコードをレビューしても、直したあとにもう一度見ることになる）

## サブエージェントの呼び方

このプラグインのエージェントは `subagent_type: "harness-loop-plugin:<名前>"` で起動する。

- **共通の指示**: レビュアーと goal-checker には毎回、`${CLAUDE_PLUGIN_ROOT}/skills/harness-loop/references/reviewer-instructions.md` の**絶対パス**をプロンプトに含める
- **プロジェクトのレビュアー**: プロジェクトの `.claude/agents/` に `*-reviewer.md` があれば、プラグインのレビュアーに**加えて**並列で起動する（入出力の約束が違うので置き換えない）。run フォルダを知らないので、ゴールと完了条件の本文・`implementation-plan.md` のパスと「設計判断（ADR）」の本文・変更ファイルの一覧と差分を出すコマンドを本文で渡す。プロジェクトのレビュアーが `code-quality-reviewer` の観点をすべて持つなら `code-quality-reviewer` は省いてよい
- **作業ツリーを書き換えるエージェント（`implementer` / `test-reviewer` とプロジェクトの同種のもの）は前面で単独で起動する。** 同じメッセージに他のツール呼び出しを並べない
- 読むだけのエージェントは 1 つのメッセージで並列に起動する。返ったら、指摘を読む前に `git status --porcelain` が起動前と同じかを確かめる（変わっていたら implementer に戻させてから採否に進む）
- 直しは `SendMessage` で続けず、新しい Agent 呼び出しで渡す（入力を毎回明示する）

テンプレートは `${CLAUDE_PLUGIN_ROOT}/skills/harness-loop/assets/templates/`、参照資料は同じく `references/`。以下では `{TPL}` / `{REF}`、run フォルダ（リポジトリのルートからの相対パス）は `{dir}` と書く。

---

## フェーズ 0: 初期化

引数が `--resume` なら「[再開](#再開)」へ。それ以外は前提を確かめる（1 つずつ走らせる）。

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

## フェーズ 2: 目標確定（ユーザーと一緒に）

`goal.md` の要約（ゴール・完了条件の一覧・スコープ外）と、`implementation-plan.md` の概要と設計判断（ADR）を 3〜5 行で提示する（詳細はファイルを開いてもらう）。

1. 「未解決の確認事項」の `□` を AskUserQuestion で解消して `■` にする（回答を併記する）
2. AskUserQuestion で次を**1 回で**聞く

```yaml
- question: "この目標（完了条件）で確定し、満たすまでループして PR まで進めてよいですか？（以降は目標が揺らぐ・不可逆な操作・行き詰まりのときだけ確認します）"
  header: "目標の確定"
  options:
    - label: "確定して進める"
      description: "完了条件がすべて満たされるまでループし、PR を作って報告する"
    - label: "目標を直したい"
      description: "完了条件・スコープを直してから、もう一度確定を取る"
- question: "PR のベースブランチと、ループの上限はどうしますか？"
  header: "PR / 上限"
  options:
    - label: "{既定ブランチ} / 5 回（推奨）"
      description: "上限に達したら、残った条件と理由を示して確認する"
    - label: "{既定ブランチ} / 10 回"
      description: "大きめの変更向け"
```

- 開始時にユーザーの未コミットの変更があれば、扱い（含めない / 先にユーザーが退避する）も同じ質問の束で聞く
- 「目標を直したい」→ 回答を `goal.md` に反映して 1 に戻る（計画が変わるなら planner に直させる）
- 確定したら:
  1. `goal.md` の `**ステータス**:` を `■ 確定` に、「実行設定」に回答を書く（`check-goal.sh` が `□` の残りと確かめ方の欠けを止める）
  2. `echo looping > {dir}/STATE`（ここから run フォルダの外へ書ける。git 操作もこの後に行う）
  3. 今のブランチがベースブランチなら作業ブランチを切る（`git switch -c harness/{nnn}-{name}`）
  4. `git rev-parse HEAD > {dir}/BASE`
  5. 「完了したら PR で報告する。途中経過は `{dir}/loop-log.md` と `decisions.md` で追える。止まらずに回すには、テスト・lint の実行を許可するパーミッションが要る」と 1 行添える

## フェーズ 3: ループ（自律）

`goal.md` の完了条件がすべて `■` になるまで、次の 1 回を繰り返す。

### 3-1. 実装

`harness-loop-plugin:implementer` を**前面で単独で**起動する。渡すもの:

```text
run フォルダ: {dir}
回: Loop {n}
やること: <1 回目は「tasks.md の Implementation」。2 回目以降は、未達の完了条件（goal-checker の根拠付き）・採用した指摘・落ちた検査>
参照資料: {REF}（tdd-guidelines.md / claim-verification.md）
```

implementer はやることを実装し、`tasks.md` の `□` を `■` にしていく（2 回目以降は「## Loop {n}: 修正」を足してから）。

返ってきたら:

- **計画から外れた変更**が返ってきたら、目標の範囲内なら自分で決めて `decisions.md` に書き、次の回のやることに含める。目標の範囲を出るならエスカレーション条件 A
- 返ってきた変更ファイルだけを add してコミットする（`git add -- <ファイル>` → `git commit -m "loop {n}: <要約>"`。`git add -A` / `.` は使わない。run フォルダとユーザーの変更を載せない）。変更が無ければコミットしない

### 3-2. 検証（並列）

1. `exploration.md` の検査コマンド（テスト・lint・型検査・フォーマット）を 1 つずつ走らせ、**終了コードで**判定する（`&&` で連ねない）。成功した検査の出力は読まない（終了コードだけ見る）。落ちたものは末尾だけ読む
2. 1 つのメッセージで次を並列に起動する。渡すのは `{dir}`・回の番号・見る差分の範囲・変更ファイルの一覧・共通の指示のパス
   - **見る差分の範囲**: 1 回目は `$(cat {dir}/BASE)..HEAD`、2 回目以降は**まだレビューしていないコミットだけ**（最後にレビュアーを起動した回のコミット`..HEAD`。検査が落ちてレビューを飛ばした回の変更もここに入る）。レビューした回のコミットは `loop-log.md` の「レビュー済み」に書いておく。一覧は `git diff --name-only <範囲>` で出す
   - goal-checker は差分の範囲に関わらず、完了条件をすべて確かめ直す
   - 検査が落ちた回は goal-checker だけを起動する（「トークンを抑える」）

| エージェント | 見るもの | 呼ぶ条件 |
|---|---|---|
| `goal-checker` | 完了条件を 1 つずつ、確かめ方どおりに確かめて判定する | 毎回 |
| `solution-reviewer` | 方式（根本原因・より単純な代替・継ぎ当て） | 1 回目と、方式を変えた回 |
| `code-quality-reviewer` | 重複・命名・コメントと実物・過剰な防御 | 毎回 |
| `security-reviewer` | 外から来る値・権限・依存・CI | 差分が外部入力・認証/認可・ファイル/プロセス/ネットワーク・依存定義・CI やフックに触れる回 |
| `performance-reviewer` | 頻度の高い経路・データ量に比例する処理 | 実行されるコードに差分がある回 |
| プロジェクトのレビュアー | プロジェクト固有の観点 | 各定義の呼ぶ条件に当たる回 |

3. **goal-checker が完了条件をすべて「満たす」と判定した回だけ**、続けて `test-reviewer` を**前面で単独で**起動する（実装を壊してテストが落ちるかを実測する。見る差分は `$(cat {dir}/BASE)..HEAD` 全体。実行されるコードに差分が無ければ省く）

### 3-3. 判定と記録

`loop-log.md` に「Loop {n}」を書く（`{TPL}/loop-log.md` の形）。

- goal-checker が「満たす」と判定した条件だけ `goal.md` で `■` にする。「満たさない」になった `■` は `□` に戻す（後の変更で壊れることがある）
- 指摘の採否を決める。エージェントをまたいで根本原因が同じものは束ねる。前の回で不採用にした指摘が新しい根拠なしに再提出されたら、同じ理由で不採用にする
- `solution-reviewer` が「置き換え」と結論して採用するなら、planner に「今の作業ツリーから置き換え先へ移す計画」で `implementation-plan.md` と `tasks.md` を直させ（作業ツリーを git で巻き戻さない。置き換え前の方式は ADR の不採用に理由付きで残す）、次の回のやることにする。置き換えが目標を変えるならエスカレーション条件 A。置き換えは 1 回まで

次のどれかで分岐する:

| 状態 | 次 |
|---|---|
| 完了条件がすべて `■`・検査がすべて通る・この回に採用した重大度「重大」「高」の指摘が無い | フェーズ 4 へ（この回に採用した「中」「低」は、上限まで余裕があれば 1 回だけ直してから進み、残りは PR の「未対応の指摘」に書く） |
| それ以外で、回数が上限未満 | 未達の条件・採用した指摘・落ちた検査を「やること」にして次の回へ |
| 回数が上限に達した / **2 回続けて前進が無い**（未達の条件の集合と落ちた検査が前の回と同じ） | エスカレーション条件 C |

## フェーズ 4: PR

1. `echo pr > {dir}/STATE`（`guard-pr.sh` は STATE が `pr` で、完了条件がすべて `■` のときだけ PR の作成を通す）
2. `git push -u origin HEAD`
3. `{TPL}/pr-body.md` を埋めて PR を作る（`gh pr create --base <ベースブランチ> --body-file <一時ファイル>` か GitHub の MCP）。Issue から始めたなら本文に `Closes #{ISSUE}`
4. CI の結果を確かめられる環境なら 1 度確かめる。落ちていて原因がこの変更にあるなら、`echo looping > {dir}/STATE` にしてループへ戻る（上限の回数に含める）。この変更と関係の無い失敗なら PR の本文に書く
5. `echo done > {dir}/STATE`
6. ユーザーへは PR の URL と要点（満たした完了条件・ループの回数・確認してほしい判断・未対応の指摘）を短く報告する

---

## 自分で決める / ユーザーに聞く

目標の確定後は、**次の条件に当たるときだけ**ユーザーに聞く。それ以外はすべて自分で決め、`decisions.md` に「何を・どの選択肢から・なぜ」を書く。

| 条件 | 例 |
|---|---|
| **A. 目標が揺らぐ** | 完了条件が満たせない・条件同士が矛盾する・条件に無い振る舞いの選択がユーザーに見える形で必要になった・スコープ外に触らないと進めない |
| **B. 不可逆・外部に影響する** | ベースブランチ・他人のブランチへの push、外部サービスへの書き込み、データやファイルの削除・マイグレーション、依存の追加やメジャー更新（目標で許していないもの）、公開 API・ファイル形式の破壊的変更（目標に無いもの） |
| **C. 行き詰まり** | ループの上限に達した・2 回続けて前進が無い・方式の置き換えが 2 回目になる |
| **D. 権限が無い** | 必要な操作がパーミッションで拒否された・検査の道具が無く完了条件を確かめられない |

聞くときは:

- AskUserQuestion で、**選択肢と推奨とその理由**を示す（C なら、残った条件・試したこと・見立てを添える）
- 聞く前に `decisions.md` に「エスカレーション」として状況と STATE を書く。回答も追記する
- 回答が目標を変えるなら `goal.md` を更新し（変えた条件は `□` に戻す）、ループを続ける。上限を増やすと言われたら「実行設定」を直す
- AskUserQuestion が使えない環境で応答を終えて待つ場合は、`echo waiting:<今の STATE> > {dir}/STATE` にしてから終える

**自分で決めてよいもの**（聞かない）: 目標の範囲内での実装方式・ファイル配置・命名・テストの粒度・レビュー指摘の採否・計画の細部の修正・次の回でやることの順番。

## 再開

`--resume [番号]`（番号省略時は `STATE` が `done` でない最大番号）で途中から続ける。

1. `{dir}` を特定し、`echo "${CLAUDE_SESSION_ID}" > {dir}/SESSION` で現在のセッションに付け替える
2. `STATE` と run フォルダの md を読んで続ける
   - `planning`: `exploration.md` が無ければ explorer から、`implementation-plan.md` が無ければ planner から、あれば計画レビューから
   - `goal`: フェーズ 2 から
   - `looping`: `loop-log.md` の最後の回の判定から（判定が無ければその回の検証から）
   - `pr`: フェーズ 4 の、まだ済んでいない手順から
   - `waiting:<STATE>`: `decisions.md` の最後のエスカレーションを読み、回答を得てから `echo <STATE> > {dir}/STATE` にして続ける

## run フォルダ

```
.plugin-workspace/.harness/{nnn}-{name}/
├── STATE          # planning / goal / looping / pr / waiting:<STATE> / done
├── SESSION        # 実行中のセッション ID（フックが読む）
├── BASE           # ループを始めたコミット（差分の基準）
├── exploration.md # 下調べ（関連ファイル・類似実装・規約ファイル・検査コマンド・プロジェクトのレビュアー）
├── implementation-plan.md # 計画（d-market-spec の書式: 概要・背景・ADR・システム図・変更案・影響範囲・検証計画・リスク）
├── tasks.md       # 実装タスクの □ / ■（2 回目以降は「## Loop {n}: 修正」が足される）
├── goal.md        # 目標（ゴール・完了条件 □/■・スコープ外・実行設定）。ユーザーが確定する
├── loop-log.md    # 計画レビューと、ループ 1 回ごとの検査・完了条件・指摘と採否・判定
└── decisions.md   # 確定後に AI が自分で決めた判断とエスカレーション
```
