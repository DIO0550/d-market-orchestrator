# エージェントカタログ

tmux-orchestrator で使用可能な14種類のエージェント一覧。

## エージェント一覧

### 制御

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Orchestrator](agents/orchestrator.md) | 必須 | 🧠 opus | 全体フロー制御。tmuxセッションの管理、エージェント起動・監視 |

### 計画フェーズ（Phase 1）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Explorer](agents/explorer.md) | 推奨 | ⚡ sonnet | コードベースの探索・関連ファイルの特定 |
| [Planner](agents/planner.md) | 必須 | 🧠 opus | 実装計画の策定・タスク分割・依存関係設計 |
| [Plan Reviewer](agents/plan-reviewer.md) | 推奨 | 🧠 opus | 計画の妥当性検証・仕様書との整合性チェック |

### 実装フェーズ（Phase 2）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Task Manager](agents/task-manager.md) | 推奨 | ⚡ sonnet | タスクライフサイクル管理（実装→レビュー→判定） |
| [Implementer](agents/implementer.md) | 必須 | ⚡ sonnet | コードの実装・変更の適用 |
| [Code Reviewer](agents/code-reviewer.md) | 推奨 | 🧠 opus | コード品質レビュー・バグ検出 |

### 検証フェーズ（Phase 2/3）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Test Runner](agents/test-runner.md) | 推奨 | 💨 haiku | テストの実行・結果報告 |
| [Linter](agents/linter.md) | 推奨 | 💨 haiku | コードスタイル・品質チェック |
| [Security Scanner](agents/security-scanner.md) | 任意 | ⚡ sonnet | セキュリティ脆弱性スキャン |

### 修正フェーズ

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Debugger](agents/debugger.md) | 任意 | 🧠 opus | テスト失敗の原因分析・修正 |
| [Refactorer](agents/refactorer.md) | 任意 | ⚡ sonnet | レビュー指摘に基づくコード改善 |

### Gitフェーズ（Phase 4）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Committer](agents/committer.md) | 任意 | 💨 haiku | Gitコミットの作成 |
| [PR Creator](agents/pr-creator.md) | 任意 | 💨 haiku | Pull Requestの作成 |

## モデル選択ガイド

| クラス | 記号 | 用途 | コスト | エージェント |
|--------|-----|------|--------|-------------|
| 🧠 高性能 | opus | 複雑な判断・設計・レビュー | 高 | Orchestrator, Planner, Plan Reviewer, Code Reviewer, Debugger |
| ⚡ 中程度 | sonnet | 分析・コード生成・探索 | 中 | Explorer, Implementer, Task Manager, Refactorer, Security Scanner |
| 💨 軽量 | haiku | 定型作業・コマンド実行 | 低 | Test Runner, Linter, Committer, PR Creator |

## プリセット構成

### Minimal（最小）

最小限のエージェント構成。小規模な変更向け。

| エージェント | モデル |
|-------------|--------|
| Orchestrator | opus |
| Planner | opus |
| Implementer | sonnet |

### Standard（標準）

一般的な開発ワークフロー。

| エージェント | モデル |
|-------------|--------|
| Orchestrator | opus |
| Explorer | sonnet |
| Planner | opus |
| Implementer | sonnet |
| Test Runner | haiku |
| Linter | haiku |
| Committer | haiku |

### Full（フル）

全機能。品質重視の大規模開発向け。

| エージェント | モデル |
|-------------|--------|
| 全14エージェント | 各推奨モデル |

### Review-Heavy（レビュー重視）

コードレビューとセキュリティを強化。

| エージェント | モデル |
|-------------|--------|
| Orchestrator | opus |
| Explorer | sonnet |
| Planner | opus |
| Plan Reviewer | opus |
| Implementer | sonnet |
| Code Reviewer | opus |
| Security Scanner | sonnet |
| Committer | haiku |

### Debug-Focused（デバッグ重視）

テストとデバッグを強化。

| エージェント | モデル |
|-------------|--------|
| Orchestrator | opus |
| Explorer | sonnet |
| Planner | opus |
| Implementer | sonnet |
| Test Runner | haiku |
| Linter | haiku |
| Debugger | opus |
| Refactorer | sonnet |

## 依存関係グラフ

```
Explorer ──→ Planner ──→ Plan Reviewer
                │
                ▼
          Task Manager ──→ Implementer ──→ Code Reviewer
                │              │                │
                │              ▼                ▼
                │         Test Runner      Refactorer
                │         Linter
                │              │
                │              ▼
                │         Debugger（失敗時）
                │
                ▼
          Committer ──→ PR Creator
```

## 出力ディレクトリ構造

各エージェントは以下のパスに結果を書き出す:

```
.orchestrator/{SESSION_ID}/
├── explorer/result.md                          ← Explorer
├── planner/plan.md                             ← Planner
├── planner/tasks.md                            ← Planner
├── plan-reviewer/review-{round}.md             ← Plan Reviewer
├── task-{id}/implementer/result-{round}.md     ← Implementer
├── task-{id}/code-reviewer/review-{round}.md   ← Code Reviewer
├── task-{id}/test-runner/result-{round}.md     ← Test Runner（Phase 2）
├── task-{id}/linter/result-{round}.md          ← Linter（Phase 2）
├── task-{id}/refactorer/result-{round}.md      ← Refactorer
├── task-{id}/debugger/report-{round}.md        ← Debugger（Phase 2）
├── task-{id}/task-manager/lifecycle.md          ← Task Manager
├── test-runner/result-{round}.md               ← Test Runner（Phase 3）
├── linter/result-{round}.md                    ← Linter（Phase 3）
├── debugger/report-{round}.md                  ← Debugger（Phase 3）
├── security-scanner/result.md                  ← Security Scanner
├── committer/result.md                         ← Committer
└── pr-creator/result.md                        ← PR Creator
```

## CLI 互換性

各エージェントは以下のCLIツールで実行可能:

| エージェント | Claude Code | Codex | Copilot | 備考 |
|-------------|:-----------:|:-----:|:-------:|------|
| Orchestrator | ✅ | ⚠️ | ❌ | tmux管理にBashツールが必要 |
| Explorer | ✅ | ✅ | ⚠️ | ファイル検索能力が必要 |
| Planner | ✅ | ✅ | ⚠️ | 複雑な分析能力が必要 |
| Plan Reviewer | ✅ | ✅ | ⚠️ | 判断能力が必要 |
| Task Manager | ✅ | ⚠️ | ❌ | ペインでのエージェント管理が必要 |
| Implementer | ✅ | ✅ | ⚠️ | ファイル編集能力が必要 |
| Code Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Test Runner | ✅ | ✅ | ⚠️ | コマンド実行能力が必要 |
| Linter | ✅ | ✅ | ⚠️ | コマンド実行能力が必要 |
| Security Scanner | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Debugger | ✅ | ✅ | ❌ | 複雑な分析+編集が必要 |
| Refactorer | ✅ | ✅ | ⚠️ | ファイル編集能力が必要 |
| Committer | ✅ | ✅ | ⚠️ | Git操作能力が必要 |
| PR Creator | ✅ | ✅ | ⚠️ | gh CLI操作が必要 |

✅ = 完全対応 / ⚠️ = 制限付き対応 / ❌ = 非対応
