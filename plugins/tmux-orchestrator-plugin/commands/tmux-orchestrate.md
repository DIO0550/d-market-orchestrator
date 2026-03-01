# /tmux-orchestrate コマンド

tmuxセッションを使って複数のAI CLIエージェントを並列起動し、タスクを遂行する。

## 使用方法

```
/tmux-orchestrate "タスクの説明"
```

## 実行フロー

**自律実行モード**: Phase 1〜2 はユーザー確認なしで自動完了する。ユーザーへの確認が必要な場合は Question 系ツールのみ使用し、それ以外では中断しない。

### 自動実行フェーズ（Phase 0-2）

このコマンドは以下のフェーズを自動で実行し、実装完了後に停止する：

0. **Phase 0: tmuxセッション初期化**
   - `.orchestrator/` 内の `????-*` パターンをスキャンし最大連番を取得
   - セッションフォルダを作成: `.orchestrator/{連番+1}-{feature名}/`
   - `init-session.sh` でディレクトリ構造を初期化
   - `.orchestrator/team-config.json` が存在すればチーム名・メンバー名を読み込み
   - `tmux-session-create.sh` でtmuxセッションを作成（チーム名があればセッション名に反映）
   - `cli-assignments.json` をデフォルト設定で作成

1. **Phase 1: 探索・計画・レビュー**
   - Explorer のプロンプトファイルを `.prompts/explorer-prompt.md` に生成
   - `tmux-agent-launch.sh` で Explorer を phase1 ウィンドウに起動
   - `wait-for-notification.sh` で完了を待機
   - Planner のプロンプトファイルを生成（Explorer結果パスを含む）
   - `tmux-agent-launch.sh` で Planner を起動、完了を待機
   - Plan Reviewer（Lead）のプロンプトファイルを生成
   - `tmux-agent-launch.sh` で Plan Reviewer を起動（内部で4スペシャリストを並列起動）、完了を待機
   - `.status/plan-reviewer.done` の状態値を確認し分岐:
     - `Approved` → Phase 2 に進む
     - `Needs Revision` → Planner を再起動（最大2回）
     - `Rejected` → ユーザーに報告

2. **Phase 2: 実装（タスクごとにtask-managerを起動）**
   - `check-dependencies.sh` でブロック解除済みタスクを取得
   - 各タスクについて:
     - `init-task.sh` でタスクディレクトリ作成
     - Task Manager のプロンプトファイルを生成
     - `tmux-agent-launch.sh` で phase2 ウィンドウに起動（独立タスクは並列）
   - Task Manager が内部で implementer → test-runner + linter → code-reviewer → refactorer → 完了判定を管理
   - `wait-for-notification.sh` で全 Task Manager の完了を待機
   - 各 Task Manager の `.status/task-{id}-task-manager.done` の状態値を確認
   - 新たにブロック解除されたタスクがあれば繰り返し
   - 全タスク完了後、`tmux-result-collector.sh` で結果を集約
   - 結果をユーザーに報告（Orchestrator は結果ファイルを読まず、.done の状態値のみで報告）
   - **ここで自動実行は停止**

### ユーザー指示フェーズ（Phase 3-4）

以下のフェーズはユーザーの指示で実行：

3. **Phase 3: 検証** - 「テスト実行して」「Lint実行して」
4. **Phase 4: Git操作** - 「コミットして」「PR作って」

## オーケストレーターの実行手順

### Step 1: Phase 0 - tmuxセッション初期化

```bash
# セッション連番の取得
NEXT_ID=$(printf "%04d" $(($(ls -d .orchestrator/????-* 2>/dev/null | sed 's/.*\///' | cut -d'-' -f1 | sort -n | tail -1 || echo 0) + 1)))

# feature名の生成
FEATURE_NAME="{タスクから生成した英小文字ハイフン区切り名}"
SESSION_ID="${NEXT_ID}-${FEATURE_NAME}"

# ディレクトリ初期化
bash "$SCRIPTS_DIR/init-session.sh" ".orchestrator/${SESSION_ID}"

# チーム設定の読み込み（存在する場合）
TEAM_CONFIG=".orchestrator/team-config.json"
if [ -f "$TEAM_CONFIG" ]; then
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG")
fi

# tmuxセッション作成（チーム名があればセッション名プレフィックスに反映）
bash "$SCRIPTS_DIR/tmux-session-create.sh" "orch-${SESSION_ID}"

# CLI割り当て設定（デフォルト）
# .orchestrator/${SESSION_ID}/.config/cli-assignments.json に書き出す
```

### Step 2: Phase 1 - 探索（Explorer）

```
1. Explorer のプロンプトファイルを生成:
   .orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md

2. tmux ペインで起動:
   bash "$SCRIPTS_DIR/tmux-agent-launch.sh" \
     "orch-{SESSION_ID}" "phase1" "explorer" "claude" \
     ".orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md" \
     ".orchestrator/{SESSION_ID}"

3. 完了通知を待機:
   bash "$SCRIPTS_DIR/wait-for-notification.sh" \
     ".orchestrator/{SESSION_ID}" "explorer" "orch-{SESSION_ID}" 600
```

### Step 3: Phase 1 - 計画（Planner）

Explorer 完了後、Planner を起動:

```
1. Planner のプロンプトファイルを生成
   （Explorer結果パスを含める: .orchestrator/{SESSION_ID}/explorer/result.md）

2. tmux ペインで起動・完了待機（同上パターン）
```

### Step 4: Phase 1 - レビュー（Plan Reviewer）

```
1. Plan Reviewer のプロンプトファイルを生成
2. tmux ペインで起動・完了待機
3. .status/plan-reviewer.done の状態値を読んで分岐:
   STATUS=$(cat ".orchestrator/{SESSION_ID}/.status/plan-reviewer.done")
   a. "Approved" → Step 5 へ
   b. "Needs Revision" → マーカー削除 → Planner 再起動（最大2回）→ Plan Reviewer 再実行
   c. "Rejected" → ユーザーに報告
```

**重要**: Orchestrator は `plan-reviewer/review-{round}.md` を Read しない。判定は `.done` ファイルの状態値のみで行う。

### Step 5: Phase 2 - 実装ループ

```
while (pendingタスクが残っている):
  1. check-dependencies.sh で実行可能タスクを取得
  2. 各タスクについて:
     a. init-task.sh でディレクトリ作成
     b. Task Manager のプロンプト生成
     c. tmux-agent-launch.sh で起動
  3. wait-for-notification.sh で全 Task Manager の完了を待機
  4. 各 .status/task-{id}-task-manager.done の状態値を確認（completed / rejected）
  5. tasks.json のステータスを更新
  6. 新たに実行可能なタスクがあれば 1 に戻る
```

**重要**: Orchestrator は `task-manager/lifecycle.md` を Read しない。タスクの成否は `.done` ファイルの状態値のみで判断する。

### Step 6: Phase 2 完了・報告

```
1. tmux-result-collector.sh で結果を集約
2. 実装結果をユーザーに報告
3. 自動実行を停止
```

### Step 7: 次のステップの案内

ユーザーに以下の選択肢を提示：
- 「テストとLint実行して」→ Phase 3
- 「コミットして」→ Phase 4
- 「PR作って」→ Phase 4

## 後続フェーズの実行（ユーザー指示時）

### 「テスト実行して」「Lint実行して」への応答

プロジェクトタイプを自動検出してコマンドを決定：
- package.json → `npm test`, `npm run lint`
- Cargo.toml → `cargo test`, `cargo clippy`
- pyproject.toml → `pytest`, `ruff check`
- go.mod → `go test ./...`, `golangci-lint run`

test-runner と linter のプロンプトを生成し、phase3 ウィンドウで並列起動。

### 「コミットして」への応答

committer のプロンプトを生成し、phase4 ウィンドウで起動。

### 「PR作って」への応答

pr-creator のプロンプトを生成し、phase4 ウィンドウで起動。

## エラーハンドリング

- **tmuxが未インストール**: インストール手順を案内
- **CLIツールが未インストール**: 指定されたCLIの代わりにデフォルト（claude）にフォールバック
- **エージェントがタイムアウト**: ユーザーに報告し「継続」「中断」を選択
- **エージェントがエラー**: エラー内容を報告し「リトライ」「手動修正」を選択
- **計画がRejected**: ユーザーに報告し代替案を提案
