# 完了マーカー仕様

tmux-orchestrator のエージェント間同期メカニズム。

## 概要

各エージェントの完了は `.status/` ディレクトリ内のマーカーファイルで管理される。
`tmux-agent-launch.sh` がCLIプロセスの終了を検知し、自動的にマーカーファイルを作成する。

## ファイル構成

```
{SESSION_DIR}/.status/
├── {agent-name}.done       # 完了マーカー（空ファイル）
├── {agent-name}.exit       # 終了コードファイル
└── {agent-name}.judgment   # 判定マーカー（エージェントが書き出す）
```

## .done ファイル

- CLIプロセスの終了後に `touch` で作成される
- ファイルの存在のみが意味を持つ（内容は空）
- `wait-for-completion.sh` がこのファイルの存在をポーリングする

## .exit ファイル

- CLIプロセスの終了コードを記録
- フォーマット: `AGENT_EXIT_CODE={終了コード}`
- 終了コード 0 = 正常終了、それ以外 = エラー

## .judgment ファイル

- **エージェント自身が**プロセス終了前に書き出す（`.done` と異なり自動生成ではない）
- 判定結果の1行のみを記録する（結果ファイルの内容は含めない）
- Orchestrator や Task Manager が結果ファイルを Read せずに分岐判断できるようにするためのメカニズム

### フォーマット

```
JUDGMENT={判定値}
```

### 判定値の一覧

| エージェント | ファイル名 | 判定値 |
|-------------|-----------|--------|
| Plan Reviewer | `plan-reviewer.judgment` | `Approved` / `Needs Revision` / `Rejected` |
| Task Manager | `task-{id}-task-manager.judgment` | `completed` / `rejected` |
| Code Reviewer | `task-{id}-code-reviewer.judgment` | `Approved` / `Approved with Suggestions` / `Request Changes` |
| Test Runner | `task-{id}-test-runner.judgment` | `PASS` / `FAIL` |
| Linter | `task-{id}-linter.judgment` | `PASS` / `FAIL` |

### 書き出しタイミング

エージェントは結果ファイルを出力した後、CLIプロセス終了直前に `.judgment` ファイルを書き出す:

```bash
# エージェント内での書き出し例
echo "JUDGMENT=Approved" > {SESSION_DIR}/.status/plan-reviewer.judgment
```

### Orchestrator での読み取り

```bash
# 判定値の取得（1行のみなので cat で十分）
JUDGMENT=$(cat {SESSION_DIR}/.status/plan-reviewer.judgment 2>/dev/null | sed 's/JUDGMENT=//')
```

Orchestrator はこの値のみで分岐判断を行い、結果ファイルの中身を Read する必要がない。

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

| エージェント | .done | .exit | .judgment |
|-------------|-------|-------|-----------|
| Explorer | `explorer.done` | `explorer.exit` | — |
| Planner | `planner.done` | `planner.exit` | — |
| Plan Reviewer | `plan-reviewer.done` | `plan-reviewer.exit` | `plan-reviewer.judgment` |
| Task Manager | `task-{id}-task-manager.done` | `task-{id}-task-manager.exit` | `task-{id}-task-manager.judgment` |
| Implementer | `task-{id}-implementer.done` | `task-{id}-implementer.exit` | — |
| Code Reviewer | `task-{id}-code-reviewer.done` | `task-{id}-code-reviewer.exit` | `task-{id}-code-reviewer.judgment` |
| Quality Reviewer | `task-{id}-quality-reviewer.done` | `task-{id}-quality-reviewer.exit` | — |
| Bug Reviewer | `task-{id}-bug-reviewer.done` | `task-{id}-bug-reviewer.exit` | — |
| Performance Reviewer | `task-{id}-performance-reviewer.done` | `task-{id}-performance-reviewer.exit` | — |
| Security Reviewer | `task-{id}-security-reviewer.done` | `task-{id}-security-reviewer.exit` | — |
| Test Runner | `task-{id}-test-runner.done` | `task-{id}-test-runner.exit` | `task-{id}-test-runner.judgment` |
| Linter | `task-{id}-linter.done` | `task-{id}-linter.exit` | `task-{id}-linter.judgment` |
| Phase 3 Test Runner | `test-runner.done` | `test-runner.exit` | `test-runner.judgment` |
| Phase 3 Linter | `linter.done` | `linter.exit` | `linter.judgment` |
| Security Scanner | `security-scanner.done` | `security-scanner.exit` | — |
| Committer | `committer.done` | `committer.exit` | — |
| PR Creator | `pr-creator.done` | `pr-creator.exit` | — |

## 同期パターン

### 直列実行（.done + .judgment で分岐）
```
explorer.done → planner 起動 → planner.done → plan-reviewer 起動
→ plan-reviewer.done → plan-reviewer.judgment を確認
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
          各 .judgment を確認 → 両方 PASS → 次のフェーズ
```

### 依存関係解決
```
check-dependencies.sh が tasks.json と .done ファイルを照合
→ blockedBy のタスクがすべて .done → 実行可能として出力
```

### Task Manager 内部フロー
```
implementer.done → test-runner.judgment + linter.judgment を確認
→ 両方 PASS → code-reviewer 起動
→ code-reviewer.judgment を確認
  → "Approved" → 完了判定
  → "Request Changes" → implementer 再起動
```

### Code Reviewer (Lead) 内部フロー
```
code-reviewer が起動される
→ 前回のスペシャリストマーカーを削除
→ 4つのスペシャリストを並列起動:
  quality-reviewer + bug-reviewer + performance-reviewer + security-reviewer
→ 全4つの .done を待機
→ 各スペシャリストの結果ファイルを Read（.judgment は使用しない）
→ 統合レビュー結果を review-{round}.md に書き出し
→ code-reviewer.judgment を書き出し
→ code-reviewer.done（自動作成）
```

## リトライ時の扱い

リトライ時は既存の `.done`、`.exit`、`.judgment` を削除してからエージェントを再起動する:

```bash
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.done
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.exit
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.judgment
```
