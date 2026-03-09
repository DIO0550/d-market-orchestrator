---
name: tmux-orchestrator-setup
description: "tmux オーケストレーション環境の確認。「tmuxセットアップ」「tmuxオーケストレーターをセットアップ」「オーケストレーション環境を初期化」などのリクエスト時に使用。"
disable-model-invocation: true
---

# tmux Orchestrator Setup

tmux オーケストレーション環境の準備状態を確認する。

スクリプトとテンプレートはスキルの `references/` に配置されており、オーケストレーターがスキル参照から直接読み込む。`.orchestrator/` へのコピーは不要。

## トリガー

- `/tmux-setup` コマンドが実行されたとき
- ユーザーが「tmuxセットアップ」「tmuxオーケストレーターをセットアップ」と指示したとき

---

## 確認手順

### Step 1: tmux の存在確認

```bash
tmux -V
```

tmux がインストールされていない場合はインストール方法を案内する。

### Step 2: Bash パーミッション設定

オーケストレーターが tmux コマンドやシェルスクリプトをプロンプトなしで自動実行できるように、`.claude/settings.json` に `permissions.allow` を設定する。

1. `.claude/settings.json` が存在するか確認
2. 存在しない場合は以下の内容で新規作成、存在する場合は `permissions.allow` 配列に不足パターンをマージする

```json
{
  "permissions": {
    "allow": [
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/generate-session-id.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/init-session.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/init-task.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/init-team-session.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/create-and-save-session.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/get-parent-pane.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/tmux-agent-launch.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/generate-agent-prompt.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/tmux-pane-presplit.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/read-agent-status.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/check-dependencies.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/complete-agent.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/notify-parent.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/tmux-session-destroy.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/tmux-result-collector.sh*)",
      "Bash(bash *tmux-orchestrator-plugin/*/references/scripts/tmux-status-monitor.sh*)",
      "Bash(tmux send-keys*)",
      "Bash(rm -f .orchestrator/*)"
    ]
  }
}
```

#### パターンの説明

| カテゴリ | パターン例 | 対象 |
|---------|-----------|------|
| スクリプト実行 | `bash *tmux-orchestrator-plugin/*/references/scripts/xxx.sh*` | プラグイン名+ディレクトリ構造で安全性を確保。先頭 `*` でキャッシュパスを吸収、`*/` でスキル名の差異を吸収 |
| tmux send-keys | `tmux send-keys*` | チームモードでメンバーへの指示送信に使用 |
| マーカー削除 | `rm -f .orchestrator/*` | リトライ時の .done/.exit マーカー削除 |

### Step 3: スキル参照の確認

以下のスキルが利用可能であることを確認:

- `tmux-orchestration` — オーケストレーション本体
- `tmux-team` — チームオーケストレーション
- `tmux-orchestrator-config` — 設定カスタマイズ

### Step 4: 完了報告

```
環境は準備完了です。スクリプトとテンプレートはスキルから直接参照されるため、追加のセットアップは不要です。
Bash パーミッションが .claude/settings.json に設定されました。

次のステップ:
  /tmux-config        — CLI割り当てやチーム設定をカスタマイズ
  /tmux-orchestrate   — オーケストレーションを開始
  /tmux-team          — チームオーケストレーションを開始
```

> **Note**: 以前のバージョンではスクリプトを `.orchestrator/scripts/` にコピーする必要がありましたが、現在はスキル参照から直接実行されるため不要です。
