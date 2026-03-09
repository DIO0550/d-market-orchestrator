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

### Step 2: Bash パーミッション設定の確認

オーケストレーターが tmux コマンドやシェルスクリプトをプロンプトなしで自動実行できるように、プラグインの `hooks/` ディレクトリに PermissionRequest hook が組み込まれている。

プラグインが有効であれば `hooks/hooks.json` が自動的にロードされ、以下のコマンドが自動許可される:

| カテゴリ | 許可条件 | 例 |
|---------|---------|-----|
| スクリプト実行 | `tmux-orchestrator-plugin` パス配下のホワイトリスト済みスクリプト（17個）のみ | `bash "$SCRIPTS_DIR/init-session.sh" ...` |
| tmux サブコマンド | ホワイトリスト済みサブコマンドのみ（`split-window`, `send-keys`, `kill-session` 等13種） | `tmux split-window -t sess -v -d` |
| マーカー削除 | `rm -f .orchestrator/` で始まるコマンドのみ（`-rf` は不許可） | `rm -f .orchestrator/sess-001/.status/agent.done` |
| ディレクトリ作成 | `mkdir -p` で `.orchestrator/` 配下のみ | `mkdir -p .orchestrator/sess-001/.config` |

> **Note**: 以前のバージョンでは `.claude/settings.json` の `permissions.allow` に18個のパターンを手動設定する必要がありましたが、現在はプラグインの hook で自動的に処理されます。

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
