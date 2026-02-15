---
name: tmux-orchestration
description: "tmuxセッションを使ってタスクを専門エージェントに分散し、複数のAI CLIプロセスとして並列実行するオーケストレーションワークフロー。/tmux-orchestrate コマンド実行時、または「tmuxでオーケストレーション」「tmuxで並列実行」などのリクエスト時に使用。"
---

# tmux Orchestration Skill

tmuxセッションで複数のAI CLIエージェントを並列起動し、タスクを分散実行するオーケストレーションワークフロー。

## トリガー

- `/tmux-orchestrate` コマンドが実行されたとき
- ユーザーが「tmuxでオーケストレーション」「tmuxで並列実行」と指示したとき
- ユーザーが「テスト実行して」「Lint実行して」「コミットして」「PR作って」と指示したとき

## ワークフロー概要

```
[Phase 0: 初期化] ──────────────────────────────
    │
    ├── tmuxセッション作成（tmux-session-create.sh）
    ├── セッションディレクトリ初期化（init-session.sh）
    └── CLI割り当て設定（cli-assignments.json）
    │
[Phase 1: 探索・計画] ──────────────────────────
    │
    ├── explorer プロンプト生成 → tmux-agent-launch.sh で起動
    │   └── 関連ファイルを探索
    │
    ▼ (wait-for-completion.sh で完了待ち)
    │
    ├── planner プロンプト生成 → tmux-agent-launch.sh で起動
    │   └── 探索結果を基に実装計画を作成
    │
    ▼ (wait-for-completion.sh で完了待ち)
    │
    ├── plan-reviewer プロンプト生成 → tmux-agent-launch.sh で起動
    │   └── 計画の妥当性を検証 → .judgment に判定値を書き出し
    │
    ▼ (完了待ち → .judgment で分岐: Approved → Phase 2 / Needs Revision → planner 再起動)
    │
[Phase 2: 実装（タスクごと）] ─────────────────
    │
    ├── check-dependencies.sh でブロック解除済みタスクを取得
    ├── 各タスクについて:
    │   ├── init-task.sh でタスクディレクトリ作成
    │   ├── task-manager プロンプト生成
    │   └── tmux-agent-launch.sh で起動（独立タスクは並列）
    │
    │   task-manager 内部（CLIがペインでのエージェント管理に対応する場合）:
    │     1. implementer 起動 → 実装
    │     2. test-runner + linter 起動 → テスト・Lint
    │     3. code-reviewer 起動 → レビュー
    │     4. refactorer 起動 → コード改善（推奨対応時）
    │     5. completed/rejected 判定 → .judgment に書き出し
    │     6. rejected → implementer 再起動（最大2回）
    │
    ├── wait-for-completion.sh で全 task-manager の完了待ち
    ├── 各 task-manager の .judgment を確認（completed / rejected）
    ├── 新たにブロック解除されたタスクがあれば繰り返し
    │
    ▼ (全タスク completed → 結果をユーザーに報告 ※結果ファイルは読まない)
    │
    ★ 自動実行停止
    │
[Phase 3: 検証] ─────────────── ユーザー指示で実行
    │
    ├── test-runner + linter を並列で tmux ペインに起動
    ├── .judgment で PASS/FAIL を確認
    ├── FAIL 時 → debugger 起動 → 再実行（最大10回）
    │
[Phase 4: Git操作] ──────────── ユーザー指示で実行
    │
    ├── committer を tmux ペインに起動
    └── pr-creator を tmux ペインに起動
```

## 中間ファイル

tmux版ではファイルベースIPCを使用。`.orchestrator/` ディレクトリ構成:

| ディレクトリ | 内容 | 用途 |
|------------|------|------|
| `.config/` | `cli-assignments.json` | エージェント→CLI割り当て |
| `.status/` | `{agent}.done`, `{agent}.exit`, `{agent}.judgment` | 完了マーカー・終了コード・判定値 |
| `.prompts/` | `{agent}-prompt.md` | CLIに渡すプロンプトファイル |
| `.deps/` | `tasks.json` | タスク依存グラフ |
| `{agent}/` | `result.md`, `plan.md` 等 | エージェント結果出力 |

## エージェント起動パターン

### tmux ペインでの起動

```bash
# 1. プロンプトファイルを生成
# .orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md に書き出す

# 2. tmux ペインでエージェント起動
bash .orchestrator/scripts/tmux-agent-launch.sh \
  "orch-{SESSION_ID}" "phase1" "explorer" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md" \
  ".orchestrator/{SESSION_ID}"

# 3. 完了を待機
bash .orchestrator/scripts/wait-for-completion.sh \
  ".orchestrator/{SESSION_ID}" "explorer" 600
```

### 並列起動（依存関係なし）

```bash
# test-runner と linter を同時起動
bash .orchestrator/scripts/tmux-agent-launch.sh \
  "orch-{SESSION_ID}" "phase3" "test-runner" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/test-runner-prompt.md" \
  ".orchestrator/{SESSION_ID}"

bash .orchestrator/scripts/tmux-agent-launch.sh \
  "orch-{SESSION_ID}" "phase3" "linter" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/linter-prompt.md" \
  ".orchestrator/{SESSION_ID}"

# 両方の完了を待機
bash .orchestrator/scripts/wait-for-completion.sh \
  ".orchestrator/{SESSION_ID}" "test-runner" 300
bash .orchestrator/scripts/wait-for-completion.sh \
  ".orchestrator/{SESSION_ID}" "linter" 300
```

### 依存関係のあるタスク起動

```bash
# 実行可能なタスクを取得
READY_TASKS=$(bash .orchestrator/scripts/check-dependencies.sh \
  ".orchestrator/{SESSION_ID}")

# 各タスクを起動
for TASK_ID in $READY_TASKS; do
  bash .orchestrator/scripts/init-task.sh \
    ".orchestrator/{SESSION_ID}" "$TASK_ID"

  # プロンプト生成してtmux起動
  bash .orchestrator/scripts/tmux-agent-launch.sh \
    "orch-{SESSION_ID}" "phase2" "task-${TASK_ID}-task-manager" "claude" \
    ".orchestrator/{SESSION_ID}/.prompts/task-${TASK_ID}-task-manager-prompt.md" \
    ".orchestrator/{SESSION_ID}"
done
```

## プロジェクトタイプ検出

テスト・Lintコマンドを自動検出:

| 検出ファイル | テストコマンド | Lintコマンド |
|-------------|-------------|-------------|
| package.json | `npm test` | `npm run lint` |
| Cargo.toml | `cargo test` | `cargo clippy` |
| pyproject.toml | `pytest` | `ruff check .` |
| go.mod | `go test ./...` | `golangci-lint run` |

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: 情報収集はすべて Explorer に委譲
- **ユーザーが URL を提示した場合**: Explorer のプロンプトに含めて委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによるエージェント起動、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{agent}.judgment` ファイルのみで行う。plan.md, lifecycle.md, review.md 等の中身は読まない
- **自律実行**: Phase 1〜2 はユーザー確認なしで自動完了

## エラーハンドリング

### エージェントがタイムアウトした場合

1. `wait-for-completion.sh` が終了コード 1 を返す
2. ユーザーに状況を報告
3. 「継続して待つ」「中断する」の選択肢を提示

### エージェントがエラーで終了した場合

1. `.exit` ファイルの終了コードを確認
2. ユーザーにエラー内容を報告
3. 「リトライする」「手動で修正する」の選択肢を提示

### リトライ時の手順

1. 既存のマーカーファイルを削除:
   ```bash
   rm -f .orchestrator/{SESSION_ID}/.status/{agent}.done
   rm -f .orchestrator/{SESSION_ID}/.status/{agent}.exit
   rm -f .orchestrator/{SESSION_ID}/.status/{agent}.judgment
   ```
2. 新しいプロンプトファイルを生成（エラー情報を含める）
3. `tmux-agent-launch.sh` で再起動

## 参照ドキュメント

- [agent-roles.md](references/agent-roles.md) - エージェントの役割定義
- [tmux-architecture.md](references/tmux-architecture.md) - tmuxセッション構成の詳細
- [ipc-protocol.md](references/ipc-protocol.md) - ファイルベースIPC仕様
- [dependency-resolution.md](references/dependency-resolution.md) - 依存関係解決の仕組み
