# tmux Team Architecture

チームモデルのアーキテクチャ仕様。

## 既存モデルとの比較

| 項目 | tmux-orchestration | tmux-team |
|------|-------------------|-----------|
| ペインライフサイクル | オンデマンド作成、完了後破棄 | 事前分割、永続 |
| CLI モード | ワンショット（`claude "$(cat prompt)"`） | インタラクティブ（`claude --permission-mode acceptEdits`） |
| 役割 | 固定（explorer, planner, ...） | 動的、タスクごとに指定 |
| ワークフロー | Phase 0〜4 の定型フロー | 自由（オーケストレーター判断） |
| タスク配信 | プロンプトファイルを CLI 引数に | プロンプトファイル + `tmux send-keys` |
| 完了検知 | COMPLETION_SUFFIX（シェルラッパー）| エージェント自身が `notify-parent.sh` 実行 |
| メンバー命名 | ロールベース（explorer, planner） | インデックスベース（member-1, member-2） |

| CLI | 対話永続モード | 備考 |
|-----|--------------|------|
| claude | 対応 | `--permission-mode acceptEdits` で起動 |
| codex | 非対応 | 非対話のみ。チームモデルでは推奨しない |
| copilot | 非対応 | 機能限定的。チームモデルでは推奨しない |

チームモデルでは全メンバーに `claude` を使用することを推奨。

## セッション構成

```
tmux session: "{TMUX_SESSION}"
  例: "Alpha-0001-user-auth" or "orch-0001-user-auth"

  ├── Pane 0: オーケストレーター（ボス）
  │
  └── メンバーペイン（tiled レイアウト）
      ├── pane: member-1（インタラクティブ claude）
      ├── pane: member-2（インタラクティブ claude）
      └── pane: member-3（インタラクティブ claude）
```

### ペインレイアウト（3メンバーの例）

```
┌──────────────────┬──────────────────┐
│ Orchestrator     │ member-1         │
│ (Boss)           │ (claude)         │
├──────────────────┼──────────────────┤
│ member-2         │ member-3         │
│ (claude)         │ (claude)         │
└──────────────────┴──────────────────┘
```

## ペインライフサイクル

```
[Pre-split]                    [Task Loop]                       [Shutdown]
    │                              │                                  │
    ├── tmux split-window          ├── send-keys で指示送信          ├── tmux kill-session
    ├── select-layout tiled        ├── メンバーが作業実行             │   (全ペイン終了)
    ├── select-pane -T 設定        ├── .done 書き出し                │
    ├── send-keys で CLI 起動      ├── notify-parent.sh 実行         │
    │                              ├── [AGENT_COMPLETE] 受信          │
    │                              ├── .done/.exit クリア             │
    │                              └── 次のタスクを send-keys         │
    │                                  (繰り返し)                     │
```

### 既存モデルとのライフサイクル差異

**tmux-orchestration**:
```
split-window → send-keys(cli "$(cat prompt)") → 完了 → kill-pane
```
- ペインはタスクの寿命と同じ
- COMPLETION_SUFFIX がシェルレベルで .done/.exit/notify/kill を処理

**tmux-team**:
```
split-window → send-keys(cli --system-prompt "キャラ情報") → [Ready] → send-keys(指示) → 完了通知 → send-keys(次の指示) → ...
```
- ペインはセッションの寿命と同じ
- 完了通知はエージェント自身が Bash ツールで実行
- キャラ情報は `--system-prompt` でシステムプロンプトに注入（compact の影響を受けない）

## セッションディレクトリ構造

```
.orchestrator/{SESSION_ID}/
├── .config/
│   ├── pane-registry.json       # ペインID ↔ メンバー名の対応
│   ├── member-status.json       # メンバー状態追跡（オーケストレーター管理）
│   └── cli-assignments.json     # メンバー別 CLI 割り当て（任意）
├── .status/
│   ├── member-1.ready           # Ready 検知用
│   ├── member-1.done            # タスク完了マーカー（状態値含む）
│   ├── member-1.exit            # 終了コード
│   └── .notify-lock/            # 排他制御ロック（notify-parent.sh）
├── .prompts/
│   ├── member-1-task-1.md       # member-1 の1番目のタスク
│   ├── member-1-task-2.md       # member-1 の2番目のタスク
│   └── member-2-task-1.md
├── member-1/
│   ├── task-1/
│   │   └── result.md
│   └── task-2/
│       └── result.md
├── member-2/
│   └── task-1/
│       └── result.md
└── shared/                      # メンバー間共有成果物
```

### pane-registry.json

```json
{
  "panes": {
    "member-1": { "pane_id": "%5", "cli": "claude" },
    "member-2": { "pane_id": "%6", "cli": "claude" },
    "member-3": { "pane_id": "%7", "cli": "claude" }
  },
  "pane_count": 3
}
```

### member-status.json

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
    },
    "member-3": {
      "status": "busy",
      "current_task": "task-3",
      "tasks_completed": 0
    }
  }
}
```

### メンバー状態遷移

| 状態 | 意味 | 次の状態 |
|------|------|---------|
| `ready` | CLI 起動完了、タスク受付可能 | `busy` |
| `busy` | タスク実行中 | `idle` / `error` |
| `idle` | タスク完了、次のタスク受付可能 | `busy` |
| `error` | エラーまたはハング | `ready`（再起動後） |

## IPC プロトコル

### 既存との共通部分

- `.done` ファイル: 完了マーカー（状態値含む、1行）
- `.exit` ファイル: 終了コード記録
- `notify-parent.sh`: ロックベースの排他的完了通知
- `[AGENT_COMPLETE] {member-id} {status}` メッセージ形式
- `.notify-lock/` による同時通知防止

### チームモデル固有

- `.ready` ファイル: CLI 起動完了の検知用
- `pane-registry.json`: ペインID管理（既存モデルでは不要）
- `member-status.json`: メンバー状態追跡（既存モデルではフェーズで暗黙的に管理）
- `.deps/tasks.json` は使用しない（依存関係はオーケストレーターが動的に判断）

### タスク割り当てシーケンス

```
Orchestrator                                  member-1 (pane)
    │                                             │
    ├── プロンプトファイル生成                     │
    │   (.prompts/member-1-task-1.md)             │
    ├── .done/.exit 削除（前タスクの残り）         │
    │                                             │
    ├── tmux send-keys ──────────────────────────→│
    │   "...prompt を読んで指示に従ってください"   │
    │                                             ├── Read prompt file
    │                                             ├── 作業実行...
    │                                             ├── 結果を member-1/task-1/ に書き出し
    │                                             ├── echo 'done' > .status/member-1.done
    │                                             ├── bash notify-parent.sh
    │                                             │
    │←── [AGENT_COMPLETE] member-1 done ──────────┤
    │                                             │
    ├── .status/member-1.done を確認              │ (待機中)
    ├── member-status.json を更新                 │
    └── 次のタスクを割り当て...                   │
```

## セッション管理

### セッション監視

```bash
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

## チーム設定

`.orchestrator/team-config.json` でメンバー設定をカスタマイズできる（任意）:

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
同じ `team-config.json` で両モデルの設定を共存可能。

### 反映される箇所

| 項目 | デフォルト | カスタマイズ時 |
|------|----------|-------------|
| tmux ペインタイトル | `member-1` | `Scout (member-1)` |
| システムプロンプト | `あなたは member-1 です` | `あなたは **Alpha** の **Scout**（member-1）です` |
| 性格・話し方 | なし | `あなたの性格・話し方: 好奇心旺盛で何でも調べたがる` |

### 影響しない箇所

内部識別子・ファイルパス・IPC プロトコルは変更されない:
- `.status/member-1.done` — 変わらない
- `member-1/task-1/result.md` — 変わらない
- `.prompts/member-1-task-1.md` — 変わらない
