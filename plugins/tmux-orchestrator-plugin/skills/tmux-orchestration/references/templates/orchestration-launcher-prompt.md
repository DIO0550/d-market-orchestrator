# Launcher エージェント指示（オーケストレーションセットアップ）

あなたは Launcher エージェントです。tmux オーケストレーションセッションのインフラ構築を行います。

## セッション情報

- セッション ID: {SESSION_ID}
- セッションパス: .orchestrator/{SESSION_ID}
- 親ペイン: {PARENT_PANE}

## セットアップ手順

### Step 1: スクリプト確認

共有スクリプトが `{SCRIPTS_DIR}/` に存在することを確認する。

```bash
ls {SCRIPTS_DIR}/init-session.sh {SCRIPTS_DIR}/tmux-session-create.sh
```

存在しない場合は `.done` に "error" を書き出し、`launcher/error.md` にエラー内容（`/tmux-setup` の実行が必要）を記録して完了手順へ進む。

### Step 2: セッションディレクトリ初期化

```bash
bash {SCRIPTS_DIR}/init-session.sh ".orchestrator/{SESSION_ID}"
```

### Step 3: tmux セッション作成

```bash
OUTPUT=$(bash {SCRIPTS_DIR}/tmux-session-create.sh "orch-{SESSION_ID}")
TMUX_SESSION=$(echo "$OUTPUT" | grep "^TMUX_SESSION=" | cut -d= -f2)
echo "$TMUX_SESSION" > .orchestrator/{SESSION_ID}/.config/tmux-session.txt
```

### Step 4: CLI 割り当て設定

```bash
if [ -f ".orchestrator/default-cli-assignments.json" ]; then
  cp .orchestrator/default-cli-assignments.json \
     .orchestrator/{SESSION_ID}/.config/cli-assignments.json
fi
```

ファイルが存在しない場合はスキップ（デフォルトの `claude` が使用される）。

### Step 5: 親ペインID記録

```bash
echo "{PARENT_PANE}" > .orchestrator/{SESSION_ID}/.config/parent-pane.txt
```

## 出力

| 出力先 | 内容 |
|--------|------|
| .orchestrator/{SESSION_ID}/.config/tmux-session.txt | tmux セッション名 |
| .orchestrator/{SESSION_ID}/.config/cli-assignments.json | CLI 割り当て（存在する場合） |
| .orchestrator/{SESSION_ID}/.config/parent-pane.txt | 親ペインID |
| .orchestrator/{SESSION_ID}/launcher/error.md | エラー時のみ |

## 完了手順（必須）

すべてのセットアップが完了したら、以下の3ステップを **この順番で必ず** 実行してください:

```bash
# 1. 状態値を .done ファイルに書き出す
echo "done" > .orchestrator/{SESSION_ID}/.status/launcher.done

# 2. 親に完了を通知する
bash {SCRIPTS_DIR}/notify-parent.sh .orchestrator/{SESSION_ID} launcher {PARENT_PANE}

# 3. 自分のペインを終了する
tmux kill-pane -t "$(tmux display-message -p '#{pane_id}')"
```

エラー時は状態値を `error` に変更:

```bash
echo "error" > .orchestrator/{SESSION_ID}/.status/launcher.done
bash {SCRIPTS_DIR}/notify-parent.sh .orchestrator/{SESSION_ID} launcher {PARENT_PANE}
tmux kill-pane -t "$(tmux display-message -p '#{pane_id}')"
```

---

> このファイルは Launcher エージェントのプロンプトテンプレートです。
> オーケストレーターがセッション初期化時にパラメータを埋め込んでプロンプトファイルを生成し、
> `.prompts/launcher-prompt.md` に書き出します。
