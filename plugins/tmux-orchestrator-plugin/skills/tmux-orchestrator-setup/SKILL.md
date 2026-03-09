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
      "Bash(*tmux-agent-launch.sh*)",
      "Bash(*tmux-pane-presplit.sh*)",
      "Bash(*init-session.sh*)",
      "Bash(*init-task.sh*)",
      "Bash(*init-team-session.sh*)",
      "Bash(*create-and-save-session.sh*)",
      "Bash(*tmux-session-create.sh*)",
      "Bash(*tmux-session-destroy.sh*)",
      "Bash(*check-dependencies.sh*)",
      "Bash(*complete-agent.sh*)",
      "Bash(*notify-parent.sh*)",
      "Bash(*tmux-result-collector.sh*)",
      "Bash(*tmux-status-monitor.sh*)",
      "Bash(tmux *)",
      "Bash(cat .orchestrator/*)",
      "Bash(mkdir -p .orchestrator/*)",
      "Bash(rm -f .orchestrator/*)",
      "Bash(ls .orchestrator*)",
      "Bash(ls -d .orchestrator*)",
      "Bash(PARENT_PANE=*)",
      "Bash(OUTPUT=*)",
      "Bash(TMUX_SESSION=*)",
      "Bash(NEXT_ID=*)",
      "Bash(STATUS=*)",
      "Bash(TR_STATUS=*)",
      "Bash(LT_STATUS=*)",
      "Bash(SCRIPTS_DIR=*)",
      "Bash(TEAM_SCRIPTS_DIR=*)"
    ]
  }
}
```

#### パターンの説明

| カテゴリ | パターン例 | 対象 |
|---------|-----------|------|
| スクリプト実行 | `*script-name.sh*` | プラグインキャッシュパスが環境により異なるため `*` で吸収 |
| tmux コマンド | `tmux *` | `display-message`, `send-keys`, `kill-pane`, `list-panes` 等すべての tmux サブコマンド |
| .orchestrator/ 操作 | `cat/mkdir/rm/ls .orchestrator/*` | ステータス・設定ファイルの読み書き |
| 変数代入 | `PARENT_PANE=*`, `OUTPUT=*` 等 | `$()` コマンド置換を含む変数代入（プロンプトの原因） |

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
