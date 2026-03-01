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

### Step 2: スキル参照の確認

以下のスキルが利用可能であることを確認:

- `tmux-orchestration` — オーケストレーション本体
- `tmux-team` — チームオーケストレーション
- `tmux-orchestrator-config` — 設定カスタマイズ

### Step 3: 完了報告

```
環境は準備完了です。スクリプトとテンプレートはスキルから直接参照されるため、追加のセットアップは不要です。

次のステップ:
  /tmux-config        — CLI割り当てやチーム設定をカスタマイズ
  /tmux-orchestrate   — オーケストレーションを開始
  /tmux-team          — チームオーケストレーションを開始
```

> **Note**: 以前のバージョンではスクリプトを `.orchestrator/scripts/` にコピーする必要がありましたが、現在はスキル参照から直接実行されるため不要です。
