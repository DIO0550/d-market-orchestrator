---
name: orchestration
description: "タスクを専門エージェントに分散して並列実行するオーケストレーションワークフロー。Task ツール（サブエージェント）を使用。"
disable-model-invocation: true
---

# Orchestration Skill

タスクを専門エージェントに分散して並列実行するオーケストレーションワークフロー。

## トリガー

- ユーザーがタスクのオーケストレーション（分散・並列実行）を依頼したとき
- ユーザーが「テスト実行して」「Lint実行して」「コミットして」「PR作って」と指示したとき

## ワークフロー概要

```
[Phase 0: セッション初期化] ─────────────────────────
    │
    └── init-session.sh でセッションディレクトリを生成
    └── テンプレートを .orchestrator/templates/ にコピー
    │
[Phase 1: 探索・計画] ───────────────────────────────
    │
    ├── explorer (バックグラウンド)
    │   └── 関連ファイルを探索
    │
    ▼ (explorer 完了待ち)
    │
    ├── planner (バックグラウンド・探索結果を入力)
    │   └── 探索結果を基にタスクを分析し実装計画を作成
    │
    ▼ (planner 完了待ち)
    │
    ├── plan-reviewer (バックグラウンド・計画を入力)
    │   └── 計画の妥当性を検証（Needs Revision → planner 再起動）
    │
    ▼ (plan-reviewer 完了待ち → 計画をユーザーに提示し Phase 2 へ)
    │
[Phase 2: 実装（タスクごとにtask-manager起動）] ──────────
    │
    ├── Orchestrator が TaskList でブロック解除済みタスクを確認
    ├── ブロック解除済みタスクごとに task-manager を起動
    │   ├── Task-A (blockedBy なし) → task-manager-A ─┐
    │   └── Task-B (blockedBy なし) → task-manager-B ─┤ 並列
    │   │                                             │
    │   │ task-manager 内部:                           │
    │   │   1. implementer 起動 → 実装                │
    │   │   2. 3つのレビューエージェント並列起動      │
    │   │      (quality/logic/performance-reviewer)   │
    │   │   3. レビュー結果集約 → 最終判定            │
    │   │   4. refactorer 起動 → コード改善（推奨時） │
    │   │   5. completed/rejected 判定                 │
    │   │   6. rejected → implementer 再起動（最大2回）│
    │   │                                             │
    │   ├── task-manager-A → Task-A: completed ✅
    │   └── task-manager-B → Task-B: completed ✅
    │
    ├── 新たにブロック解除されたタスクがあれば再度 task-manager を起動
    │   └── Task-C (blockedBy [A,B]) → task-manager-C
    │
    ▼ (全タスク completed → 結果をユーザーに報告)
    │
    ★ 自動実行停止
    │
[Phase 3: 検証] ─────────────── ユーザー指示で実行
    │
    ├── test-runner (バックグラウンド)
    └── linter (バックグラウンド・並列)
    │
[Phase 4: Git操作] ────────────── ユーザー指示で実行
    │
    ├── committer (バックグラウンド)
    └── pr-creator (バックグラウンド)
```

## Phase 0: セッション初期化

オーケストレーション開始時に、セッションディレクトリとテンプレートを準備する。

### 1. セッションディレクトリの作成

[init-session.sh](references/scripts/init-session.sh) を実行してセッションフォルダを作成する：

```bash
SESSION_DIR=$(bash "$SCRIPTS_DIR/init-session.sh" "{feature-name}")
# 例: .orchestrator/0001-user-auth
```

タスク追加時は [init-task.sh](references/scripts/init-task.sh) でタスクフォルダを作成：

```bash
bash "$SCRIPTS_DIR/init-task.sh" "$SESSION_DIR" "{task-id}"
```

### 2. テンプレートの配置

エージェントはランタイムで `.orchestrator/templates/` 内のテンプレートを Read して出力フォーマットを決定する。
以下の7ファイルを **Read → Write** でコピーする：

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [exploration-result.md](references/templates/exploration-result.md) | `.orchestrator/templates/exploration-result.md` |
| 2 | [implementation-plan.md](references/templates/implementation-plan.md) | `.orchestrator/templates/implementation-plan.md` |
| 3 | [code-review-result.md](references/templates/code-review-result.md) | `.orchestrator/templates/code-review-result.md` |
| 4 | [test-result.md](references/templates/test-result.md) | `.orchestrator/templates/test-result.md` |
| 5 | [plan-review-result.md](references/templates/plan-review-result.md) | `.orchestrator/templates/plan-review-result.md` |
| 6 | [task-lifecycle-result.md](references/templates/task-lifecycle-result.md) | `.orchestrator/templates/task-lifecycle-result.md` |
| 7 | [tasks.md](references/templates/tasks.md) | `.orchestrator/templates/tasks.md` |

スクリプトも配置する：

| # | Read 対象 | Write 先 |
|---|----------|----------|
| 1 | [init-session.sh](references/scripts/init-session.sh) | `.orchestrator/scripts/init-session.sh` |
| 2 | [init-task.sh](references/scripts/init-task.sh) | `.orchestrator/scripts/init-task.sh` |

コピー後、実行権限を付与：

```bash
chmod +x .orchestrator/scripts/init-session.sh .orchestrator/scripts/init-task.sh
```

## 中間ファイル

オーケストレーションでは `.orchestrator/` ディレクトリを使用してエージェント間で情報を共有する：

| ファイル | 内容 | 作成者 |
|---------|------|-------|
| `.orchestrator/plan.md` | 実装計画 | planner |
| `.orchestrator/exploration.md` | 探索結果 | explorer |
| `.orchestrator/implementation-log.md` | 実装ログ（全タスク統合） | orchestrator |
| `.orchestrator/test-results.md` | テスト結果 | test-runner |
| `.orchestrator/lint-results.md` | Lint結果 | linter |

## エージェント起動パターン

### 並列起動（依存関係なし）

```
Phase 1: explorer → planner を直列でバックグラウンド起動（planner は探索結果を入力として受け取る）
Phase 2: blockedBy なしのタスクに対する task-manager を同時にバックグラウンド起動
Phase 3: test-runner + linter を同時にバックグラウンド起動
```

### 直列起動（依存関係あり）

```
Phase 1 内: explorer → planner（探索結果を計画に反映）
Phase 1 → Phase 2: 計画完了後に実装開始
Phase 2 内: blockedBy のあるタスクは前提タスクの完了を待って起動
Phase 3 → Phase 4: テスト成功後にコミット
Phase 4 内: コミット → PR作成
```

### Phase 2 の実装ループ（Orchestrator が制御）

```
while (pendingタスクが残っている):
  1. TaskList でブロック解除済み（blockedBy が空）の pending タスクを取得
  2. 各タスクに対して task-manager を1つずつバックグラウンド起動
     - 独立タスクは並列起動
     - task-manager が内部で implementer → 3つのレビューエージェント並列 → refactorer → 判定を管理
     - rejected 時のリトライも task-manager 内部で処理（最大2回）
  3. TaskOutput で全 task-manager の完了を待つ
  4. 新たにブロック解除されたタスクがあれば 1 に戻る
```

## Task ツールの使い方

### バックグラウンドでエージェント起動

```
Task tool:
  description: "plannerエージェント起動"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたは planner エージェントです。
    ...
```

### エージェントの完了待ち

```
TaskOutput tool:
  task_id: "{起動時に返されたtask_id}"
  block: true
  timeout: 300000  # 5分
```

## プロジェクトタイプ検出

テスト・Lintコマンドを自動検出するロジック：

```
1. package.json が存在する場合:
   - test: npm test
   - lint: npm run lint

2. Cargo.toml が存在する場合:
   - test: cargo test
   - lint: cargo clippy

3. pyproject.toml が存在する場合:
   - test: pytest
   - lint: ruff check .

4. go.mod が存在する場合:
   - test: go test ./...
   - lint: golangci-lint run
```

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: URL取得、コード検索、ファイル内容の調査など、情報収集に類する作業はすべて Explorer に委譲すること
- **ユーザーが URL（GitHub Issue、仕様書リンク等）を提示した場合**: その URL を含めて Explorer のプロンプトに渡し、Explorer に取得・分析させること。Orchestrator 自身が WebFetch や Read で内容を確認してはならない
- **Orchestrator の役割は指揮・監視・報告のみ**: エージェントの起動、進捗の監視、結果のユーザーへの報告に専念すること

## オーケストレーターの責務

1. **タスク受付**: ユーザーからの要求を受け取る
2. **タスク管理**: Plannerが登録したタスクの依存関係（blocks/blockedBy）を監視し、実行順序を制御する
3. **エージェント起動**: ブロック解除済みタスクに対して適切なエージェントを起動
4. **進捗監視**: バックグラウンドエージェントの出力を監視し、タスク完了時に次のブロック解除を確認
5. **結果統合**: 各エージェントの結果を統合してユーザーに報告
6. **エラーハンドリング**: 失敗時のリトライや代替処理の提案

## エラーハンドリング

### エージェントがタイムアウトした場合

1. TaskOutput で timeout エラーを検出
2. ユーザーに状況を報告
3. 「継続して待つ」「中断する」の選択肢を提示

### エージェントがエラーで終了した場合

1. エラー内容を確認
2. ユーザーにエラー内容を報告
3. 可能であれば修正方法を提案
4. 「リトライする」「手動で修正する」の選択肢を提示

### テストやLintが失敗した場合

1. 失敗内容をユーザーに報告
2. 「implementerで修正する」「手動で修正する」の選択肢を提示
