# 完了マーカー仕様

tmux-orchestrator のエージェント間同期メカニズム。

## 概要

各エージェントの完了は `.status/` ディレクトリ内のマーカーファイルで管理される。

**対話モード（Claude Code）**: エージェント自身が作業完了時に `.done` ファイルに状態値を書き出し、`notify-parent.sh` を Bash ツールで実行して親ペインに `[AGENT_COMPLETE]` メッセージを送信する。`tmux-agent-launch.sh` の COMPLETION_SUFFIX はフォールバック（プロセス終了時にまだ `.done` がなければデフォルト値を書き出す）として機能する。

**非対話モード（Codex 等）**: `tmux-agent-launch.sh` がCLIプロセスの終了を検知し、自動的にマーカーファイルを作成した後、`notify-parent.sh` で親ペインに `[AGENT_COMPLETE]` メッセージを `tmux send-keys` で送信する。

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
- `notify-parent.sh` がこのファイルの状態値を読み取り、`tmux send-keys` で親ペインに `[AGENT_COMPLETE] {agent-name} {status}` メッセージを送信する

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

エージェントは結果ファイルを出力した後、以下の3ステップをこの順番で実行する:

```bash
# エージェント内での書き出し例（対話モード: エージェント自身が実行）
# Step 1: 状態値を書き出す
echo "Approved" > {SESSION_DIR}/.status/plan-reviewer.done
# Step 2: 親に完了を通知する
bash {SCRIPTS_DIR}/notify-parent.sh {SESSION_DIR} plan-reviewer {PARENT_PANE}
# Step 3: 自分のペインを終了する（対話モードではプロセスが自動終了しないため必須）
tmux kill-pane
```

判定を出さないエージェント（デフォルト状態値 `done`）の場合:

```bash
echo "done" > {SESSION_DIR}/.status/{agent-name}.done
bash {SCRIPTS_DIR}/notify-parent.sh {SESSION_DIR} {agent-name} {PARENT_PANE}
tmux kill-pane
```

> `{PARENT_PANE}` はプロンプトのセッション情報から取得する（`tmux-agent-launch.sh` が第6引数として受け取り、エージェントのプロンプトに含める）。
> Step 3 の `tmux kill-pane` は対話モード（Claude Code 等）で必須。非対話モード（Codex 等）ではプロセス終了後に `tmux-agent-launch.sh` の COMPLETION_SUFFIX がペインを自動閉じるため不要だが、実行しても無害。

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

### 通知フロー（send-keys 方式）

```
Agent完了 → .done/.exit 作成 → notify-parent.sh SESSION_DIR AGENT_NAME PARENT_PANE
         → tmux send-keys -t {parent-pane} "[AGENT_COMPLETE] {agent-name} {status}" Enter

親ペイン → 入力に [AGENT_COMPLETE] メッセージを受信
         → .done ファイルの状態値を確認 → 次のアクション判断
```

メッセージにはエージェント名と状態値が含まれるため、複数エージェントが同時に完了しても区別可能。

### 直列実行（.done の状態値で分岐）
```
explorer 完了 → [AGENT_COMPLETE] explorer done → planner 起動
→ planner 完了 → [AGENT_COMPLETE] planner done → plan-reviewer (Lead) 起動
→ plan-reviewer が 4 スペシャリストを並列起動
→ 全スペシャリスト完了 → 統合 → plan-reviewer.done の状態値を確認
  → "Approved" → Phase 2 へ
  → "Needs Revision" → planner 再起動
  → "Rejected" → ユーザーに報告
```

### 並列実行 + バリア
```
test-runner 起動 ─┐
                  ├── [AGENT_COMPLETE] メッセージを各エージェントから受信
linter 起動 ──────┘   （順序不問: メッセージは到着順に処理）
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
→ PARENT_PANE=$(tmux display-message -p '#{pane_id}') で自身のペインIDを取得
→ 前回のスペシャリストマーカーを削除
→ 4つのスペシャリストを並列起動（PARENT_PANE を第6引数に渡す）:
  plan-quality-reviewer + plan-bug-reviewer + plan-performance-reviewer + plan-security-reviewer
→ 全4つの [AGENT_COMPLETE] メッセージを受信
→ 各スペシャリストの結果ファイルを Read（.done の状態値は使用しない）
→ 統合レビュー結果 + タスク依存関係チェック → review-{round}.md に書き出し
→ plan-reviewer.done に状態値を書き出し（例: "Approved"）
→ notify-parent.sh で親ペインに [AGENT_COMPLETE] plan-reviewer Approved を送信
```

### Code Reviewer (Lead) 内部フロー
```
code-reviewer が起動される
→ PARENT_PANE=$(tmux display-message -p '#{pane_id}') で自身のペインIDを取得
→ 前回のスペシャリストマーカーを削除
→ 4つのスペシャリストを並列起動（PARENT_PANE を第6引数に渡す）:
  quality-reviewer + bug-reviewer + performance-reviewer + security-reviewer
→ 全4つの [AGENT_COMPLETE] メッセージを受信
→ 各スペシャリストの結果ファイルを Read（.done の状態値は使用しない）
→ 統合レビュー結果を review-{round}.md に書き出し
→ code-reviewer.done に状態値を書き出し（例: "Approved"）
→ notify-parent.sh で親ペインに [AGENT_COMPLETE] code-reviewer Approved を送信
```

## リトライ時の扱い

リトライ時は既存の `.done`、`.exit` を削除してからエージェントを再起動する:

```bash
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.done
rm -f ${SESSION_DIR}/.status/${AGENT_NAME}.exit
```
