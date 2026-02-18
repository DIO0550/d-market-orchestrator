# d-market-orchestrator

AI CLIエージェントを専門チームとして編成し、ソフトウェア開発タスクを自動で分散・並列実行するオーケストレーションプラグイン集。

## 概要

1つのタスク指示から、探索・計画・実装・レビュー・テスト・Git操作までを複数の専門エージェントが自律的に遂行します。2つの実行モデルを提供しており、用途に応じて選択できます。

| プラグイン | 実行モデル | 対応CLI |
|-----------|-----------|---------|
| [orchestrator-plugin](#orchestrator-plugin) | Claude Code サブエージェント（Task ツール） | Claude Code |
| [tmux-orchestrator-plugin](#tmux-orchestrator-plugin) | tmux セッション + ファイルベース IPC | Claude Code / GitHub Copilot / OpenAI Codex / 汎用CLI |

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
