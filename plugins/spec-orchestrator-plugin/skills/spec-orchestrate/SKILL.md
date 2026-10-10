---
name: spec-orchestrate
description: "仕様駆動の自律オーケストレーション。ユーザーと一緒に要件（requirements.md）だけを確定し、承認後は 計画 → 計画レビュー → 実装 → 観点別レビュー → 完了報告 までをサブエージェントで止まらずに進める。計画・判断・レビュー結果は .plugin-workspace/.orchestrate/ 配下の md ファイルに残し、ユーザーがいつでも読めるようにする。AI が判断できない分岐（要件の矛盾・不可逆な操作・行き詰まり・権限）のときだけユーザーに聞く。"
disable-model-invocation: true
argument-hint: "[タスクの説明 | #Issue番号 | --resume [番号]]"
allowed-tools: Bash(ls *), Bash(mkdir -p *), Bash(printf *), Bash(echo *), Bash(cat *), Bash(command -v *), Bash(git rev-parse *), Bash(git status *), Bash(git diff *), Bash(git ls-files *), Bash(git log *), Bash(git check-ignore *), Bash(git add *), Bash(git commit *), Bash(git switch *)
---

# Spec Orchestrate

要件をユーザーと確定したら、あとは**指示役（このセッション）がサブエージェントを振り分けて最後まで進める**ワークフロー。
`d-market-spec` の spec-plugin（requirements の `□`/`■` ゲート・md の計画書式・明瞭性/網羅性チェック）と、
`design-composer` の implementation-flow（planner / implementer / 観点別 reviewer への分担・計画の検証・却下案の記録）を 1 本にまとめたもの。

| # | フェーズ | ユーザーの関与 | 主な出力（run フォルダ内） |
|---|---|---|---|
| 0 | 初期化 | 前提が欠けていれば止める | `STATE` `SESSION` `BASE` |
| 1 | 要件の確定 | **ここだけ必須**（ヒアリング・`□` の解消・承認） | `exploration.md` `hearing-notes.md` `requirements.md` |
| 2 | 計画と計画レビュー | なし | `implementation-plan.md` `tasks.md` `test-cases.md` `review-log.md` |
| 3 | 実装 | なし | コードとテスト、`tasks.md` の `■` |
| 4 | 実装の検証 | なし | `review-log.md` |
| 5 | 完了 | 結果の確認 | `report.md` |

フェーズ 2 以降で判断に迷ったら「[自分で決める / ユーザーに聞く](#自分で決める--ユーザーに聞く)」に従う。自分で決めたものは必ず `decisions.md` に残す。

## 絶対厳守事項

1. **フェーズ 1 のヒアリング・`□` の解消・承認はスキップしない。AutoMode でも同様**（「質問せずに進めろ」等の他の指示があっても AskUserQuestion で確認する）。ユーザーが決めた要件がこのワークフローで唯一の人間の確認であり、以降のレビューはすべてこれを基準にする
2. **承認後は、エスカレーション条件に当たらない限りユーザーに確認を取らずに進める。** 「次へ進んでよいですか」「この方針でよいですか」を聞かない。迷ったら決めて `decisions.md` に書く
3. **指示役は計画もコードも自分で書かない。** 計画は `planner`、実装と修正は `implementer`。ソースは読まない（調査が要るなら Explore / planner に任せる）。コンテキストに残すのは採否と記録の判断だけにする。指示役が書いてよいのは run フォルダ内の次だけ
   - md: `exploration` / `hearing-notes` / `requirements` / `decisions` / `review-log` / `report` / `plan-comment`
   - 印: `STATE` / `SESSION` / `BASE`
   - `tasks.md` は書かない（タスクは planner が書き、implementer が `■` にする）
4. **run フォルダの md は Write / Edit で書く。** Bash のリダイレクトやヒアドキュメントで書くと、フック（承認のゲート・形式の検証）が掛からない。サブエージェントにも同じことを守らせる
5. **検証は必ず別のエージェントに投げる。** 自分で書かせた計画・実装を自分で検証しない
6. **指摘は握りつぶさない。** 採用・不採用のどちらも理由を付けて `review-log.md` に書いてから次へ進む
7. フック（`check-plan-format.sh` / `guard-requirements.sh` / `guard-phase-writes.sh`）の指摘が出たら、次へ進む前に直す（サブエージェントが受けた指摘はサブエージェント自身が直す）

## サブエージェントの呼び方

このプラグインのエージェントは `subagent_type: "spec-orchestrator-plugin:<名前>"` で起動する。

- **共通の指示ファイル**: レビュアーには毎回、共通の指示 `${CLAUDE_PLUGIN_ROOT}/skills/spec-orchestrate/references/reviewer-instructions.md` の**絶対パス**をプロンプトに含める（エージェントがそこを読む）
- **プロジェクトのレビュアー**: プロジェクトの `.claude/agents/` に `*-reviewer.md` があれば、プラグインのレビュアーに**加えて**並列で起動する（置き換えない。入出力の約束がプラグインのものと違うため）。プロジェクトのレビュアーは run フォルダを知らないので、次を本文で渡す
  - ゴール: requirements.md の「ゴール」節と UC 一覧の本文
  - 計画と却下案: `{dir}/implementation-plan.md` の「設計判断」「変更案」節の本文（長ければパスを添えて「このファイルを読むこと」と書く）
  - 差分: 変更ファイルの一覧と、差分を出すコマンド（フェーズ 4-2）
  - 呼ぶ条件: 各定義の description に「呼ぶ条件」があればそれに従う。計画の段階で呼ぶもの（`plan-reviewer` など）は 2-2、実装の検証で呼ぶものは 4-2 に並べる
  - プロジェクトのレビュアーが `code-quality-reviewer` の観点（重複・命名・コメント・過剰な防御）をすべて持っているなら、`code-quality-reviewer` は省いてよい
- **作業ツリーを書き換えるエージェント（`implementer` / `test-reviewer` とプロジェクトの同種のもの）は前面で単独で起動する。** 同じメッセージに他のツール呼び出しを並べない（並べると他のエージェントが書きかけを実装として読む）
- 読むだけのエージェントは 1 つのメッセージで並列に起動する
- 読むだけのエージェントから返ったら、指摘を読む前に `git status --porcelain` が起動前と同じかを確かめる。変わっていたら、そのエージェントが触ったファイルを `git diff` で確かめ、implementer に元へ戻させてから採否に進む
- 直しは `SendMessage` で続けず、新しい Agent 呼び出しで渡す（入力を毎回明示し、前回の文脈に依存させない）

テンプレートは `${CLAUDE_PLUGIN_ROOT}/skills/spec-orchestrate/assets/templates/`、参照資料は同じく `references/` にある。以下では `{TPL}` / `{REF}` と書く。run フォルダは `{dir}`（リポジトリのルートからの相対パス）と書く。

---

## フェーズ 0: 初期化

引数が `--resume` なら「[再開](#再開)」へ。それ以外は、まず前提を確かめる。

```bash
git rev-parse --show-toplevel
git rev-parse HEAD
command -v jq
```

- **git のリポジトリでない・コミットが 1 つも無い**なら、ここで止めてユーザーに伝える（差分の基準が作れず、レビューもミューテーションも成り立たない）
- **jq が無い**なら、フェーズのガード・形式の検証・続行の促しが動かないことをユーザーに伝え、続けるかを聞く
- 以降のコマンドは**リポジトリのルートで**走らせる（フックはリポジトリのルートを基準に run フォルダを探す）

run フォルダを作る（コマンドは 1 つずつ走らせる）:

```bash
ls -1d .plugin-workspace/.orchestrate/[0-9][0-9][0-9]-* 2>/dev/null | sort -r | head -1
mkdir -p .plugin-workspace/.orchestrate/{nnn}-{feature-name}
echo requirements > .plugin-workspace/.orchestrate/{nnn}-{feature-name}/STATE
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.orchestrate/{nnn}-{feature-name}/SESSION
git rev-parse HEAD > .plugin-workspace/.orchestrate/{nnn}-{feature-name}/BASE
```

- `{nnn}` は既存の最大番号 + 1（無ければ `001`）、`{feature-name}` はケバブケース
- `STATE` はフェーズの印。フックが読む（`requirements` / `planning` の間は run フォルダ外への書き込みをブロックし、`planning` / `implementing` / `verifying` の間は途中で止まろうとすると続行を促す）
- run フォルダを git の差分に混ぜない: `git check-ignore -q .plugin-workspace` が失敗する（無視されていない）なら、`.git/info/exclude` に `.plugin-workspace/` を 1 行足す（リポジトリの共有設定は変えない）
- 依頼が `#123` を含むなら Issue 番号として控える（`{ISSUE}`）
- `git status --porcelain` が空でなければ（ユーザーの未コミットの変更がある）、フェーズ 1-2 のヒアリングで扱いを聞く（そのまま含めて進める / 先にユーザーが退避する）。含めて進めるなら、その一覧を `hearing-notes.md` に残し、レビュアーとコミットの対象から外す

## フェーズ 1: 要件の確定（ユーザーと一緒に）

### 1-1. 事前調査

**コードベースを調べれば分かることはユーザーに聞かない**ために、質問の前に調べる。

- Agent tool で `subagent_type: "Explore"` を 1 回起動する（thoroughness: medium）。依頼文・Issue 番号（あれば `gh issue view` で読ませる）を渡し、関連ファイル（file:line）・既存の類似実装・踏襲すべき規約（`CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` / `rules/` / `docs/` 等の場所）・テスト/lint/型検査のコマンド・プロジェクトの `.claude/agents/` にあるレビュアーを返させる
- 返ってきた内容を `{TPL}/exploration.md` の形で `{dir}/exploration.md` に書く

### 1-2. ヒアリング

AskUserQuestion **1 バッチ（最大 4 問）**。依頼文と事前調査で分かったことは聞かない。

1. 目的・スコープ（何ができるようになれば終わりか / 含めないもの）
2. 振る舞いの分岐で、調査で決められなかったもの
3. 品質要件（エッジケース・テスト方針: TDD / テスト追加 / 手動検証のみ）
4. その他、依頼文から読み取れない前提（フェーズ 0 で未コミットの変更があれば、その扱い）

`{TPL}/hearing-notes.md` を埋めて `{dir}/hearing-notes.md` に書く。

### 1-3. requirements の作成と `□` の解消

`{TPL}/requirements.md` を埋めて `{dir}/requirements.md` に書く。

- ユースケース（`### UC-n`）は**ユーザーから見た達成状態**で書く（実装手段を書かない）。以降のテストケースとレビューはすべて UC を基準にする
- **調べても決まらず、ユーザーにしか決められない分岐**を「未解決の確認事項」に `□` で並べ、AskUserQuestion で解消して `■` にする（回答も併記する）
- **後から AI が困りそうな分岐はここで先に潰す。** 承認後に聞くのはエスカレーション条件に当たるときだけなので、「既定の挙動」「エラー時の見せ方」「既存の挙動を変えてよいか」「依存を足してよいか」など振る舞いに出る判断はここで決める

### 1-4. 承認ゲート

requirements の要約（UC 一覧・主要な制約・スコープ外）を提示し、AskUserQuestion で次を**1 回で**聞く。

```yaml
- question: "この要件で確定し、計画→実装→検証まで自律で進めてよいですか？（以降は要件の矛盾・不可逆な操作・行き詰まりのときだけ確認します）"
  header: "要件の承認"
  options:
    - label: "承認して進める"
      description: "完了まで自律で進め、report.md で報告する"
    - label: "修正したい"
      description: "requirements を直してから、もう一度承認を取る"
- question: "完了時の git 操作はどうしますか？"
  header: "git"
  options:
    - label: "何もしない（推奨）"
      description: "変更は作業ツリーに残す。コミットはユーザーが行う"
    - label: "タスクごとにコミット"
      description: "実装グループが終わるたびにローカルへコミット（push はしない）"
    - label: "最後に PR まで作る"
      description: "ブランチを切ってコミット・push・PR 作成まで行う"
- question: "関連 Issue への記録はどうしますか？"   # {ISSUE} があるときだけ
  header: "Issue"
  options:
    - label: "記録しない"
      description: "Issue には何も書かない"
    - label: "計画確定時と完了時にコメントする"
      description: "計画の要約と完了報告の要約を gh issue comment で投稿する"
```

- 「修正したい」→ 1-3 に戻る
- 承認されたら requirements の `**ステータス**:` を `■ 承認済み` に、「実行設定」に git / Issue の回答を書き、`echo planning > {dir}/STATE`
- **ここから先は止まらずに進める。** 承認時に「完了したら `{dir}/report.md` で報告する。途中経過は `{dir}/decisions.md` と `review-log.md` で追える。止まらずに進めるには、テスト・lint の実行を許可するパーミッションが要る」と添える

## フェーズ 2: 計画と計画レビュー（自律）

### 2-1. 計画

`spec-orchestrator-plugin:planner` を起動する。渡すもの:

```text
run フォルダ: {dir}
テンプレート: {TPL}
参照資料: {REF}（test-scenarios.md / tdd-guidelines.md / claim-verification.md）
（直しのときだけ）採用した指摘: <review-log の ID と本文> / 決めた判断: <decisions の ID と本文>
```

planner は `{dir}` の requirements / hearing-notes / exploration を読み、コードを調べて
`implementation-plan.md` / `tasks.md` / `test-cases.md`（テスト方針が「手動検証のみ」なら無し）を書いて、確かめた事実と未決の判断を返す。

- 未決の判断が返ってきたら「[自分で決める / ユーザーに聞く](#自分で決める--ユーザーに聞く)」で処理し、決めた内容を次の planner 呼び出しに渡す

### 2-2. 計画レビュー（並列）

1 つのメッセージで次を並列に起動する（読むだけのエージェント）。

| エージェント | 見るもの | 渡すもの |
|---|---|---|
| `plan-reviewer` | 要件との対応・設計の妥当性・既存資産の再利用・ファイルの数え漏れ・テストケースの十分さ | `{dir}` と共通の指示のパス |
| `plan-clarity-checker`（haiku） | 計画だけで実装内容が一意に伝わるか | `{dir}/implementation-plan.md` と `{dir}/requirements.md` の**パスだけ**（意図・補足を書かない。素で読ませるのが目的） |
| `test-coverage-checker` | UC 単位でテストケースが足りているか | `{dir}/requirements.md` / `{dir}/test-cases.md` / `{REF}/test-scenarios.md` のパスと機能タイプ（test-cases が無ければ起動しない） |
| プロジェクトの計画レビュアー | プロジェクト固有の観点 | 「サブエージェントの呼び方」の形で本文を渡す（あれば） |

### 2-3. 採否と直し

返ってきた指摘を `review-log.md` に「計画レビュー 第 n 回」として記録する（`{TPL}/review-log.md` の形。指摘ごとに 採用 / 不採用 と理由）。

- **採用したものがあれば**、採用した指摘だけを渡して planner を新しく起動し直させる → 2-2 へ。**最大 2 回**。2 回目でも残る指摘は「未対応」として `review-log.md` に残し、実装へ進む（要件に関わるものはエスカレーション）
- `plan-clarity-checker` の `PARTIAL` / `CONFUSED` は、本文を明瞭にする方向で直させる（注釈を足して合わせない）
- 指摘が**要件そのもの**を揺らしている（UC が実現できない・UC 同士が矛盾する・UC が足りない）ならエスカレーション条件 A
- 確定したら `echo implementing > {dir}/STATE`。実行設定で Issue 記録が有効なら、計画の要約（ADR・変更ファイル・タスク一覧。コードブロックは貼らない）を `{dir}/plan-comment.md` に書き、`gh issue comment {ISSUE} --body-file {dir}/plan-comment.md` で投稿する

## フェーズ 3: 実装（自律）

`tasks.md` の実装グループ（`## T1: ...` `## T2: ...`）のうち `□` を含むものを、**上から順に** `spec-orchestrator-plugin:implementer` へ**前面で単独で**渡す。渡すもの:

```text
run フォルダ: {dir}
担当グループ: T{n}
参照資料: {REF}（tdd-guidelines.md / claim-verification.md）
（直しのときだけ）直す指摘: <採用した指摘>
```

implementer は担当グループのタスクを実装し、終わったタスクを `□` → `■` にし、関係するテストを走らせて、変更したファイル・走らせた検査と終了コード・計画との差分を返す。

返ってきたら:

1. 返ってきた変更ファイルを計画の変更案と突き合わせる（run フォルダとフェーズ 0 で控えたユーザーの変更は除く）。計画に無いファイルが増えていたら、その理由が返り値にあるかを見る
2. **計画との差分（Deviation）が返ってきたら**、要件の範囲内で収まるなら自分で決めて `decisions.md` に書き、planner に計画を直させてから（2-2 は省いてよい。直した理由は decisions にある）implementer を起動し直す。要件の範囲を出るならエスカレーション条件 A
3. 検査が落ちたまま返ってきたら、同じグループの直しとして implementer を起動し直す（同じ失敗が 2 回続いたらエスカレーション条件 C）
4. 実行設定が「タスクごとにコミット」なら、ここでコミットする。add するのは**計画の変更案にあり、implementer が変更したと返したファイルだけ**（`git add -- <ファイル>`。`git add -A` / `.` は使わない。run フォルダとユーザーの変更を載せない）→ `git commit -m "{グループ名}"`

`tasks.md` の全グループが `■` になったら `echo verifying > {dir}/STATE`。

## フェーズ 4: 実装の検証（自律）

### 4-1. 検査

exploration.md に控えたプロジェクトの検査（テスト・lint・型検査・フォーマット）を走らせ、**終了コードで**判定する。`&&` で 1 本に連ねない（途中の出力が流れて末尾しか見えず、通ったと読み違える）。落ちたら implementer に直させる。

### 4-2. 観点別レビュー（2 段）

差分は次で出す（未追跡ファイルを含め、run フォルダを除く）。変更ファイルの一覧は各レビュアーにも本文で渡す（Bash を持たないレビュアーも差分を辿れるように）。

```bash
git diff --name-only $(cat {dir}/BASE) -- . ':!.plugin-workspace'
git ls-files --others --exclude-standard -- . ':!.plugin-workspace'
```

フェーズ 0 で控えたユーザーの変更があれば、その一覧も「レビューの対象外」として渡す。

**1 段目**: 下の表で呼ぶ条件に当たるもの（`test-reviewer` 以外）と、条件に当たるプロジェクトのレビュアーを 1 つのメッセージで並列に起動する。渡すのは `{dir}`・変更ファイルの一覧・共通の指示のパス。

| エージェント | 観点 | 呼ぶ条件 |
|---|---|---|
| `solution-reviewer` | 方式（根本原因を直しているか・より単純な代替・継ぎ当て） | 常に |
| `spec-alignment-reviewer` | 要件・計画・DoD との整合 | 常に |
| `code-quality-reviewer` | 重複・命名・コメントと実物・過剰な防御 | 常に（プロジェクトのレビュアーが観点をすべて持つなら省く） |
| `security-reviewer` | セキュリティ | 外部入力・認証/認可・ファイル/プロセス/ネットワーク・依存定義（lockfile 含む）・CI やフックの設定に差分が触れるとき |
| `performance-reviewer` | 性能・資源 | 実行されるコード（テスト・文書・設定以外）に差分があるとき |

**2 段目**: 1 段目の採用分を implementer に直させて検査を通したあと、`test-reviewer` を**前面で単独で**起動する（実装を壊してテストが落ちるかを実測する。実行されるコードに差分が無ければ省く）。

### 4-3. 採否と直し

- **`solution-reviewer` の結論を先に読む。** 「置き換え」なら下の「[方式の置き換え](#方式の置き換え)」へ
- エージェントをまたいで根本原因が同じ指摘は束ねて対応を決める（記録は元の指摘ごと）
- 採否を `review-log.md` に「実装レビュー 第 n 回」として書き、採用分を implementer に渡す → 4-1 の検査
- 直しのサイクルは**最大 2 回**。残った指摘は `report.md` の「未対応の指摘」に理由付きで残す（重大度「重大」「高」が残るならエスカレーション条件 C）

### 方式の置き換え

`solution-reviewer` が「置き換え」と結論し、それを採用した場合（置き換えが requirements の UC・制約を変えるならエスカレーション条件 A）。

1. 採否と置き換えの理由を `review-log.md` と `decisions.md` に書く
2. `echo planning > {dir}/STATE` にして planner を起動し、**今の作業ツリーから置き換え先へ移す計画**を書かせる。作業ツリーを git で巻き戻さない（ユーザーの変更や他の修正まで消える）。不要になったコードの削除・書き戻しも、計画の変更案と `tasks.md` の新しいグループ（`## T{n+1}` 以降）として書かせる。ADR には置き換え前の方式を「不採用」として理由付きで残させる
3. 2-2 の計画レビューを通す（置き換えの計画も検証せずに実装しない）
4. `echo implementing > {dir}/STATE` にしてフェーズ 3 の新しいグループから続ける
5. 置き換えは 1 回まで。2 回目になるならエスカレーション条件 C

## フェーズ 5: 完了

1. `implementation-plan.md` の Definition of Done を 1 項目ずつ確かめる（確かめ方は検査の終了コード・レビュー結果を根拠にする）
2. `{TPL}/report.md` を埋めて `{dir}/report.md` に書く（何ができるようになったか・変更ファイル・検査結果・DoD・自分で決めた判断の要約・未対応の指摘・フォローアップ）
3. 実行設定の git 操作を行う。add するのはフェーズ 3 と同じく計画にあり変更したファイルだけ
   - 「最後に PR まで作る」: 作業ブランチでなければ `git switch -c {feature-name}` → add → コミット → `git push -u origin HEAD` → PR 作成（本文は report.md の要約）
4. 実行設定で Issue 記録が有効なら、完了の要約を `gh issue comment` で投稿する（Issue は閉じない）
5. `echo done > {dir}/STATE`
6. ユーザーへは report.md のパスと要点（できるようになったこと・未対応・自分で決めた判断のうち確認してほしいもの）を短く報告する

---

## 自分で決める / ユーザーに聞く

承認後（フェーズ 2〜5）は、**次の条件に当たるときだけ**ユーザーに聞く。それ以外はすべて自分で決め、`decisions.md` に「何を・どの選択肢から・なぜ」を 1 件ずつ書く（`{TPL}/decisions.md` の形）。

| 条件 | 例 |
|---|---|
| **A. 要件が揺らぐ** | UC が実現できない・UC 同士が矛盾する・UC に無い振る舞いの選択がユーザーに見える形で必要になった・スコープ外にしたものに触らないと進めない |
| **B. 不可逆・外部に影響する** | 実行設定で許可されていない push / PR / Issue 投稿・外部サービスへの書き込み、データやファイルの削除・マイグレーション、requirements で許していない依存の追加やメジャー更新、requirements に無い公開 API・ファイル形式の破壊的変更 |
| **C. 行き詰まり** | 同じ検査・同じ指摘の修正が 2 回続けて失敗した、方式の置き換えが 2 回目になる、重大度「重大」「高」の指摘が直しきれない |
| **D. 権限が無い** | 必要な操作がパーミッションで拒否された・道具（テストランナー等）が無く検査できない |

聞くときは:

- AskUserQuestion で、**選択肢と推奨とその理由**を示す（何が分からないかだけを投げない）
- 聞く前に `decisions.md` に「エスカレーション」として状況と**その時点のフェーズ**を書く。回答も追記する
- 回答が要件を変えるなら requirements.md を更新し（追記した項目は `■` で回答付き）、影響するフェーズからやり直す
- AskUserQuestion が使えない環境で応答を終えて待つ場合は、`echo waiting:<今の STATE> > {dir}/STATE`（例: `waiting:implementing`）にしてから終える。再開時は `:` の後ろのフェーズへ戻す

**自分で決めてよいもの**（聞かない）: 要件の範囲内での実装方式の選択・ファイル配置・命名・テストの粒度・レビュー指摘の採否・計画の細部の修正・リファクタリングの範囲（要件に必要な分まで）。

## 再開

`--resume [番号]`（番号省略時は `STATE` が `done` でない最大番号）で途中から続ける。

1. `{dir}` を特定し、`echo "${CLAUDE_SESSION_ID}" > {dir}/SESSION` で現在のセッションに付け替える
2. `STATE` と run フォルダの md を読み、次から続ける
   - `requirements`: requirements の `□` / 承認状態を見てフェーズ 1 の途中から
   - `planning`: `implementation-plan.md` が無ければ 2-1、あれば 2-2 から
   - `implementing`: `tasks.md` の `## T{n}` のうち最初に `□` を含むグループから
   - `verifying`: 4-1 から
   - `waiting:<フェーズ>`: `decisions.md` の最後のエスカレーションを読み、回答を得てから `echo <フェーズ> > {dir}/STATE` にして続ける

## run フォルダ

```
.plugin-workspace/.orchestrate/{nnn}-{feature-name}/
├── STATE                  # requirements / planning / implementing / verifying / waiting:<フェーズ> / done
├── SESSION                # 実行中のセッション ID（フックが読む）
├── BASE                   # 差分の基準コミット
├── exploration.md         # 事前調査（関連ファイル・規約・検査コマンド・プロジェクトのレビュアー）
├── hearing-notes.md       # ヒアリング結果（開始時の未コミットの変更を含む）
├── requirements.md        # ユーザーと確定した要件（唯一の人間の確認が入った文書）
├── implementation-plan.md # 計画（ADR・却下案・変更案・影響範囲・検証計画・DoD）
├── tasks.md               # 実装グループ（## T{n}）とタスク（□ / ■）
├── test-cases.md          # テストケースと UC へのトレース
├── decisions.md           # 承認後に AI が自分で決めた判断とエスカレーション
├── review-log.md          # 計画・実装レビューの指摘と採否
├── report.md              # 完了報告
└── plan-comment.md        # Issue への計画サマリ（Issue 記録が有効なときのみ）
```
