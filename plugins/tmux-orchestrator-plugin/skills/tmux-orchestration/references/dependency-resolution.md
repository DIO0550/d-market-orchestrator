# 依存関係解決

tmux-orchestrator のタスク依存関係管理と実行順序制御の仕組み。

## 依存グラフ

Planner がタスクを作成する際に、依存関係を `tasks.json` に記録する。

### tasks.json フォーマット

```json
{
  "tasks": [
    {
      "id": "1",
      "subject": "APIエンドポイント作成",
      "status": "pending",
      "blockedBy": [],
      "cli": "claude"
    },
    {
      "id": "2",
      "subject": "サービス層実装",
      "status": "pending",
      "blockedBy": [],
      "cli": "claude"
    },
    {
      "id": "3",
      "subject": "統合テスト作成",
      "status": "pending",
      "blockedBy": ["1", "2"],
      "cli": "codex"
    }
  ]
}
```

### フィールド説明

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | string | タスク識別子 |
| subject | string | タスクの件名 |
| status | string | `pending` / `in_progress` / `completed` / `failed` |
| blockedBy | string[] | このタスクの前提となるタスクIDの配列 |
| cli | string | 使用するCLIツール（cli-assignments.json のデフォルトを上書き） |

## 解決アルゴリズム

`check-dependencies.sh` は以下のロジックで実行可能タスクを判定:

```
for each task in tasks.json:
  if task.status != "pending":
    skip  # 完了済み・実行中のタスクは対象外

  all_done = true
  for each blocker_id in task.blockedBy:
    if not exists(.status/task-{blocker_id}-task-manager.done):
      all_done = false
      break

  if all_done:
    output task.id  # 実行可能
```

## 実行フロー

### 1. 初期状態

```
Task 1 (blockedBy: [])    → 実行可能 ✅
Task 2 (blockedBy: [])    → 実行可能 ✅
Task 3 (blockedBy: [1,2]) → ブロック中 ❌
```

### 2. Task 1, 2 を並列起動

```bash
# check-dependencies.sh → "1" "2" を出力
for TASK_ID in 1 2; do
  bash init-task.sh ".orchestrator/{SESSION_ID}" "$TASK_ID"
  # プロンプト生成 & tmux起動
done
```

### 3. Task 1 完了

```
.status/task-1-task-manager.done が作成される
tasks.json: Task 1 → "completed"

Task 3 (blockedBy: [1,2]) → Task 2 がまだ → ブロック中 ❌
```

### 4. Task 2 完了

```
.status/task-2-task-manager.done が作成される
tasks.json: Task 2 → "completed"

Task 3 (blockedBy: [1,2]) → 両方完了 → 実行可能 ✅
```

### 5. Task 3 を起動

```bash
# check-dependencies.sh → "3" を出力
bash init-task.sh ".orchestrator/{SESSION_ID}" "3"
# プロンプト生成 & tmux起動
```

## ステータス更新

Orchestrator がタスクの完了を検知したら `tasks.json` のステータスを更新する:

```bash
# jq でステータスを更新
jq --arg id "$TASK_ID" --arg status "completed" \
  '(.tasks[] | select(.id == $id)).status = $status' \
  "$TASKS_FILE" > "${TASKS_FILE}.tmp" && \
  mv "${TASKS_FILE}.tmp" "$TASKS_FILE"
```

## エッジケース

### 循環依存

- Planner が循環依存を作らないようにする責務
- `check-dependencies.sh` は循環を検出しない（無限ループになる）
- Plan Reviewer が循環依存をチェックして指摘すべき

### 全タスクがブロック中

- `check-dependencies.sh` が何も出力しない
- Orchestrator はエラーとして報告
- 考えられる原因: 循環依存、または前提タスクの失敗

### タスクの失敗

- 失敗したタスクの `.done` は作成される（終了コードが非0）
- 後続タスクはブロック解除される
- Orchestrator が `.exit` を確認し、失敗を検知して対応を判断
