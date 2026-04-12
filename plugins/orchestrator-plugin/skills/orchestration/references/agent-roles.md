# エージェント役割定義

各エージェントの役割と対応テンプレートを定義する。
詳細な指示・判定基準・出力形式は各テンプレート（`.orchestrator/templates/`）を参照。

## エージェント一覧

| エージェント | 役割 | テンプレート | 起動タイミング |
|-------------|------|-------------|---------------|
| **explorer** | ファイル探索・コード調査 | `exploration-result.md` | 最初に起動 |
| **planner** | タスク分析・実装計画作成 | `implementation-plan.md` + `tasks.md` | explorer完了後 |
| **plan-reviewer** | 計画の妥当性検証 | `plan-review-result.md` | planner完了後 |
| **task-manager** | タスクライフサイクル管理 | `task-lifecycle-result.md` | タスクごとに起動 |
| **implementer** | コード実装（1タスク=1エージェント） | `implementation-result.md` | task-managerから起動 |
| **quality-reviewer** | コード品質レビュー | `quality-review-result.md` | task-managerから並列起動 |
| **logic-reviewer** | ロジックレビュー | `logic-review-result.md` | task-managerから並列起動 |
| **performance-reviewer** | パフォーマンスレビュー | `performance-review-result.md` | task-managerから並列起動 |
| **refactorer** | コード品質改善 | `refactoring-result.md` | レビュー後（推奨対応時） |
| **test-runner** | テスト実行・結果報告 | `test-result.md` | 実装後 |
| **linter** | Lint実行・結果報告 | `lint-result.md` | 実装後（テストと並列可） |
| **debugger** | テスト/Lint失敗の原因分析 | `debug-result.md` | テスト/Lint失敗時 |
| **security-scanner** | セキュリティ脆弱性検出 | `security-scan-result.md` | 実装後 |
| **committer** | コミット作成 | `commit-result.md` | テスト・Lint成功後 |
| **pr-creator** | PR作成 | （SKILL.md Phase 4 参照） | コミット後 |

## サブエージェント起動パターン

全エージェントは以下の共通パターンで起動する：

```
Task tool:
  description: "{agent-name}: {タスク件名}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたは{agent-name}です。

    ## コンテキスト
    {タスク情報・前のエージェントの出力}

    ## 指示
    `.orchestrator/templates/{template}.md` を読み、その指示に従ってください。
    結果を標準出力で返してください。
```
