# エージェントカタログ

tmux-orchestrator で使用可能な22種類のエージェント一覧。

## エージェント一覧

### 制御

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Orchestrator](instructions/orchestrator.md) | 必須 | 🧠 opus | 全体フロー制御。tmuxセッションの管理、エージェント起動・監視 |

### 計画フェーズ（Phase 1）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Explorer](instructions/planning/explorer.md) | 推奨 | ⚡ sonnet | コードベースの探索・関連ファイルの特定 |
| [Planner](instructions/planning/planner.md) | 必須 | 🧠 opus | 実装計画の策定・タスク分割・依存関係設計 |
| [Plan Reviewer](instructions/planning/plan-reviewer.md) | 推奨 | 🧠 opus | リードプランレビュー・スペシャリスト統合・最終判定 |
| [Plan Quality Reviewer](instructions/review/plan-quality-reviewer.md) | 任意 | ⚡ sonnet | 計画品質レビュー（構造・明確さ・タスク粒度・一貫性） |
| [Plan Bug Reviewer](instructions/review/plan-bug-reviewer.md) | 任意 | ⚡ sonnet | 実装リスク検出（エッジケース・エラーシナリオ・前提条件） |
| [Plan Performance Reviewer](instructions/review/plan-performance-reviewer.md) | 任意 | ⚡ sonnet | パフォーマンス影響レビュー（スケーラビリティ・効率性） |
| [Plan Security Reviewer](instructions/review/plan-security-reviewer.md) | 任意 | ⚡ sonnet | セキュリティ影響レビュー（認証・データ処理・脆弱性） |

### 実装フェーズ（Phase 2）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Task Manager](instructions/implementation/task-manager.md) | 推奨 | ⚡ sonnet | タスクライフサイクル管理（実装→レビュー→判定） |
| [Implementer](instructions/implementation/implementer.md) | 必須 | ⚡ sonnet | コードの実装・変更の適用 |
| [Code Reviewer](instructions/review/code-reviewer.md) | 推奨 | 🧠 opus | リードレビュー・スペシャリスト統合・最終判定 |
| [Quality Reviewer](instructions/review/quality-reviewer.md) | 任意 | ⚡ sonnet | コード品質レビュー（可読性・保守性・DRY・一貫性） |
| [Bug Reviewer](instructions/review/bug-reviewer.md) | 任意 | ⚡ sonnet | バグリスク検出（エッジケース・null/undefined・エラーハンドリング） |
| [Performance Reviewer](instructions/review/performance-reviewer.md) | 任意 | ⚡ sonnet | パフォーマンスレビュー（アルゴリズム効率・N+1クエリ・メモリリーク） |
| [Security Reviewer](instructions/review/security-reviewer.md) | 任意 | ⚡ sonnet | セキュリティレビュー（入力検証・機密情報・インジェクション脆弱性） |

### 検証フェーズ（Phase 2/3）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Test Runner](instructions/review/test-runner.md) | 推奨 | 💨 haiku | テストの実行・結果報告 |
| [Linter](instructions/review/linter.md) | 推奨 | 💨 haiku | コードスタイル・品質チェック |
| [Security Scanner](instructions/review/security-scanner.md) | 任意 | ⚡ sonnet | セキュリティ脆弱性スキャン |

### 修正フェーズ

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Debugger](instructions/implementation/debugger.md) | 任意 | 🧠 opus | テスト失敗の原因分析・修正 |
| [Refactorer](instructions/implementation/refactorer.md) | 任意 | ⚡ sonnet | レビュー指摘に基づくコード改善 |

### Gitフェーズ（Phase 4）

| エージェント | 必須 | モデル | 説明 |
|-------------|------|--------|------|
| [Committer](instructions/git/committer.md) | 任意 | 💨 haiku | Gitコミットの作成 |
| [PR Creator](instructions/git/pr-creator.md) | 任意 | 💨 haiku | Pull Requestの作成 |

## モデル選択ガイド

| クラス | 記号 | 用途 | コスト | エージェント |
|--------|-----|------|--------|-------------|
| 🧠 高性能 | opus | 複雑な判断・設計・レビュー | 高 | Orchestrator, Planner, Plan Reviewer, Code Reviewer, Debugger |
| ⚡ 中程度 | sonnet | 分析・コード生成・探索 | 中 | Explorer, Implementer, Task Manager, Refactorer, Security Scanner, Quality Reviewer, Bug Reviewer, Performance Reviewer, Security Reviewer, Plan Quality Reviewer, Plan Bug Reviewer, Plan Performance Reviewer, Plan Security Reviewer |
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
| 全22エージェント | 各推奨モデル |

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
Explorer ──→ Planner ──→ Plan Reviewer (Lead)
                │              │
                │              ├── Plan Quality Reviewer
                │              ├── Plan Bug Reviewer
                │              ├── Plan Performance Reviewer
                │              ├── Plan Security Reviewer
                │              ▼
                ▼
          Task Manager ──→ Implementer ──→ Code Reviewer (Lead)
                │              │                │
                │              ▼                ├── Quality Reviewer
                │         Test Runner           ├── Bug Reviewer
                │         Linter                ├── Performance Reviewer
                │              │                ├── Security Reviewer
                │              │                ▼
                │              │           Refactorer
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
├── plan-reviewer/review-{round}.md             ← Plan Reviewer (Lead)
├── plan-reviewer/quality-review-{round}.md     ← Plan Quality Reviewer
├── plan-reviewer/bug-review-{round}.md         ← Plan Bug Reviewer
├── plan-reviewer/performance-review-{round}.md ← Plan Performance Reviewer
├── plan-reviewer/security-review-{round}.md    ← Plan Security Reviewer
├── task-{id}/implementer/result-{round}.md     ← Implementer
├── task-{id}/code-reviewer/review-{round}.md              ← Code Reviewer (Lead)
├── task-{id}/code-reviewer/quality-review-{round}.md      ← Quality Reviewer
├── task-{id}/code-reviewer/bug-review-{round}.md          ← Bug Reviewer
├── task-{id}/code-reviewer/performance-review-{round}.md  ← Performance Reviewer
├── task-{id}/code-reviewer/security-review-{round}.md     ← Security Reviewer
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
| Plan Reviewer | ✅ | ⚠️ | ❌ | tmux管理にBashツールが必要 |
| Plan Quality Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Plan Bug Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Plan Performance Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Plan Security Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Task Manager | ✅ | ⚠️ | ❌ | ペインでのエージェント管理が必要 |
| Implementer | ✅ | ✅ | ⚠️ | ファイル編集能力が必要 |
| Code Reviewer | ✅ | ⚠️ | ❌ | tmux管理にBashツールが必要 |
| Quality Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Bug Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Performance Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Security Reviewer | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Test Runner | ✅ | ✅ | ⚠️ | コマンド実行能力が必要 |
| Linter | ✅ | ✅ | ⚠️ | コマンド実行能力が必要 |
| Security Scanner | ✅ | ✅ | ⚠️ | コード分析能力が必要 |
| Debugger | ✅ | ✅ | ❌ | 複雑な分析+編集が必要 |
| Refactorer | ✅ | ✅ | ⚠️ | ファイル編集能力が必要 |
| Committer | ✅ | ✅ | ⚠️ | Git操作能力が必要 |
| PR Creator | ✅ | ✅ | ⚠️ | gh CLI操作が必要 |

✅ = 完全対応 / ⚠️ = 制限付き対応 / ❌ = 非対応
