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

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: 情報収集はすべて Explorer に委譲
- **ユーザーが URL を提示した場合**: Explorer の task-spec に含めて委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによるエージェント起動、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{agent}.done` の状態値のみで行う。plan.md, lifecycle.md, review.md 等の中身は読まない
- **ポーリング禁止**: Bash の sleep ループで `.done` や `.ready` ファイルを待機してはならない。エージェント完了は `[AGENT_COMPLETE]` プッシュ通知で検知する
- **テンプレートの Read 不要**: 出力フォーマットテンプレートは `tmux-agent-launch.sh` 内部で自動追記される。task-spec にはタスク説明・入出力パス・手順のみを記載する
- **自律実行**: Phase 1〜3 はユーザー確認なしで自動完了

## スクリプトパス

スクリプトはこのスキルの `references/scripts/` に配置されている（`.orchestrator/scripts/` へのコピーは不要）。

オーケストレーターは起動時に [tmux-agent-launch.sh](references/scripts/tmux-agent-launch.sh) のパスからディレクトリを取得し、`SCRIPTS_DIR` として保持する。

## 詳細手順

詳細な実行手順・IPC仕様・エージェント間パス渡しは以下を参照:

- [orchestrator.md](references/instructions/orchestrator.md) - オーケストレーターの詳細手順

## 参照ドキュメント

- [agent-catalog.md](references/agent-catalog.md) - エージェント一覧・選択ガイド
