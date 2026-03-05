---
name: tmux-orchestration
description: "tmuxセッションを使ってタスクを専門エージェントに分散し、複数のAI CLIプロセスとして並列実行するオーケストレーションワークフロー。/tmux-orchestrate コマンド実行時、「tmuxでオーケストレーション」「tmuxで並列実行」、「セッション確認」「セッション破棄」、「tmuxエージェント作成」「tmuxオーケストレーターにエージェント追加」などのリクエスト時に使用。"
disable-model-invocation: true
---

# tmux Orchestration Skill

tmuxセッションで複数のAI CLIエージェントを並列起動し、タスクを分散実行するオーケストレーションワークフロー。
セッションのライフサイクル管理、エージェント指示ファイルの作成もこのスキルで行う。

## トリガー

- `/tmux-orchestrate` コマンドが実行されたとき
- ユーザーが「tmuxでオーケストレーション」「tmuxで並列実行」と指示したとき
- ユーザーが「テスト実行して」「Lint実行して」「コミットして」「PR作って」と指示したとき
- ユーザーが「セッション確認して」「セッション状態を見せて」「セッション破棄して」と指示したとき
- ユーザーが「tmuxエージェント作成」「tmuxオーケストレーターにエージェント追加」と指示したとき

---

## ワークフロー概要

```
[Phase 0: 初期化（Launcher 委譲）] ─────────────
    |
    ├── Launcher プロンプト生成（SESSION_ID, PARENT_PANE）
    ├── tmux-agent-launch.sh で Launcher 起動
    ├── [AGENT_COMPLETE] launcher done 受信
    └── .config/ から TMUX_SESSION, PARENT_PANE, cli-assignments を取得
    |
[Phase 1: 探索・計画] ──────────────────────────
    |
    ├── explorer プロンプト生成 → tmux-agent-launch.sh で起動
    |   └── 関連ファイルを探索
    |
    ▼ ([AGENT_COMPLETE] メッセージ受信で完了検知)
    |
    ├── planner プロンプト生成 → tmux-agent-launch.sh で起動
    |   └── 探索結果を基に実装計画を作成
    |       planner 内部（ミニオーケストレーター）:
    |         1. plan-reviewer 起動 → スペシャリスト4名を並列起動 → 統合レビュー
    |         2. Approved → .done に "done" を書き出し
    |         3. Needs Revision → レビュー結果を読んで修正 → plan-reviewer 再起動（最大2回）
    |         4. Rejected → .done に "rejected" を書き出し
    |
    ▼ ([AGENT_COMPLETE] 受信 → .done の状態値で分岐: done → Phase 2 / rejected → ユーザーに報告)
    |
[Phase 2: 実装（タスクごと）] ─────────────────
    |
    ├── check-dependencies.sh でブロック解除済みタスクを取得
    ├── 各タスクについて:
    |   ├── init-task.sh でタスクディレクトリ作成
    |   ├── task-manager プロンプト生成
    |   └── tmux-agent-launch.sh で起動（独立タスクは並列）
    |
    |   task-manager 内部（Task ツールでサブエージェント実行、ペイン増加なし）:
    |     1. implementer 起動（Task ツール） → 実装
    |     2. test-runner + linter 並列起動（Task ツール） → テスト・Lint
    |     3. code-reviewer 起動（Task ツール） → レビュー
    |     4. refactorer 起動（Task ツール） → コード改善（推奨対応時）
    |     5. completed/rejected 判定 → .done に状態値を書き出し
    |     6. rejected → implementer 再起動（最大2回）
    |
    ├── [AGENT_COMPLETE] メッセージ受信で各 task-manager の完了を検知
    ├── 各 task-manager の .done の状態値を確認（completed / rejected）
    ├── 新たにブロック解除されたタスクがあれば繰り返し
    |
    ▼ (全タスク completed → 結果をユーザーに報告 ※結果ファイルは読まない)
    |
[Phase 3: 検証] ─────────────── 自動実行
    |
    ├── test-runner + linter を並列で tmux ペインに起動
    ├── .done の状態値で PASS/FAIL を確認
    ├── FAIL 時 → debugger 起動 → 再実行（最大10回）
    |
    ▼ (全 PASS → 検証結果をユーザーに報告)
    |
    ★ 自動実行停止
    |
[Phase 4: Git操作] ──────────── ユーザー指示で実行
    |
    ├── committer を tmux ペインに起動
    └── pr-creator を tmux ペインに起動
```

## 中間ファイル

tmux版ではファイルベースIPCを使用。`.orchestrator/` ディレクトリ構成:

| ディレクトリ | 内容 | 用途 |
|------------|------|------|
| `.orchestrator/` | `team-config.json` | チーム名・メンバー名設定（プロジェクト単位、任意） |
| `.config/` | `cli-assignments.json` | エージェント→CLI割り当て |
| `.status/` | `{agent}.done`, `{agent}.exit` | 完了マーカー（状態値含む）・終了コード |
| `.prompts/` | `{agent}-prompt.md` | CLIに渡すプロンプトファイル |
| `.deps/` | `tasks.json` | タスク依存グラフ |
| `{agent}/` | `result.md`, `plan.md` 等 | エージェント結果出力 |

## スクリプトパス

スクリプトはこのスキルの `references/scripts/` に配置されている（`.orchestrator/scripts/` へのコピーは不要）。

オーケストレーターは起動時に [tmux-agent-launch.sh](references/scripts/tmux-agent-launch.sh) のパスからディレクトリを取得し、`SCRIPTS_DIR` として保持する。Launcher やエージェントのプロンプト生成時に `{SCRIPTS_DIR}` プレースホルダを実パスに置換する。

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: 情報収集はすべて Explorer に委譲
- **ユーザーが URL を提示した場合**: Explorer のプロンプトに含めて委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによるエージェント起動、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{agent}.done` の状態値のみで行う。plan.md, lifecycle.md, review.md 等の中身は読まない
- **ポーリング禁止**: Bash の sleep ループで `.done` や `.ready` ファイルを待機してはならない。エージェント完了は `[AGENT_COMPLETE]` プッシュ通知で検知する
- **自律実行**: Phase 1〜3 はユーザー確認なしで自動完了

## エラーハンドリング

### エージェントがタイムアウトした場合

1. `[AGENT_COMPLETE]` メッセージが一定時間届かない
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
   ```
2. 新しいプロンプトファイルを生成（エラー情報を含める）
3. `tmux-agent-launch.sh` で再起動（`$PARENT_PANE` を第6引数に含める）

---

## 参照ドキュメント

### アーキテクチャ

- [tmux-architecture.md](references/tmux-architecture.md) - tmuxセッション構成・ペインレイアウト
- [ipc-protocol.md](references/ipc-protocol.md) - ファイルベースIPC仕様
- [session-lifecycle.md](references/session-lifecycle.md) - セッションのライフサイクル
- [dependency-resolution.md](references/dependency-resolution.md) - 依存関係解決の仕組み

### エージェント

- [agent-catalog.md](references/agent-catalog.md) - エージェント一覧・選択ガイド
- [agent-roles.md](references/agent-roles.md) - エージェントの役割定義
- [orchestrator.md](references/instructions/orchestrator.md) - オーケストレーターの詳細手順

### テンプレート

- [orchestration-launcher-prompt.md](references/templates/orchestration-launcher-prompt.md) - Launcher エージェント用プロンプトテンプレート
