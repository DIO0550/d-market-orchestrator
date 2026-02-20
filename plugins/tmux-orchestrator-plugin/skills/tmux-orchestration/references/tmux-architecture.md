# tmux アーキテクチャ

tmux-orchestrator のセッション・ウィンドウ・ペイン構成の詳細。

## セッション構成

```
tmux session: "orch-{SESSION_ID}"
│
├── window "control"       ← ステータスモニター表示
│   └── pane 0: tmux-status-monitor.sh
│
├── window "phase1"        ← 探索・計画・レビュー
│   ├── pane 0: explorer (CLI プロセス)
│   ├── pane 1: planner (CLI プロセス)
│   └── pane 2: plan-reviewer (CLI プロセス)
│
├── window "phase2"        ← 実装（タスクごと）
│   ├── pane 0: task-1-task-manager (CLI プロセス)
│   ├── pane 1: task-2-task-manager (CLI プロセス)
│   └── pane N: task-N-task-manager (CLI プロセス)
│
├── window "phase3"        ← 検証
│   ├── pane 0: test-runner (CLI プロセス)
│   ├── pane 1: linter (CLI プロセス)
│   └── pane 2: security-scanner (CLI プロセス)
│
└── window "phase4"        ← Git操作
    ├── pane 0: committer (CLI プロセス)
    └── pane 1: pr-creator (CLI プロセス)
```

## ウィンドウの使い方

### control ウィンドウ

Orchestrator がステータスモニターを表示するための専用ウィンドウ。
`tmux-status-monitor.sh` を実行して全エージェントの進捗をリアルタイム表示する。

### phase ウィンドウ

各フェーズの実行ウィンドウ。`tmux-agent-launch.sh` がペインを自動作成してエージェントを起動する。

- 最初のエージェントは既存の空ペインを再利用
- 2つ目以降は `split-window` で新しいペインを追加
- 各ペインのタイトルにエージェント名を設定

### サブエージェントパターン（Phase 2）

Task Manager や Code Reviewer (Lead) は自身もエージェントを tmux ペインで起動するミニオーケストレーターとして動作する。
Code Reviewer (Lead) は Phase 2 ウィンドウ内で4つのスペシャリストレビュアー（quality/bug/performance/security）を並列起動する。
スペシャリストは既にプロセスが完了した他のペイン（implementer, test-runner 等）と同じウィンドウに追加される。

## ペイン管理

### ペインの作成

```bash
# 新しいペインを作成してエージェントを起動
tmux split-window -t "orch-{SESSION_ID}:phase1" -v
```

### ペインの識別

```bash
# ペインのタイトルでエージェントを識別
tmux select-pane -t "$PANE_ID" -T "explorer"
```

### ペインの一覧

```bash
# セッション内の全ペインを表示
tmux list-panes -t "orch-{SESSION_ID}" -a -F \
  '#{window_name}:#{pane_index} #{pane_title} #{pane_current_command}'
```

## セッション命名規則

```
orch-{連番}-{feature名}
```

例:
- `orch-0001-user-auth`
- `orch-0002-api-refactor`
- `orch-0003-bug-fix-login`

## 並列実行の制限

tmux のペインは画面サイズに制限されるため、同時起動するペイン数を制御する:

- デフォルト上限: 4ペイン/ウィンドウ
- `--parallel-limit` オプションで変更可能
- 上限を超える場合はキュー管理で順次起動

## 作業ディレクトリ

すべてのペインはプロジェクトルート（`.orchestrator/` が存在するディレクトリ）で起動する。
`tmux-agent-launch.sh` の `working-dir` 引数で明示的に指定可能。

## ペインレイアウト

### control ウィンドウ

```
┌─────────────────────────────────────┐
│                                     │
│       tmux-status-monitor.sh        │
│       （リアルタイムステータス）      │
│                                     │
└─────────────────────────────────────┘
```

ステータスモニターが全エージェントの進捗を3秒間隔で更新表示。

### phase1 ウィンドウ（探索・計画）

```
┌─────────────────────────────────────┐
│ explorer (claude)                   │
├─────────────────────────────────────┤
│ planner (claude)                    │
├─────────────────────────────────────┤
│ plan-reviewer (claude)              │
└─────────────────────────────────────┘
```

エージェントは順次起動されるため、同時に3ペインすべてがアクティブになることは通常ない。

### phase2 ウィンドウ（実装）

```
┌──────────────────┬──────────────────┐
│ task-1-manager   │ task-2-manager   │
│ (claude)         │ (codex)          │
├──────────────────┼──────────────────┤
│ task-3-manager   │ task-4-manager   │
│ (claude)         │ (claude)         │
└──────────────────┴──────────────────┘
```

タスク数に応じてペインが動的に追加される。並列上限（デフォルト4）を超える場合はキューイング。

### phase3 ウィンドウ（検証）

```
┌──────────────────┬──────────────────┐
│ test-runner      │ linter           │
│ (claude)         │ (codex)          │
├──────────────────┴──────────────────┤
│ security-scanner (claude)           │
└─────────────────────────────────────┘
```

test-runner と linter は並列実行。security-scanner はオプション。

### phase4 ウィンドウ（Git）

```
┌─────────────────────────────────────┐
│ committer (claude)                  │
├─────────────────────────────────────┤
│ pr-creator (claude)                 │
└─────────────────────────────────────┘
```

committer → pr-creator の順で実行。

## レイアウト調整

### 自動レイアウト

ペインが追加されるたびに tmux の自動レイアウトを適用:

```bash
# 均等分割（縦）
tmux select-layout -t "orch-{SESSION_ID}:phase2" even-vertical

# タイル状（2x2グリッド）
tmux select-layout -t "orch-{SESSION_ID}:phase2" tiled
```

### ペインサイズの制限

- 最小高さ: 10行（これ以下だと出力が見にくい）
- ウィンドウあたりの推奨最大ペイン数: 4
- 4ペインを超える場合は `tiled` レイアウトを使用

## ペインの操作

```bash
# 全ペインの一覧
tmux list-panes -t "orch-{SESSION_ID}" -a -F \
  '#{window_name}:#{pane_index} [#{pane_title}] #{pane_current_command} #{pane_width}x#{pane_height}'

# 特定ペインの出力をキャプチャ
tmux capture-pane -t "orch-{SESSION_ID}:phase1.0" -p

# ペインを全画面表示
tmux resize-pane -t "orch-{SESSION_ID}:phase1.0" -Z
```
