# ファイルベース IPC プロトコル

tmux-orchestrator のエージェント間通信プロトコル。

## 概要

tmux-orchestrator ではエージェント間の通信にファイルシステムを使用する。
各エージェントは独立したCLIプロセスとして動作し、以下の仕組みで情報を共有する:

1. **結果ファイル**: エージェントが処理結果を所定パスに書き出す
2. **完了マーカー**: エージェントの完了を `.done` ファイルで通知
3. **判定マーカー**: 判定を出すエージェントが `.judgment` ファイルに判定値を書き出す
4. **プロンプトファイル**: 次のエージェントへの入力をプロンプトファイルに記載
5. **依存グラフ**: タスクの実行順序を `tasks.json` で管理

## ディレクトリ構成

```
.orchestrator/
├── team-config.json              # チーム名・メンバー名設定（プロジェクト単位）
│
.orchestrator/{SESSION_ID}/
├── .config/                     # ランタイム設定
│   └── cli-assignments.json     # エージェント→CLI割り当て
│
├── .status/                     # マーカーファイル（同期メカニズム）
│   ├── explorer.done            # 完了時に touch される空ファイル
│   ├── explorer.exit            # 終了コード: AGENT_EXIT_CODE={code}
│   ├── planner.done
│   ├── planner.exit
│   ├── plan-reviewer.done
│   ├── plan-reviewer.exit
│   ├── plan-reviewer.judgment   # 判定値: JUDGMENT={Approved|Needs Revision|Rejected}
│   ├── task-1-task-manager.done
│   ├── task-1-task-manager.judgment  # 判定値: JUDGMENT={completed|rejected}
│   └── ...
│
├── .prompts/                    # CLI に渡すプロンプトファイル
│   ├── explorer-prompt.md
│   ├── planner-prompt.md
│   ├── task-1-task-manager-prompt.md
│   └── ...
│
├── .deps/                       # 依存関係管理
│   └── tasks.json               # タスク依存グラフ
│
└── {agent}/                     # 結果出力ディレクトリ
    └── result.md                # 結果ファイル
```

## 通信パターン

### パターン 1: 直列パイプライン

```
Orchestrator:
  1. explorer-prompt.md を生成
  2. tmux-agent-launch.sh で explorer 起動
  3. wait-for-completion.sh で explorer.done を待機
  4. explorer/result.md のパスを planner-prompt.md に含める
  5. tmux-agent-launch.sh で planner 起動
  6. wait-for-completion.sh で planner.done を待機
```

### パターン 2: 並列実行 + バリア

```
Orchestrator:
  1. test-runner-prompt.md と linter-prompt.md を生成
  2. tmux-agent-launch.sh で両方を起動
  3. wait-for-completion.sh で test-runner.done を待機
  4. wait-for-completion.sh で linter.done を待機
  5. 両方完了後に次のフェーズへ
```

### パターン 3: 依存関係駆動

```
Orchestrator:
  1. check-dependencies.sh で実行可能タスクを取得
  2. 各タスクの task-manager を起動
  3. wait-for-completion.sh で完了を待機
  4. check-dependencies.sh で新たに実行可能になったタスクを取得
  5. 繰り返し
```

## プロンプトファイル仕様

### 構成

```markdown
# {エージェント名} エージェント指示

あなたは {エージェント名} エージェントです。

## セッション情報
- セッションパス: .orchestrator/{SESSION_ID}/
- 出力先: .orchestrator/{SESSION_ID}/{出力パス}

## タスク
{タスク内容}

## 入力ファイル
| ファイル | 内容 |
|---------|------|
| {パス} | {説明} |

## 出力フォーマット
.orchestrator/templates/{テンプレート名} を読んでフォーマットに従ってください。

## 完了条件
- {条件}
```

### 重要なルール

- **ファイル内容は含めない**: プロンプトにはパスのみ記載し、エージェントが自分で Read する
- **出力先を明記**: エージェントが結果を書き出すパスを必ず指定する
- **テンプレート参照**: フォーマットテンプレートのパスを指定する

## マーカーファイル仕様

### .done ファイル
- `tmux-agent-launch.sh` がCLIプロセスの終了を検知して自動作成
- `touch` で作成される空ファイル
- ファイルの存在のみが意味を持つ

### .exit ファイル
- フォーマット: `AGENT_EXIT_CODE={終了コード}`
- 0 = 正常終了
- それ以外 = エラー

### .judgment ファイル
- **エージェント自身が**プロセス終了前に書き出す（自動生成ではない）
- フォーマット: `JUDGMENT={判定値}`（1行のみ）
- Orchestrator / Task Manager が結果ファイルを Read せずに分岐判断するためのメカニズム

| エージェント | 判定値 |
|-------------|--------|
| Plan Reviewer | `Approved` / `Needs Revision` / `Rejected` |
| Task Manager | `completed` / `rejected` |
| Code Reviewer | `Approved` / `Approved with Suggestions` / `Request Changes` |
| Test Runner | `PASS` / `FAIL` |
| Linter | `PASS` / `FAIL` |

### リトライ時
```bash
# マーカーを削除してから再起動
rm -f .orchestrator/{SESSION_ID}/.status/{agent}.done
rm -f .orchestrator/{SESSION_ID}/.status/{agent}.exit
rm -f .orchestrator/{SESSION_ID}/.status/{agent}.judgment
```

## コンテキスト保護の原則

Orchestrator のコンテキストウィンドウ肥大化を防ぐため、以下の原則を厳守する:

1. **Orchestrator は結果ファイルを Read しない**: 分岐判断は `.judgment` ファイルのみで行う
2. **パス渡し方式**: Orchestrator は次のエージェントのプロンプトにファイルパスだけを記載する。内容は渡し先のエージェントが自分で Read する
3. **マーカーファイルは最小限**: `.judgment` ファイルは判定値の1行のみ。詳細は結果ファイルに書く

## チーム設定（team-config.json）

プロジェクトルートの `.orchestrator/team-config.json` に配置する任意の設定ファイル。
チーム名やメンバー名をカスタマイズし、tmux セッション名・ペインタイトル・プロンプトに反映する。

**ファイルが存在しない場合は全てデフォルト動作**（完全後方互換）。

### スキーマ

```json
{
  "team_name": "Alpha",
  "members": {
    "orchestrator": { "name": "Commander" },
    "explorer": { "name": "Scout" },
    "planner": { "name": "Architect" },
    "plan-reviewer": { "name": "Critic" },
    "implementer": { "name": "Builder" },
    "task-manager": { "name": "Captain" },
    "code-reviewer": { "name": "Inspector" },
    "test-runner": { "name": "Tester" },
    "linter": { "name": "Checker" },
    "security-scanner": { "name": "Guardian" },
    "debugger": { "name": "Medic" },
    "refactorer": { "name": "Polisher" },
    "committer": { "name": "Recorder" },
    "pr-creator": { "name": "Messenger" }
  }
}
```

### フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `team_name` | string \| null | No | チーム名。tmux セッション名のプレフィックスとプロンプトに使用 |
| `members` | object | No | エージェント内部識別子→表示名のマッピング |
| `members.{id}.name` | string | No | そのエージェントの表示名 |

### デフォルト動作

| 設定状態 | tmux セッション名 | ペインタイトル | プロンプト |
|---------|------------------|--------------|----------|
| ファイルなし | `orch-{SESSION_ID}` | `{agent-id}` | `あなたは {agent-id} エージェントです` |
| team_name 設定あり | `{team_name}-{SESSION_ID}` | `{member-name}` | `あなたは {team_name} の {member-name}（{agent-id}）エージェントです` |
| member 未定義 | — | `{agent-id}` | `あなたは {agent-id} エージェントです` |

### 影響範囲

表示レイヤーのみに影響。以下は一切変更されない:
- 内部識別子（explorer, planner 等）
- ファイルパス（`.status/explorer.done`, `explorer/result.md` 等）
- IPC プロトコル（`.done`, `.exit`, `.judgment`）
- Phase シーケンス

### 読み込み方法

```bash
# team-config.json からチーム名を取得（jq 使用）
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ]; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG")
fi

# エージェントの表示名を取得
get_member_name() {
  local agent_id="$1"
  if [ -f "$TEAM_CONFIG" ]; then
    local name
    name=$(jq -r ".members.\"${agent_id}\".name // empty" "$TEAM_CONFIG")
    if [ -n "$name" ]; then
      echo "$name"
      return
    fi
  fi
  echo "$agent_id"
}
```

## データフロー図

```
Explorer                    Planner                 Plan Reviewer
  │                           │                         │
  └── explorer/result.md ──→  │                         │
                              ├── planner/plan.md ───→  │
                              └── planner/tasks.md      │
                                    │                   └── plan-reviewer/review-{round}.md
                                    │
                                    ▼
                              .deps/tasks.json
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              Task Manager 1  Task Manager 2  Task Manager N
                    │               │               │
              task-1/         task-2/         task-N/
              ├── implementer/    ...             ...
              ├── code-reviewer/
              ├── test-runner/
              ├── linter/
              ├── refactorer/
              └── task-manager/lifecycle.md
```
