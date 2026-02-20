# セッションライフサイクル

tmuxオーケストレーションセッションの作成から破棄までのライフサイクル。

## ライフサイクル図

```
[作成] → [初期化] → [実行] → [監視] → [収集] → [破棄]
```

## 各フェーズ

### 1. 作成（Creation）

tmux セッションとウィンドウを作成する。

```bash
bash .orchestrator/scripts/tmux-session-create.sh "orch-0001-user-auth"
```

**前提条件**:
- tmux がインストールされていること
- 同名のセッションが存在しないこと（存在する場合は自動で破棄・再作成）

**結果**:
- tmux セッション `orch-0001-user-auth` が作成
- ウィンドウ: control, phase1, phase2, phase3, phase4

### 2. 初期化（Initialization）

セッションディレクトリとメタデータを初期化する。

```bash
bash .orchestrator/scripts/init-session.sh ".orchestrator/0001-user-auth"
```

**結果**:
- `.config/`, `.status/`, `.prompts/`, `.deps/` ディレクトリ作成
- 各エージェントの結果ディレクトリ作成
- `cli-assignments.json` の配置

### 3. 実行（Execution）

Orchestrator がエージェントを tmux ペインに順次起動する。

```bash
# エージェント起動
bash .orchestrator/scripts/tmux-agent-launch.sh \
  "orch-0001-user-auth" "phase1" "explorer" "claude" \
  ".orchestrator/0001-user-auth/.prompts/explorer-prompt.md" \
  ".orchestrator/0001-user-auth"
```

### 4. 監視（Monitoring）

エージェントからのロック付き通知をイベント駆動で待機する。

```bash
# エージェント完了通知の待機（イベント駆動、ポーリングなし）
bash .orchestrator/scripts/wait-for-notification.sh \
  ".orchestrator/0001-user-auth" "orch-0001-user-auth" 600

# リアルタイムモニター（control ウィンドウ表示用）
bash .orchestrator/scripts/tmux-status-monitor.sh \
  ".orchestrator/0001-user-auth"
```

### 5. 収集（Collection）

全エージェントの結果をサマリーファイルに集約する。

```bash
bash .orchestrator/scripts/tmux-result-collector.sh \
  ".orchestrator/0001-user-auth"
```

**結果**:
- `.orchestrator/0001-user-auth/implementation-log.md` が作成

### 6. 破棄（Destruction）

tmux セッションを破棄する。セッションディレクトリは保持される（履歴として）。

```bash
bash .orchestrator/scripts/tmux-session-destroy.sh "orch-0001-user-auth"
```

## セッション ID の採番

```
1. .orchestrator/ 内の `????-*` パターンをスキャン
2. 最大連番を取得（なければ 0000）
3. 連番 + 1 で新しい ID を生成
4. feature 名を付与（英小文字ハイフン区切り）
```

例: `0001-user-auth`, `0002-api-refactor`, `0003-bug-fix`

## 複数セッションの管理

同時に複数のオーケストレーションセッションを実行可能:

```bash
# 全セッションの一覧
tmux ls 2>/dev/null | grep "^orch-"

# 特定セッションにアタッチ
tmux attach -t "orch-0001-user-auth"

# セッション間の切り替え
tmux switch-client -t "orch-0002-api-refactor"
```
