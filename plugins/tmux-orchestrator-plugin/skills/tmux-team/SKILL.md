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

---

# Part 1: チーム オーケストレーション

## ワークフロー概要

```
[Launcher セットアップ] ─── Launcher エージェントが環境構築
    │
    ├── オーケストレーターが Launcher プロンプトを生成
    ├── tmux-agent-launch.sh で Launcher 起動
    ├── Launcher が実行:
    │   ├── セッションディレクトリ初期化
    │   ├── tmux セッション作成
    │   ├── ペイン事前分割 + CLI 起動
    │   └── 全メンバーの Ready 検知
    ├── [AGENT_COMPLETE] launcher done 受信
    ├── pane-registry.json を Read してペインID取得
    └── member-status.json を初期化
    │
[タスク委任（自由）] ────────────────────────
    │
    ├── オーケストレーターがタスクを分析・分解
    ├── idle メンバーにタスクを割り振り:
    │   1. .prompts/member-{N}-task-{M}.md にプロンプト生成
    │   2. 古い .done/.exit を削除
    │   3. tmux send-keys でメンバーに指示送信
    │   4. メンバーがタスクを実行
    │   5. メンバーが .done 書き出し＋ notify-parent.sh 実行
    │   6. [AGENT_COMPLETE] member-{N} {status} メッセージ受信
    │
    ├── 並列: 複数メンバーに同時にタスク割り振り可能
    ├── 完了メンバーに新たなタスクを割り当て
    │
    └── 全タスク完了 → ユーザーに報告
```

**重要**: このスキルには固定のフェーズ構造がない。タスクの分解方法、割り当て順序、レビューの要否はすべてオーケストレーター（ボス）の判断に委ねられる。

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
   NEXT_ID=$(printf "%04d" $(($(ls -d .orchestrator/????-* 2>/dev/null | sed 's/.*\///' | cut -d'-' -f1 | sort -n | tail -1 || echo 0) + 1)))
   FEATURE_NAME="{タスクから生成した英小文字ハイフン区切り名}"
   SESSION_ID="${NEXT_ID}-${FEATURE_NAME}"
   ```

2. Launcher プロンプトディレクトリを作成:
   ```bash
   mkdir -p .orchestrator/${SESSION_ID}/.prompts
   mkdir -p .orchestrator/${SESSION_ID}/.status
   ```

3. [team-launcher-prompt.md](references/templates/team-launcher-prompt.md) を Read し、パラメータ（SESSION_ID, PANE_COUNT, CLI_TOOL, WORKING_DIR, PARENT_PANE）を埋め込んで `.orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md` に Write する

4. 自身のペイン ID を取得:
   ```bash
   PARENT_PANE=$(tmux display-message -p '#{pane_id}')
   ```

5. Launcher を起動:
   ```bash
   bash $SCRIPTS_DIR/tmux-agent-launch.sh \
     "$(tmux display-message -p '#{session_name}')" "launcher" "claude" \
     ".orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md" \
     ".orchestrator/${SESSION_ID}" "$PARENT_PANE"
   ```

6. 「Launcher を起動しました。完了通知を待機中...」と出力して **ターンを終了する**

7. `[AGENT_COMPLETE] launcher done` を受信したら:
   - `.orchestrator/${SESSION_ID}/.config/pane-registry.json` を Read してペインID一覧を取得
   - `.orchestrator/${SESSION_ID}/.config/tmux-session.txt` を Read して TMUX_SESSION を取得
   - `member-status.json` を初期化（全メンバーを `ready` に設定）
   - タスク委任フェーズへ進む

8. `[AGENT_COMPLETE] launcher error` の場合:
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

### 5. 並列割り当て

複数のメンバーに同時にタスクを割り当てる場合:

```bash
# member-1 にタスク割り当て
tmux send-keys -t "$PANE_ID_1" \
  ".orchestrator/${SESSION_ID}/.prompts/member-1-task-1.md を読んで、指示に従って作業してください。" Enter

# member-2 にタスク割り当て
tmux send-keys -t "$PANE_ID_2" \
  ".orchestrator/${SESSION_ID}/.prompts/member-2-task-1.md を読んで、指示に従って作業してください。" Enter

# 各メンバーの完了通知を待機:
#   [AGENT_COMPLETE] member-1 done
#   [AGENT_COMPLETE] member-2 done
```

## 完了検知

### メインメカニズム: push 型通知

メンバーはプロンプト内の「完了手順（必須）」セクションに従い:
1. `.status/member-{N}.done` に状態値を書き出す
2. `notify-parent.sh` を実行

オーケストレーターの入力に以下のメッセージが届く:
```
[AGENT_COMPLETE] member-1 done
```

### フォールバック: タイムアウト

`[AGENT_COMPLETE]` メッセージが一定時間届かない場合:

1. `.status/member-{N}.done` を直接確認（通知だけ失敗した可能性）
2. `.done` がなければ、リマインダーを送信:
   ```bash
   tmux send-keys -t "$PANE_ID" \
     "作業が完了していたら、完了手順を実行してください: echo 'done' > .orchestrator/${SESSION_ID}/.status/member-{N}.done && bash $SCRIPTS_DIR/notify-parent.sh .orchestrator/${SESSION_ID} member-{N} ${PARENT_PANE}" Enter
   ```
3. それでも応答なし → ユーザーに報告し「待機継続」「中断」を選択

## メンバー状態管理

オーケストレーターが `.config/member-status.json` を管理してメンバー状態を追跡する。

```json
{
  "members": {
    "member-1": {
      "status": "busy",
      "current_task": "task-2",
      "tasks_completed": 1
    },
    "member-2": {
      "status": "idle",
      "current_task": null,
      "tasks_completed": 1
    }
  }
}
```

### 状態遷移

| 状態 | 意味 | 次の状態 |
|------|------|---------|
| `ready` | CLI 起動完了、タスク受付可能 | `busy` |
| `busy` | タスク実行中 | `idle` / `error` |
| `idle` | タスク完了、次のタスク受付可能 | `busy` |
| `error` | エラーまたはハング | `ready`（再起動後） |

### タスク割り当て時の選択

1. `idle` のメンバーを優先
2. `idle` がなければ `ready` のメンバー（まだタスクを受けていない）
3. 全メンバーが `busy` なら、完了を待機

## セッション管理

### セッション監視

```bash
# ステータスモニターを起動（任意）
bash $SCRIPTS_DIR/tmux-status-monitor.sh ".orchestrator/${SESSION_ID}"
```

### セッション破棄

```bash
bash $SCRIPTS_DIR/tmux-session-destroy.sh "${TMUX_SESSION}"
```

### セッション一覧

```bash
# 全オーケストレーションセッションを表示
tmux ls 2>/dev/null | grep "^orch-"

# セッションディレクトリの一覧
ls -d .orchestrator/????-* 2>/dev/null
```

## エラーハンドリング

### メンバーがクラッシュした場合

1. ペインの存在確認:
   ```bash
   tmux list-panes -t "${TMUX_SESSION}" -F '#{pane_id}' | grep -q "$PANE_ID"
   ```
2. ペインが消失している場合:
   - 新しいペインを `tmux split-window` で作成
   - CLI を再起動
   - `pane-registry.json` を更新
   - 失敗したタスクを再割り当て

### メンバーがハングした場合

1. タイムアウト検知
2. リマインダー送信（完了手順を再指示）
3. 応答なし → `tmux capture-pane -t "$PANE_ID" -p` で状況確認
4. 必要に応じてペインを kill して再作成

### メンバーのコンテキスト飽和

長時間のセッションでは、メンバーのコンテキストが飽和して品質が低下する可能性がある。

1. `member-status.json` の `tasks_completed` を監視
2. 閾値（目安: 5タスク）を超えた場合、ローテーションを検討:
   - 現在のタスク完了を待機
   - ペインを kill して再作成
   - 新しい CLI を起動
   - `pane-registry.json` を更新

### CLI 起動失敗

Launcher が `[AGENT_COMPLETE] launcher error` を返した場合:
1. `.orchestrator/${SESSION_ID}/launcher/error.md` を Read してエラー内容を確認
2. ユーザーに報告（例: コマンド未インストール、認証エラー）

## 委任パターン例

### パターン1: 探索→実装（逐次）

```
1. member-1 に「コードベースを調査して」と指示
   → member-1/task-1/result.md に探索結果
2. member-1 と member-2 に「探索結果を元に実装して」と並列指示
   → 入力: member-1/task-1/result.md
```

### パターン2: 並列実装＋レビュー

```
1. member-1 に「認証APIを実装して」
   member-2 に「ユーザーモデルを実装して」
   → 並列実行
2. 両方完了後、member-3 に「member-1 と member-2 の実装をレビューして」
   → 入力: member-1/task-1/result.md, member-2/task-1/result.md
```

### パターン3: パイプライン

```
1. member-1 に「要件を分析して」→ shared/analysis.md
2. member-2 に「分析結果を元に設計して」→ shared/design.md（member-1 完了後）
3. member-3 に「設計を元に実装して」→ member-3/task-1/result.md（member-2 完了後）
```

### パターン4: ファンアウトレビュー

```
1. member-1 に「セキュリティ観点でレビューして」
   member-2 に「パフォーマンス観点でレビューして」
   member-3 に「コード品質観点でレビューして」
   → 同じコードを異なる観点で並列レビュー
```

## オーケストレーターの制約（厳守）

- **自分で調査・実装を行わない**: 情報収集もコーディングもすべてメンバーに委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによる指示送信、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{member-id}.done` の状態値のみで行う
- **メンバー間の成果物受け渡し**: プロンプトにパスだけを記載し、メンバーが自分で Read する
- **ポーリング禁止**: サブエージェント起動後はテキスト出力のみでターンを終了し、`[AGENT_COMPLETE]` メッセージを入力として待つ

## CLI 互換性

| CLI | 対話永続モード | 備考 |
|-----|--------------|------|
| claude | 対応 | `--permission-mode acceptEdits` で起動 |
| codex | 非対応 | 非対話のみ。チームモデルでは推奨しない |
| copilot | 非対応 | 機能限定的。チームモデルでは推奨しない |

チームモデルでは全メンバーに `claude` を使用することを推奨。

---

# Part 2: セットアップ・参照

## 前提条件

- tmux がインストールされていること

## スクリプトパス

スクリプトはスキルの `references/scripts/` に配置されている（`.orchestrator/scripts/` へのコピーは不要）。

- 共有スクリプト: tmux-orchestration スキルの [references/scripts/](../tmux-orchestration/references/scripts/) → `SCRIPTS_DIR`
- チーム専用スクリプト: このスキルの [references/scripts/](references/scripts/) → `TEAM_SCRIPTS_DIR`

オーケストレーターは起動時にスクリプトパスを解決し、Launcher やメンバーのプロンプト生成時に `{SCRIPTS_DIR}` / `{TEAM_SCRIPTS_DIR}` プレースホルダを実パスに置換する。

## チーム設定のカスタマイズ（任意）

`.orchestrator/team-config.json` にメンバー設定を追加:

```json
{
  "team_name": "Alpha",
  "members": {
    "member-1": { "name": "Scout", "personality": "好奇心旺盛で何でも調べたがる" },
    "member-2": { "name": "Builder", "personality": "職人気質で実直" },
    "member-3": { "name": "Inspector", "personality": "細部にこだわる分析家" }
  }
}
```

既存の `orchestrator`, `explorer` 等のキーと競合しない。

### 反映される箇所

| 項目 | デフォルト | カスタマイズ時 |
|------|----------|-------------|
| tmux ペインタイトル | `member-1` | `Scout (member-1)` |
| プロンプト冒頭 | `あなたは member-1 です` | `あなたは **Alpha** の **Scout**（member-1）です` |
| 性格・話し方 | なし | `あなたの性格・話し方: 好奇心旺盛で何でも調べたがる` |

### 影響しない箇所

内部識別子・ファイルパス・IPC プロトコルは変更されない:
- `.status/member-1.done` — 変わらない
- `member-1/task-1/result.md` — 変わらない
- `.prompts/member-1-task-1.md` — 変わらない

---

# Part 3: 参照ドキュメント

## アーキテクチャ

- [tmux-team-architecture.md](references/tmux-team-architecture.md) - チームモデルのアーキテクチャ仕様

## スクリプト

- [tmux-pane-presplit.sh](references/scripts/tmux-pane-presplit.sh) - ペイン事前分割＋CLI起動
- [init-team-session.sh](references/scripts/init-team-session.sh) - チームセッションディレクトリ初期化

## テンプレート

- [team-member-prompt.md](references/templates/team-member-prompt.md) - メンバーへのタスク指示プロンプト
- [team-launcher-prompt.md](references/templates/team-launcher-prompt.md) - Launcher エージェント用セットアッププロンプト

## 共有リソース（tmux-orchestration と共有）

- tmux-session-create.sh — セッション作成
- tmux-session-destroy.sh — セッション破棄
- notify-parent.sh — 完了通知（ロックベース排他制御）
- tmux-status-monitor.sh — ステータス監視
