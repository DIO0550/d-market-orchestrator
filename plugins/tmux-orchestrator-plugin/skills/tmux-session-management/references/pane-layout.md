# ペインレイアウト設計

tmux ウィンドウ内のペイン配置とレイアウト管理。

## デフォルトレイアウト

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
