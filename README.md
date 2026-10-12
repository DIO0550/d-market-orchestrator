# d-market-orchestrator

AI CLIエージェントを専門チームとして編成し、ソフトウェア開発タスクを自動で分散・並列実行するオーケストレーションプラグイン集。

## 概要

1つのタスク指示から、探索・計画・実装・レビュー・テスト・Git操作までを複数の専門エージェントが自律的に遂行します。複数の実行モデルを提供しており、用途に応じて選択できます。

| プラグイン | 実行モデル | 対応CLI |
|-----------|-----------|---------|
| [orchestrator-plugin](#orchestrator-plugin) | Claude Code サブエージェント（Task ツール） | Claude Code |
| [tmux-orchestrator-plugin](#tmux-orchestrator-plugin) | tmux セッション + ファイルベース IPC | Claude Code / GitHub Copilot / OpenAI Codex / 汎用CLI |
| [harness-loop-plugin](#harness-loop-plugin) | Claude Code サブエージェント + 目標を満たすまでのループ（目標だけユーザーと確定） | Claude Code |

## インストール

```bash
# リポジトリをクローン
git clone https://github.com/DIO0550/d-market.git

# プラグインディレクトリを Claude Code のプラグインパスに配置
# （具体的な配置方法はご利用環境に合わせてください）
```

---

## orchestrator-plugin

**Claude Code のサブエージェント機構（Task ツール）を使い、単一プロセス内でエージェントを並列起動するプラグイン。**

環境構築不要で即座に使えるシンプルな構成が特徴です。

### コマンド

#### `/orchestrate "タスクの説明"`

タスクを受け取り、専門サブエージェントをバックグラウンドで並列起動して遂行します。

- **Phase 1-2**（自動実行）: 探索 → 計画 → 計画レビュー → タスク実装ループ
- **Phase 3-4**（ユーザー指示）: テスト・Lint → コミット・PR作成

### Skills

| Skill | 目的 |
|-------|------|
| **orchestration** | メインのオーケストレーションワークフローを実行。`/orchestrate` コマンドで起動し、Phase 1-4 の全フローを制御する |
| **create-orchestrator-agent** | エージェント定義ファイルを生成。Claude Code / GitHub Copilot / OpenAI Codex の各フォーマットに対応し、13種のテンプレートから選択して作成 |
| **create-orchestrator-agent-file-based** | 上記のファイルベース出力版。エージェント間の結果受け渡しに `.orchestrator/` ディレクトリへの明示的なファイル出力を使用 |

### エージェント一覧

#### 制御系

| エージェント | 役割 | 推奨モデル |
|-------------|------|-----------|
| **task-manager** | 単一タスクのライフサイクル管理。実装→レビュー→完了の流れを制御 | Opus |

#### 計画系

| エージェント | 役割 | 推奨モデル |
|-------------|------|-----------|
| **explorer** | コードベースの関連ファイル・パターン・依存関係を探索 | Sonnet |
| **planner** | 探索結果をもとに実装計画を作成し、タスクに分解 | Opus |
| **plan-reviewer** | 計画の妥当性・実現可能性を検証。不備があれば差し戻し | Opus |

#### 実装系

| エージェント | 役割 | 推奨モデル |
|-------------|------|-----------|
| **implementer** | タスク仕様に基づいてコードを実装 | Sonnet |
| **code-reviewer** | 実装の品質・正確性をレビュー。4つのスペシャリストを並列起動 | Opus |
| **refactorer** | レビュー承認後、改善提案に基づいてコードを最適化 | Sonnet |

#### 品質保証系

| エージェント | 役割 | 推奨モデル |
|-------------|------|-----------|
| **test-runner** | プロジェクトのテストを実行（npm test / cargo test / pytest 等） | Haiku |
| **linter** | コードスタイルチェックを実行（npm run lint / cargo clippy 等） | Haiku |
| **security-scanner** | セキュリティ脆弱性を分析 | Sonnet |

#### デバッグ・Git系

| エージェント | 役割 | 推奨モデル |
|-------------|------|-----------|
| **debugger** | テスト失敗やエラーの原因調査・デバッグ支援 | Opus |
| **committer** | 変更をGitコミット | Haiku |
| **pr-creator** | プルリクエストを作成 | Haiku |

---

## tmux-orchestrator-plugin

**tmux セッションで複数のAI CLIプロセスを物理的に並列起動し、ファイルベース IPC で連携するプラグイン。**

複数のAI CLIツール（Claude Code、GitHub Copilot、OpenAI Codex）を混在利用でき、各エージェントが独立プロセスとして動作するのが特徴です。

### コマンド

#### `/tmux-orchestrate "タスクの説明"`

tmuxセッション内で複数のAI CLIエージェントを並列起動してタスクを遂行します。

- **Phase 0**（自動）: セッション初期化・CLI割り当て
- **Phase 1-2**（自動）: 探索 → 計画 → スペシャリストレビュー → タスク実装ループ
- **Phase 3-4**（ユーザー指示）: テスト・Lint → コミット・PR作成

### Skills

| Skill | 目的 |
|-------|------|
| **tmux-orchestration** | tmux上でのメインオーケストレーションワークフローを実行。`/tmux-orchestrate` コマンドで起動し、ファイルベース IPC でエージェント間を連携 |
| **tmux-session-management** | tmuxセッションのライフサイクル管理。セッションの作成・監視・破棄・結果収集を担当 |
| **create-tmux-agent** | tmux用の指示ファイルを生成。Claude Code / Copilot / Codex / 汎用CLI の各フォーマットに対応し、22種のテンプレートから選択して作成 |

### 指示ファイル一覧

orchestrator-plugin のエージェントに加え、以下のスペシャリストレビュアーが追加されています。

#### 計画レビュースペシャリスト（並列実行）

| 指示ファイル | 役割 |
|-------------|------|
| **plan-quality-reviewer** | 計画の設計品質・可読性・保守性を評価 |
| **plan-bug-reviewer** | 計画に潜むリスクやバグの可能性を特定 |
| **plan-performance-reviewer** | 計画のパフォーマンスへの影響を分析 |
| **plan-security-reviewer** | 計画のセキュリティ観点でのレビュー |

#### コードレビュースペシャリスト（並列実行）

| 指示ファイル | 役割 |
|-------------|------|
| **quality-reviewer** | コード品質・可読性・保守性を評価 |
| **bug-reviewer** | 潜在的なバグやエッジケースを検出 |
| **performance-reviewer** | パフォーマンス上の問題を発見 |
| **security-reviewer** | セキュリティ脆弱性を特定 |

### ファイルベース IPC

tmux版ではエージェント間の通信にファイルシステムを使用します。

```
.orchestrator/
├── team-config.json              # チーム名カスタマイズ（任意）
└── {SESSION_ID}/                 # セッションディレクトリ（例: 0001-feature-name）
    ├── .config/
    │   └── cli-assignments.json  # エージェント→CLI の割り当て
    ├── .status/
    │   ├── {agent}.done          # 完了マーカー（状態値: Approved/Completed/Rejected 等）
    │   └── {agent}.exit          # 終了コード
    ├── .prompts/
    │   └── {agent}-prompt.md     # エージェントへの入力プロンプト
    ├── .deps/
    │   └── tasks.json            # タスク依存関係グラフ
    ├── explorer/result.md
    ├── planner/plan.md
    ├── plan-reviewer/review-{round}.md
    └── task-{id}/
        ├── implementer/result-{round}.md
        ├── code-reviewer/review-{round}.md
        └── ...
```

---

## harness-loop-plugin

**計画 → 目標確定 → 目標を満たすまでループ → PR を回すハーネス。ユーザーが関わるのは目標（完了条件）の確定だけ。**

design-composer の implementation-flow（planner / implementer / 観点別 reviewer への分担、計画の検証、却下案の記録、ミューテーションによるテストの検証）と、d-market-spec の spec-plugin（`□`/`■` のゲート、implementation-plan.md / tasks.md の書式）を、ループ型のハーネスとしてまとめたもの。計画の出力は d-market-spec と同じ形（概要・背景・ADR・システム図・`[NEW]`/`[MODIFY]` とコード骨格・検証計画）。プロジェクト固有の規約は持たず、実行時にプロジェクトの `CLAUDE.md` / `AGENTS.md` / 規約ファイルを読んで従う。

### コマンド

#### `/harness-loop "タスクの説明"` / `/harness-loop #123` / `/harness-loop --resume [番号]`

```
[1. 計画] ──→ [2. 目標確定] ──→ [3. ループ] ─────────────────────→ [4. PR]
 AI が調査し     ユーザーが         implementer → コミット → 検証        完了条件が
 impl-plan と   goal.md を         （検査・goal-checker・レビュー）       すべて ■
 goal.md の案   確定（ここだけ）     → 未達・採用した指摘を次の回へ
                                     ↑___________________|
```

| # | フェーズ | ユーザーの関与 | 出力 |
|---|---|---|---|
| 1 | 計画 | なし | `exploration.md`・`implementation-plan.md`・`tasks.md`・`goal.md`（案） |
| 2 | 目標確定 | **`□` の解消・完了条件の確定・PR のベースとループの上限（ここだけ）** | `goal.md`（確定） |
| 3 | ループ | なし | 1 回ごとのコミット・`loop-log.md`・完了条件の `■` |
| 4 | PR | 結果の確認 | PR |

- **ループの終了条件は `goal.md` の完了条件。** 完了条件は 1 つずつ確かめ方（コマンドか、判定の基準を書いたレビュー）を持ち、独立した `goal-checker` が毎回その確かめ方どおりに判定する。すべて満たした回だけ `test-reviewer`（実装を壊してテストが落ちるかを実測）を走らせ、採用した重大/高の指摘が無ければ PR へ進む
- 確定後にユーザーへ聞くのは、**目標が揺らぐ / 不可逆・外部に影響する / 行き詰まり（上限・2 回続けて前進なし） / 権限が無い** のどれかに当たるときだけ。それ以外は AI が決めて `decisions.md` に残す

### ユーザーが読めるファイル

```
.plugin-workspace/.harness/{nnn}-{name}/
├── exploration.md # 下調べ（explorer）
├── implementation-plan.md # 計画（d-market-spec の書式: 概要・背景・ADR・システム図・変更案とコード骨格・影響範囲・検証計画）
├── tasks.md       # 実装タスクの □ / ■（2 回目以降は「## Loop {n}: 修正」が足される）
├── goal.md        # 目標（ゴール・確かめ方付きの完了条件 □/■・スコープ外・実行設定）
├── loop-log.md    # 計画レビューと、1 回ごとの検査・完了条件の判定・指摘と採否・判定
└── decisions.md   # 確定後に AI が自分で決めた判断・エスカレーション
```

run フォルダは `.git/info/exclude` で git の差分とコミットから外す。

### エージェント一覧

トークンを抑えるため、エージェントごとに model / effort / maxTurns を frontmatter で決めている（読むだけのものは `omitClaudeMd: true` で CLAUDE.md の自動読み込みも省く）。変えたいときは各 `agents/*.md` の frontmatter を直す。

| エージェント | 役割 | model | effort |
|---|---|---|---|
| **explorer** | 関連ファイル・類似実装・規約ファイルの場所・検査コマンドを探して exploration.md に書く | haiku | low |
| **planner** | exploration.md から implementation-plan.md・tasks.md と goal.md の案（確かめ方付きの完了条件）を書く | opus | high |
| **plan-reviewer** | 完了条件が確かめられる形か・依頼との対応・既存資産・影響範囲・テストを検証 | opus | medium |
| **implementer** | 1 回分の「やること」（計画の手順 / 未達の条件 / 採用した指摘）を実装して検査を走らせる | opus | medium |
| **goal-checker** | 完了条件を確かめ方どおりに実行し、満たす / 満たさないを根拠付きで判定 | haiku | medium |
| **solution-reviewer** | 方式を 維持 / 調整 / 置き換え で結論（1 回目と方式を変えた回だけ） | opus | medium |
| **code-quality-reviewer** | 重複・命名・コメントと実物・過剰な防御 | opus | low |
| **security-reviewer** | 外から来る値・権限・依存・CI（条件に当たる回だけ） | opus | low |
| **performance-reviewer** | 頻度の高い経路・データ量に比例する処理（条件に当たる回だけ） | haiku | low |
| **test-reviewer** | 実装を壊してテストが落ちるかを実測（全条件を満たした回に単独で） | opus | medium |

ほかに、指示役（スキル）は `effort: medium` で動き、ソースを読まずパスと結論だけを持つ。2 回目以降のレビューはまだレビューしていない差分だけを見せ、検査が落ちた回はレビュアーを起動しない。各エージェントの返り値には行数の上限がある。

プロジェクトの `.claude/agents/` にある `*-reviewer` は、プラグインのレビュアーに加えて並列で起動する（入出力の約束が違うので置き換えず、目標・計画・差分を本文で渡す）。

### フック

| フック | タイミング | 内容 |
|---|---|---|
| `guard-phase-writes.sh` | PreToolUse | 目標の確定前（`planning` / `goal` とその回答待ち）は、run フォルダと一時ディレクトリの外への書き込みをブロック。Bash は字句解析でリダイレクト先・書き換え系コマンドの対象を見る最善努力のガード（`python -c` の中の書き込みまでは追わない） |
| `check-plan-format.sh` | PostToolUse | implementation-plan.md / tasks.md を d-market-spec の書式で検査（必須セクション・システム図・変更案のコード骨格と理由・実装の省略・プレースホルダ） |
| `check-goal.sh` | PostToolUse | goal.md の完了条件に確かめ方が無い・確定なのに `□` の確認事項やプレースホルダが残る、を止める |
| `guard-pr.sh` | PreToolUse | ループを抜けていない（STATE が `pr` でない）・完了条件に `□` が残る間は、`gh pr create` と MCP の PR 作成をブロック |
| `continue-until-done.sh` | Stop | 確定後（`looping` / `pr`）に止まろうとしたら 1 度だけ続行を促す |

フックは `jq`（全体）と `python3`（Bash の判定）を使う。無い場合は警告を出して素通りする。

判定表: `bash plugins/harness-loop-plugin/hooks/tests/hook-cases.sh`

---

## ワークフロー全体像

```
ユーザー入力
    │
    ▼
[Phase 0: 初期化]  ← tmux版のみ
    │  セッション作成、CLI割り当て
    │
    ▼
[Phase 1: 探索・計画]
    │
    ├── Explorer ─────── コードベース探索
    ├── Planner ──────── 実装計画作成・タスク分解（Explorer完了後）
    └── Plan Reviewer ── 計画の検証（Planner完了後）
         │
         ├─ Needs Revision → Planner 再起動（最大2回）
         └─ Approved → Phase 2 へ
    │
    ▼
[Phase 2: 実装ループ]
    │
    ├── 依存関係が解消されたタスクを並列起動
    │   └── Task Manager（タスクごと）
    │       ├── Implementer（コード実装）
    │       ├── Code Reviewer + スペシャリスト（レビュー）
    │       └── Refactorer（改善提案の反映）
    │
    ├── 完了したタスクの依存先を解放
    └── 全タスク完了まで繰り返し
    │
    ▼
[Phase 3: テスト・Lint]  ← ユーザー指示で実行
    │
    ├── Test Runner（並列）
    └── Linter（並列）
    │
    ▼
[Phase 4: Git操作]  ← ユーザー指示で実行
    │
    ├── Committer
    └── PR Creator
```

## プロジェクト種別の自動検出

以下のファイルをもとに、テスト・Lintコマンドを自動判定します。

| 検出ファイル | テストコマンド | Lintコマンド |
|-------------|--------------|-------------|
| `package.json` | `npm test` | `npm run lint` |
| `Cargo.toml` | `cargo test` | `cargo clippy` |
| `pyproject.toml` | `pytest` | `ruff check .` |
| `go.mod` | `go test ./...` | `golangci-lint run` |

## チーム名カスタマイズ（tmux版）

`team-config.json` を配置することで、セッション名やペインタイトルにカスタム名を使用できます。

```json
{
  "teamName": "my-team",
  "members": {
    "explorer": "Scout",
    "planner": "Architect",
    "implementer": "Builder"
  }
}
```

## ライセンス

MIT
