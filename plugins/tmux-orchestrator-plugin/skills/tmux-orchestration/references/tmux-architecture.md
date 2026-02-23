# tmux アーキテクチャ

tmux-orchestrator のセッション・ウィンドウ・ペイン構成の詳細。

## セッション構成

```
tmux session: "{TMUX_SESSION}"
  tmux 内で実行: 現在のセッションをそのまま使用（新セッション不要）
  tmux 外で実行: "orch-{SESSION_ID}" (team_name設定時: "{team_name}-{SESSION_ID}")
│
├── window (orchestrator)  ← オーケストレーターが動作中のウィンドウ（tmux内実行時）
│   └── pane 0: orchestrator (Claude Code)
│
└── window "agents"        ← 全エージェント（tiled レイアウト）
    ├── pane: explorer
    ├── pane: planner
    ├── pane: plan-reviewer
    ├── pane: task-N-task-manager
    ├── pane: test-runner
    ├── pane: linter
    ├── pane: committer
    └── pane: pr-creator
    （起動順にペイン追加、tiled で均等配置）
```

## ウィンドウの使い方

### control ウィンドウ

Orchestrator がステータスモニターを表示するための専用ウィンドウ。
`tmux-status-monitor.sh` を実行して全エージェントの進捗をリアルタイム表示する。

### agents ウィンドウ

全エージェントの実行ウィンドウ。`tmux-agent-launch.sh` がペインを自動作成してエージェントを起動する。

- 最初のエージェントは既存の空ペインを再利用
- 2つ目以降は `split-window` で新しいペインを追加
- 各ペインのタイトルにエージェント名を設定
- tiled レイアウトで均等配置

### サブエージェントパターン

Task Manager や Code Reviewer (Lead) は自身もエージェントを tmux ペインで起動するミニオーケストレーターとして動作する。
Code Reviewer (Lead) は agents ウィンドウ内で4つのスペシャリストレビュアー（quality/bug/performance/security）を並列起動する。
スペシャリストは既にプロセスが完了した他のペイン（implementer, test-runner 等）と同じウィンドウに追加される。

## ペイン管理

### ペインの作成

```bash
# 新しいペインを作成してエージェントを起動
tmux split-window -t "orch-{SESSION_ID}:agents" -v
```

### ペインの識別

```bash
# ペインのタイトルでエージェントを識別
tmux select-pane -t "$PANE_ID" -T "explorer"
```

### ペインの一覧

```bash
# セッション内の全ペインを表示
tmux list-panes -t "{TMUX_SESSION}" -a -F \
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

### agents ウィンドウ（全エージェント）

```
┌──────────────────┬──────────────────┐
│ explorer         │ planner          │
│ (claude)         │ (claude)         │
├──────────────────┼──────────────────┤
│ plan-reviewer    │ task-1-manager   │
│ (claude)         │ (claude)         │
├──────────────────┼──────────────────┤
│ task-2-manager   │ test-runner      │
│ (codex)          │ (claude)         │
├──────────────────┼──────────────────┤
│ linter           │ committer        │
│ (codex)          │ (claude)         │
└──────────────────┴──────────────────┘
```

起動順にペインが追加され、tiled レイアウトで均等配置される。

## レイアウト調整

### 自動レイアウト

ペインが追加されるたびに tmux の自動レイアウトを適用:

```bash
# 均等分割（縦）
tmux select-layout -t "orch-{SESSION_ID}:agents" even-vertical

# タイル状（2x2グリッド）
tmux select-layout -t "orch-{SESSION_ID}:agents" tiled
```

### ペインサイズの制限

- 最小高さ: 10行（これ以下だと出力が見にくい）
- ウィンドウあたりの推奨最大ペイン数: 4
- 4ペインを超える場合は `tiled` レイアウトを使用

## ペインの操作

```bash
# 全ペインの一覧
tmux list-panes -t "{TMUX_SESSION}" -a -F \
  '#{window_name}:#{pane_index} [#{pane_title}] #{pane_current_command} #{pane_width}x#{pane_height}'

# 特定ペインの出力をキャプチャ
tmux capture-pane -t "orch-{SESSION_ID}:agents.0" -p

# ペインを全画面表示
tmux resize-pane -t "orch-{SESSION_ID}:agents.0" -Z
```
