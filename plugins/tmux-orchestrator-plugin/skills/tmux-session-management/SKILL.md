---
name: tmux-session-management
description: "tmuxオーケストレーションセッションのライフサイクル管理。セッションの作成・監視・破棄、ペインレイアウトの制御を行う。「tmuxセッション管理」「セッション確認」「セッション破棄」などのリクエスト時に使用。"
---

# tmux Session Management Skill

tmuxオーケストレーションセッションのライフサイクルを管理するスキル。

## トリガー

- オーケストレーション開始時（内部的に使用）
- 「セッション確認して」「セッション状態を見せて」と指示されたとき
- 「セッションを破棄して」「クリーンアップして」と指示されたとき

## セッション操作

### セッション作成

```bash
# 1. tmuxセッションを作成
bash .orchestrator/scripts/tmux-session-create.sh "orch-{SESSION_ID}"

# 2. セッションディレクトリを初期化
bash .orchestrator/scripts/init-session.sh ".orchestrator/{SESSION_ID}"

# 3. CLI割り当て設定を作成
# .orchestrator/{SESSION_ID}/.config/cli-assignments.json に書き出す
```

### セッション監視

```bash
# ステータスモニターを起動（control ウィンドウで実行）
bash .orchestrator/scripts/tmux-status-monitor.sh ".orchestrator/{SESSION_ID}"
```

### セッション破棄

```bash
# tmuxセッションを破棄
bash .orchestrator/scripts/tmux-session-destroy.sh "orch-{SESSION_ID}"
```

### 結果収集

```bash
# 全エージェントの結果をサマリーファイルに集約
bash .orchestrator/scripts/tmux-result-collector.sh ".orchestrator/{SESSION_ID}"
```

## セッション一覧の確認

```bash
# 全オーケストレーションセッションを表示
tmux ls 2>/dev/null | grep "^orch-"

# セッションディレクトリの一覧
ls -d .orchestrator/????-* 2>/dev/null
```

## 参照ドキュメント

- [session-lifecycle.md](references/session-lifecycle.md) - セッションのライフサイクル詳細
- [pane-layout.md](references/pane-layout.md) - ペインレイアウト設計
