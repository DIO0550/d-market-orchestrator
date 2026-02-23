---
name: tmux-orchestrator-setup
description: "tmux オーケストレーション環境のセットアップ。テンプレート・スクリプトを .orchestrator/ に配置する。「tmuxセットアップ」「tmuxオーケストレーターをセットアップ」「オーケストレーション環境を初期化」などのリクエスト時に使用。"
---

# tmux Orchestrator Setup

tmux オーケストレーションに必要なテンプレートとスクリプトを `.orchestrator/` に配置するセットアップスキル。

## トリガー

- `/tmux-setup` コマンドが実行されたとき
- ユーザーが「tmuxセットアップ」「tmuxオーケストレーターをセットアップ」と指示したとき
- ユーザーが「オーケストレーション環境を初期化」と指示したとき

---

## セットアップ手順

### Step 1: 既存環境の確認

`.orchestrator/` ディレクトリが既に存在するか確認する。

- **存在しない場合**: Step 2 に進む
- **存在する場合**: テンプレート・スクリプトの上書き確認をユーザーに行う

### Step 2: ディレクトリ作成

```bash
mkdir -p .orchestrator/templates
mkdir -p .orchestrator/scripts
```

### Step 3: テンプレートの配置

以下の 11 ファイルを **1つずつ Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [exploration-result.md](../tmux-orchestration/references/templates/exploration-result.md) | `.orchestrator/templates/exploration-result.md` |
| 2 | [implementation-plan.md](../tmux-orchestration/references/templates/implementation-plan.md) | `.orchestrator/templates/implementation-plan.md` |
| 3 | [code-review-result.md](../tmux-orchestration/references/templates/code-review-result.md) | `.orchestrator/templates/code-review-result.md` |
| 4 | [specialist-review-result.md](../tmux-orchestration/references/templates/specialist-review-result.md) | `.orchestrator/templates/specialist-review-result.md` |
| 5 | [plan-specialist-review-result.md](../tmux-orchestration/references/templates/plan-specialist-review-result.md) | `.orchestrator/templates/plan-specialist-review-result.md` |
| 6 | [test-result.md](../tmux-orchestration/references/templates/test-result.md) | `.orchestrator/templates/test-result.md` |
| 7 | [plan-review-result.md](../tmux-orchestration/references/templates/plan-review-result.md) | `.orchestrator/templates/plan-review-result.md` |
| 8 | [task-lifecycle-result.md](../tmux-orchestration/references/templates/task-lifecycle-result.md) | `.orchestrator/templates/task-lifecycle-result.md` |
| 9 | [tasks.md](../tmux-orchestration/references/templates/tasks.md) | `.orchestrator/templates/tasks.md` |
| 10 | [agent-prompt.md](../tmux-orchestration/references/templates/agent-prompt.md) | `.orchestrator/templates/agent-prompt.md` |
| 11 | [completion-marker.md](../tmux-orchestration/references/templates/completion-marker.md) | `.orchestrator/templates/completion-marker.md` |

### Step 4: スクリプトの配置

以下の 9 ファイルを **Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [tmux-session-create.sh](../tmux-orchestration/references/scripts/tmux-session-create.sh) | `.orchestrator/scripts/tmux-session-create.sh` |
| 2 | [tmux-session-destroy.sh](../tmux-orchestration/references/scripts/tmux-session-destroy.sh) | `.orchestrator/scripts/tmux-session-destroy.sh` |
| 3 | [tmux-agent-launch.sh](../tmux-orchestration/references/scripts/tmux-agent-launch.sh) | `.orchestrator/scripts/tmux-agent-launch.sh` |
| 4 | [tmux-status-monitor.sh](../tmux-orchestration/references/scripts/tmux-status-monitor.sh) | `.orchestrator/scripts/tmux-status-monitor.sh` |
| 5 | [tmux-result-collector.sh](../tmux-orchestration/references/scripts/tmux-result-collector.sh) | `.orchestrator/scripts/tmux-result-collector.sh` |
| 6 | [notify-parent.sh](../tmux-orchestration/references/scripts/notify-parent.sh) | `.orchestrator/scripts/notify-parent.sh` |
| 7 | [check-dependencies.sh](../tmux-orchestration/references/scripts/check-dependencies.sh) | `.orchestrator/scripts/check-dependencies.sh` |
| 8 | [init-session.sh](../tmux-orchestration/references/scripts/init-session.sh) | `.orchestrator/scripts/init-session.sh` |
| 9 | [init-task.sh](../tmux-orchestration/references/scripts/init-task.sh) | `.orchestrator/scripts/init-task.sh` |

コピー後、実行権限を付与:

```bash
chmod +x .orchestrator/scripts/*.sh
```

### Step 5: 完了確認

以下のチェックリストを確認して結果を報告:

- [ ] `.orchestrator/templates/` に 11 ファイルが配置されている
- [ ] `.orchestrator/scripts/` に 9 スクリプトが配置されている
- [ ] 全スクリプトに実行権限が付与されている

完了後、以下を案内:

```
セットアップが完了しました。

次のステップ:
  /tmux-config   — CLI割り当てやチーム設定をカスタマイズ
  /tmux-orchestrate "タスクの説明" — オーケストレーションを開始
```
