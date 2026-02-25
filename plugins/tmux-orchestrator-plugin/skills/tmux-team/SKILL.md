---
name: tmux-team
description: "tmuxセッションに事前分割した永続ペインでAI CLIチームを編成し、ボスが動的にタスクを割り振るオーケストレーション。/tmux-team コマンド実行時、「チームで作業」「tmuxチーム」「チーム編成」「N人のチームで」「セッション確認」「セッション破棄」などのリクエスト時に使用。"
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
[チーム編成] ──────────────────────────────
    │
    ├── チーム設定読み込み（team-config.json、存在する場合）
    ├── tmuxセッション作成（tmux-session-create.sh）
    ├── チームセッションディレクトリ初期化（init-team-session.sh）
    ├── ペイン事前分割＋CLI起動（tmux-pane-presplit.sh）
    └── 全メンバーの Ready 検知
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

## チーム編成

### Step 1: セッション連番の取得

```bash
NEXT_ID=$(printf "%04d" $(($(ls -d .orchestrator/????-* 2>/dev/null | sed 's/.*\///' | cut -d'-' -f1 | sort -n | tail -1 || echo 0) + 1)))
FEATURE_NAME="{タスクから生成した英小文字ハイフン区切り名}"
SESSION_ID="${NEXT_ID}-${FEATURE_NAME}"
```

### Step 2: スクリプト配置（初回のみ）

共有スクリプト（`tmux-session-create.sh`, `notify-parent.sh` 等）が `.orchestrator/scripts/` に存在することを確認する。存在しない場合は `/tmux-setup` の実行を案内する。

チーム専用スクリプトが存在しない場合、Read → Write でコピーする:

| Read 対象 | Write 先 |
|-----------|---------|
| [tmux-pane-presplit.sh](references/scripts/tmux-pane-presplit.sh) | `.orchestrator/scripts/tmux-pane-presplit.sh` |
| [init-team-session.sh](references/scripts/init-team-session.sh) | `.orchestrator/scripts/init-team-session.sh` |
| [team-member-prompt.md](references/templates/team-member-prompt.md) | `.orchestrator/templates/team-member-prompt.md` |

コピー後:

```bash
chmod +x .orchestrator/scripts/tmux-pane-presplit.sh
chmod +x .orchestrator/scripts/init-team-session.sh
```

### Step 3: チームセッション初期化

```bash
# ディレクトリ構造を初期化
bash .orchestrator/scripts/init-team-session.sh ".orchestrator/${SESSION_ID}" "${PANE_COUNT}"
```

### Step 4: tmuxセッション作成

```bash
# チーム設定読み込み
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ]; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG")
fi

# tmuxセッション作成
OUTPUT=$(bash .orchestrator/scripts/tmux-session-create.sh "orch-${SESSION_ID}")
TMUX_SESSION=$(echo "$OUTPUT" | grep "^TMUX_SESSION=" | cut -d= -f2)

# 自身のペインIDを取得
PARENT_PANE=$(tmux display-message -p '#{pane_id}')
```

### Step 5: メンバー数の決定

- `--members N` が指定されている場合: その数を使用
- 指定されていない場合: タスクの複雑さから判断（デフォルト: 3）
  - 単純なタスク: 2
  - 中程度: 3
  - 複雑・大規模: 4〜5

### Step 6: ペイン事前分割＋CLI起動

```bash
bash .orchestrator/scripts/tmux-pane-presplit.sh \
  "${TMUX_SESSION}" "${PANE_COUNT}" ".orchestrator/${SESSION_ID}" "claude" "$(pwd)"
```

出力から `PANE_REGISTRY` のパスを取得し、pane-registry.json を Read してペインIDを記録する。

### Step 7: Ready 検知

CLI の起動完了を待機する:

1. grace period として **10秒** 待機（CLI の初期化時間）
2. 各メンバーに readiness probe を送信:
   ```bash
   # pane-registry.json から PANE_ID を取得
   tmux send-keys -t "$PANE_ID" \
     "echo 'ready' > .orchestrator/${SESSION_ID}/.status/member-${N}.ready && echo 'Ready confirmed'" Enter
   ```
3. `.status/member-{N}.ready` ファイルの出現をポーリング
4. タイムアウト: 60秒/メンバー
5. 全メンバー Ready 確認後、タスク委任開始

## タスク割り当て

### 1. プロンプトファイル生成

`.orchestrator/templates/team-member-prompt.md` を参照してプロンプトファイルを生成する。

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

### メインメカニズム: プロンプト指示

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
     "作業が完了していたら、完了手順を実行してください: echo 'done' > .orchestrator/${SESSION_ID}/.status/member-{N}.done && bash .orchestrator/scripts/notify-parent.sh .orchestrator/${SESSION_ID} member-{N} ${PARENT_PANE}" Enter
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
| `initializing` | CLI 起動中 | `ready` |
| `ready` | CLI 起動完了、タスク受付可能 | `busy` |
| `busy` | タスク実行中 | `idle` / `error` |
| `idle` | タスク完了、次のタスク受付可能 | `busy` |
| `error` | エラーまたはハング | `ready`（再起動後） |

### タスク割り当て時の選択

1. `idle` のメンバーを優先
2. `idle` がなければ `ready` のメンバー（まだタスクを受けていない）
3. 全メンバーが `busy` なら、完了を待機

## セッション管理

### セッション作成

```bash
bash .orchestrator/scripts/init-team-session.sh ".orchestrator/${SESSION_ID}" "${PANE_COUNT}"
OUTPUT=$(bash .orchestrator/scripts/tmux-session-create.sh "orch-${SESSION_ID}")
TMUX_SESSION=$(echo "$OUTPUT" | grep "^TMUX_SESSION=" | cut -d= -f2)
```

### セッション監視

```bash
# ステータスモニターを起動（任意）
bash .orchestrator/scripts/tmux-status-monitor.sh ".orchestrator/${SESSION_ID}"
```

### セッション破棄

```bash
bash .orchestrator/scripts/tmux-session-destroy.sh "${TMUX_SESSION}"
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

Ready 検知でタイムアウトした場合:
1. `tmux capture-pane -t "$PANE_ID" -p` でペイン出力を確認
2. エラー内容をユーザーに報告（例: コマンド未インストール、認証エラー）

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
- `/tmux-setup` が実行済みで `.orchestrator/scripts/` に共有スクリプトが配置されていること

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

## 共有リソース（tmux-orchestration と共有）

- tmux-session-create.sh — セッション作成
- tmux-session-destroy.sh — セッション破棄
- notify-parent.sh — 完了通知（ロックベース排他制御）
- tmux-status-monitor.sh — ステータス監視
