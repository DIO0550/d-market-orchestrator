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

## チーム設定との連携

`team-config.json` を使用する場合、メンバーキーは `member-1`, `member-2`, ... を使用:

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
