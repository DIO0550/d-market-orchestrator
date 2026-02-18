# 完了マーカー仕様

tmux-orchestrator のエージェント間同期メカニズム。

## 概要

各エージェントの完了は `.status/` ディレクトリ内のマーカーファイルで管理される。
`tmux-agent-launch.sh` がCLIプロセスの終了を検知し、自動的にマーカーファイルを作成する。

## ファイル構成

```
{SESSION_DIR}/.status/
├── {agent-name}.done       # 完了マーカー（状態値を含む）
└── {agent-name}.exit       # 終了コードファイル
```

## .done ファイル

- **ファイルの存在** = エージェントが完了したことを示す
- **ファイルの中身** = 状態値（1行のみ）
- 判定を出すエージェントは、プロセス終了前に自分で `.done` ファイルに状態値を書き出す
- 判定を出さないエージェントの場合、`tmux-agent-launch.sh` がCLIプロセス終了後に `done` をデフォルト書き込みする
- `wait-for-completion.sh` がこのファイルの存在をポーリングする

### 状態値の一覧

| エージェント | ファイル名 | 状態値 |
|-------------|-----------|--------|
| Explorer, Planner, Implementer 等 | `{agent}.done` | `done`（デフォルト） |
| Plan Reviewer | `plan-reviewer.done` | `Approved` / `Needs Revision` / `Rejected` |
| Task Manager | `task-{id}-task-manager.done` | `completed` / `rejected` |
| Code Reviewer | `task-{id}-code-reviewer.done` | `Approved` / `Approved with Suggestions` / `Request Changes` |
| Test Runner | `task-{id}-test-runner.done` | `PASS` / `FAIL` |
| Linter | `task-{id}-linter.done` | `PASS` / `FAIL` |

> **注意**: コードスペシャリストレビュアー（Quality/Bug/Performance/Security Reviewer）は状態値を書き出さない（デフォルトの `done`）。Lead Reviewer（Code Reviewer）が各スペシャリストの結果ファイルを直接読んで統合判定する。

> **注意**: プランスペシャリストレビュアー（Plan Quality/Bug/Performance/Security Reviewer）も同様に状態値を書き出さない（デフォルトの `done`）。Lead Plan Reviewer が各スペシャリストの結果ファイルを直接読んで統合判定する。

### 書き出しタイミング

エージェントは結果ファイルを出力した後、CLIプロセス終了直前に `.done` ファイルに状態値を書き出す:

```bash
# エージェント内での書き出し例
echo "Approved" > {SESSION_DIR}/.status/plan-reviewer.done
```

### Orchestrator での読み取り

```bash
# 状態値の取得（1行のみなので cat で十分）
STATUS=$(cat {SESSION_DIR}/.status/plan-reviewer.done 2>/dev/null)
```

Orchestrator はこの状態値のみで分岐判断を行い、結果ファイルの中身を Read する必要がない。

## .exit ファイル

- CLIプロセスの終了コードを記録
- フォーマット: `AGENT_EXIT_CODE={終了コード}`
- 終了コード 0 = 正常終了、それ以外 = エラー

## チーム設定との関係

`team-config.json` でメンバー名をカスタマイズしても、マーカーファイル名は**常に内部識別子**を使用する。
表示名はスクリプト（status-monitor, result-collector 等）が team-config.json から動的に解決する。

```
# 内部識別子: explorer → 表示名: Scout
# ファイル名は常に内部識別子
.status/explorer.done       ← 変わらない
.status/explorer.exit       ← 変わらない
```

## 命名規則

| エージェント | .done（状態値） | .exit |
|-------------|----------------|-------|
| Explorer | `explorer.done`（done） | `explorer.exit` |
| Planner | `planner.done`（done） | `planner.exit` |
| Plan Reviewer | `plan-reviewer.done`（Approved等） | `plan-reviewer.exit` |
| Plan Quality Reviewer | `plan-quality-reviewer.done`（done） | `plan-quality-reviewer.exit` |
| Plan Bug Reviewer | `plan-bug-reviewer.done`（done） | `plan-bug-reviewer.exit` |
| Plan Performance Reviewer | `plan-performance-reviewer.done`（done） | `plan-performance-reviewer.exit` |
| Plan Security Reviewer | `plan-security-reviewer.done`（done） | `plan-security-reviewer.exit` |
| Task Manager | `task-{id}-task-manager.done`（completed等） | `task-{id}-task-manager.exit` |
| Implementer | `task-{id}-implementer.done`（done） | `task-{id}-implementer.exit` |
| Code Reviewer | `task-{id}-code-reviewer.done`（Approved等） | `task-{id}-code-reviewer.exit` |
| Quality Reviewer | `task-{id}-quality-reviewer.done`（done） | `task-{id}-quality-reviewer.exit` |
| Bug Reviewer | `task-{id}-bug-reviewer.done`（done） | `task-{id}-bug-reviewer.exit` |
| Performance Reviewer | `task-{id}-performance-reviewer.done`（done） | `task-{id}-performance-reviewer.exit` |
| Security Reviewer | `task-{id}-security-reviewer.done`（done） | `task-{id}-security-reviewer.exit` |
| Test Runner | `task-{id}-test-runner.done`（PASS等） | `task-{id}-test-runner.exit` |
| Linter | `task-{id}-linter.done`（PASS等） | `task-{id}-linter.exit` |
| Phase 3 Test Runner | `test-runner.done`（PASS等） | `test-runner.exit` |
| Phase 3 Linter | `linter.done`（PASS等） | `linter.exit` |
| Security Scanner | `security-scanner.done`（done） | `security-scanner.exit` |
| Committer | `committer.done`（done） | `committer.exit` |
| PR Creator | `pr-creator.done`（done） | `pr-creator.exit` |

## 同期パターン

### 直列実行（.done の状態値で分岐）
```
explorer.done → planner 起動 → planner.done → plan-reviewer (Lead) 起動
→ plan-reviewer が 4 スペシャリストを並列起動
→ 全スペシャリスト完了 → 統合 → plan-reviewer.done の状態値を確認
  → "Approved" → Phase 2 へ
  → "Needs Revision" → planner 再起動
  → "Rejected" → ユーザーに報告
```

### 並列実行 + バリア
```
test-runner 起動 ─┐
                  ├── 両方の .done を待機
linter 起動 ──────┘
                  ↓
          各 .done の状態値を確認 → 両方 PASS → 次のフェーズ
```

### 依存関係解決
```
check-dependencies.sh が tasks.json と .done ファイルを照合
→ blockedBy のタスクがすべて .done → 実行可能として出力
```

### Task Manager 内部フロー
```
implementer.done → test-runner.done + linter.done の状態値を確認
→ 両方 PASS → code-reviewer 起動
→ code-reviewer.done の状態値を確認
  → "Approved" → 完了判定
  → "Request Changes" → implementer 再起動
```

### Plan Reviewer (Lead) 内部フロー
```
plan-reviewer が起動される
→ 前回のスペシャリストマーカーを削除
→ 4つのスペシャリストを並列起動:
  plan-quality-reviewer + plan-bug-reviewer + plan-performance-reviewer + plan-security-reviewer
→ 全4つの .done を待機
→ 各スペシャリストの結果ファイルを Read（.done の状態値は使用しない）
→ 統合レビュー結果 + タスク依存関係チェック → review-{round}.md に書き出し
→ plan-reviewer.done に状態値を書き出し（例: "Approved"）
```

### Code Reviewer (Lead) 内部フロー
```
code-reviewer が起動される
→ 前回のスペシャリストマーカーを削除
→ 4つのスペシャリストを並列起動:
  quality-reviewer + bug-reviewer + performance-reviewer + security-reviewer
→ 全4つの .done を待機
→ 各スペシャリストの結果ファイルを Read（.done の状態値は使用しない）
→ 統合レビュー結果を review-{round}.md に書き出し
→ code-reviewer.done に状態値を書き出し（例: "Approved"）
```

## リトライ時の扱い

リトライ時は既存の `.done`、`.exit` を削除してからエージェントを再起動する:

```bash
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.done
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.exit
```
