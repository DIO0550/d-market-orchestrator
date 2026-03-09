---
name: tmux-team
description: "tmuxセッションに事前分割した永続ペインでAI CLIチームを編成し、ボスが動的にタスクを割り振るオーケストレーション。/tmux-team コマンド実行時、「チームで作業」「tmuxチーム」「チーム編成」「N人のチームで」「セッション確認」「セッション破棄」などのリクエスト時に使用。"
disable-model-invocation: true
---

# tmux Team Skill

事前分割したペインでチームを編成し、オーケストレーター（ボス）が自由にタスクを割り振るモデル。
各メンバーは CLI をインタラクティブモードで常駐し、ボスの指示を待つ。

## トリガー

- `/tmux-team` コマンドが実行されたとき
- ユーザーが「チームで作業」「tmuxチーム」「チーム編成」と指示したとき
- ユーザーが「N人のチームで」「3ペインで」と指示したとき
- ユーザーが「セッション確認して」「セッション破棄して」と指示したとき

**重要**: このスキルには固定のフェーズ構造がない。タスクの分解方法、割り当て順序、レビューの要否はすべてオーケストレーター（ボス）の判断に委ねられる。

---

## チームセットアップ（Launcher 委譲）

セッション構築はすべて **Launcher エージェント** に委譲する。オーケストレーターが直接セットアップを行わないことで、コンテキストの消費を防ぐ。

### メンバー数の決定

- `--members N` が指定されている場合: その数を使用
- 指定されていない場合: タスクの複雑さから判断（デフォルト: 3）
  - 単純なタスク: 2
  - 中程度: 3
  - 複雑・大規模: 4〜5

### Launcher 起動手順

1. セッション ID を生成:
   ```bash
   bash "$SCRIPTS_DIR/generate-session-id.sh" "{feature-name}"
   ```
   > 出力: `SESSION_ID=0001-feature-name`

2. セッションディレクトリを初期化:
   ```bash
   bash "$SCRIPTS_DIR/init-session.sh" ".orchestrator/${SESSION_ID}"
   ```

3. [team-launcher-prompt.md](references/templates/team-launcher-prompt.md) を Read し、パラメータ（SESSION_ID, PANE_COUNT, CLI_TOOL, WORKING_DIR, PARENT_PANE）を埋め込んで `.orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md` に Write する

4. 自身のペイン ID を取得:
   ```bash
   bash "$SCRIPTS_DIR/get-parent-pane.sh" ".orchestrator/${SESSION_ID}"
   ```
   > 出力: `PARENT_PANE={pane-id}`（`.config/parent-pane.txt` にも自動保存）

5. tmux セッション名を取得:
   ```bash
   bash "$SCRIPTS_DIR/create-and-save-session.sh" "${SESSION_ID}" ".orchestrator/${SESSION_ID}"
   ```
   > 出力: `TMUX_SESSION={session-name}`

6. Launcher を起動:
   ```bash
   bash "$SCRIPTS_DIR/tmux-agent-launch.sh" \
     "{TMUX_SESSION}" "launcher" "claude" \
     ".orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md" \
     ".orchestrator/${SESSION_ID}" "{PARENT_PANE}"
   ```

7. 「Launcher を起動しました。完了通知を待機中...」と出力して **ターンを終了する**

8. `[AGENT_COMPLETE] launcher done` を受信したら:
   - `.orchestrator/${SESSION_ID}/.config/pane-registry.json` を Read してペインID一覧を取得
   - `.orchestrator/${SESSION_ID}/.config/tmux-session.txt` を Read して TMUX_SESSION を取得
   - `member-status.json` を初期化（全メンバーを `ready` に設定）
   - タスク委任フェーズへ進む

9. `[AGENT_COMPLETE] launcher error` の場合:
   - `.orchestrator/${SESSION_ID}/launcher/error.md` を Read してエラー内容を確認
   - ユーザーにエラーを報告

### キャラ情報の永続化

`tmux-pane-presplit.sh` は `team-config.json` からメンバーのキャラ情報（名前・性格）を読み取り、`--system-prompt` フラグで CLI に渡す。システムプロンプトはコンテキスト圧縮（compact）の影響を受けないため、セッション中ずっとキャラ設定が維持される。

## タスク割り当て

### 1. プロンプトファイル生成

[team-member-prompt.md](references/templates/team-member-prompt.md) を参照してプロンプトファイルを生成する。

```
生成先: .orchestrator/{SESSION_ID}/.prompts/member-{N}-task-{M}.md
```

プロンプトには以下を含める:
- メンバーの役割（このタスクでの役割）
- タスクの詳細
- 入力ファイルのパス（あれば）
- 結果の出力先
- **完了手順**（.done 書き出し + notify-parent.sh 実行）

### 2. 前タスクの完了マーカーを削除

```bash
rm -f .orchestrator/${SESSION_ID}/.status/member-{N}.done
rm -f .orchestrator/${SESSION_ID}/.status/member-{N}.exit
```

### 3. タスクの結果ディレクトリを作成

```bash
mkdir -p .orchestrator/${SESSION_ID}/member-{N}/task-{M}
```

### 4. tmux send-keys で指示送信

```bash
tmux send-keys -t "$PANE_ID" \
  ".orchestrator/${SESSION_ID}/.prompts/member-1-task-1.md を読んで、指示に従って作業してください。" Enter
```

> **注意**: send-keys で送信するのは短い参照文のみ。詳細な指示はプロンプトファイルに記載する。

複数メンバーへの並列割り当ても同様に、各メンバーに対して send-keys を実行する。

## 完了検知

メンバーはプロンプト内の「完了手順（必須）」セクションに従い、`.status/member-{N}.done` に状態値を書き出し `notify-parent.sh` を実行する。オーケストレーターの入力に以下のメッセージが届く:

```
[AGENT_COMPLETE] member-1 done
```

`[AGENT_COMPLETE]` が一定時間届かない場合は `.status/member-{N}.done` を直接確認し、なければリマインダーを送信する。それでも応答なければユーザーに報告する。

## メンバー選択ルール

オーケストレーターが `.config/member-status.json` でメンバー状態を追跡する（状態: `ready` / `busy` / `idle` / `error`）。タスク割り当て時:

1. `idle` のメンバーを優先
2. `idle` がなければ `ready` のメンバー（まだタスクを受けていない）
3. 全メンバーが `busy` なら、完了を待機

## オーケストレーターの制約（厳守）

- **自分で調査・実装を行わない**: 情報収集もコーディングもすべてメンバーに委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによる指示送信、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{member-id}.done` の状態値のみで行う
- **メンバー間の成果物受け渡し**: プロンプトにパスだけを記載し、メンバーが自分で Read する
- **ポーリング禁止**: サブエージェント起動後はテキスト出力のみでターンを終了し、`[AGENT_COMPLETE]` メッセージを入力として待つ

---

## 前提条件

- tmux がインストールされていること

## スクリプトパス

スクリプトはスキルの `references/scripts/` に配置されている（`.orchestrator/scripts/` へのコピーは不要）。

- 共有スクリプト: tmux-orchestration スキルの [references/scripts/](../tmux-orchestration/references/scripts/) → `SCRIPTS_DIR`
- チーム専用スクリプト: このスキルの [references/scripts/](references/scripts/) → `TEAM_SCRIPTS_DIR`

オーケストレーターは起動時にスクリプトパスを解決し、Launcher やメンバーのプロンプト生成時に `{SCRIPTS_DIR}` / `{TEAM_SCRIPTS_DIR}` プレースホルダを実パスに置換する。

## 参照ドキュメント

- [tmux-team-architecture.md](references/tmux-team-architecture.md) - アーキテクチャ仕様・状態管理・エラーハンドリング・委任パターン・チーム設定
- [tmux-pane-presplit.sh](references/scripts/tmux-pane-presplit.sh) - ペイン事前分割＋CLI起動
- [init-team-session.sh](references/scripts/init-team-session.sh) - チームセッションディレクトリ初期化
- [team-member-prompt.md](references/templates/team-member-prompt.md) - メンバーへのタスク指示プロンプト
- [team-launcher-prompt.md](references/templates/team-launcher-prompt.md) - Launcher エージェント用セットアッププロンプト

### 共有リソース（tmux-orchestration と共有）

- tmux-session-create.sh — セッション作成
- tmux-session-destroy.sh — セッション破棄
- notify-parent.sh — 完了通知（ロックベース排他制御）
- tmux-status-monitor.sh — ステータス監視
