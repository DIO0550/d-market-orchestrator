---
name: create-tmux-agent
description: "tmuxベースのオーケストレーターフロー用指示ファイルを作成。Claude Code、GitHub Copilot、OpenAI Codex の各フォーマットに対応。14種類の指示テンプレートから必要なものを選択し、tmux実行コンテキスト付きで生成可能。「tmuxエージェント作成」「tmuxオーケストレーターにエージェント追加」などのリクエスト時に使用。"
---

# Create tmux Orchestrator Agent

tmuxベースのオーケストレーターフローで使用する指示ファイルを作成するスキル。

## ワークフロー

```
1. ターゲットCLI確認 → Claude Code / Copilot / Codex / 汎用
2. エージェント選択 → カタログから必要なものを選ぶ
3. テンプレート参照 → 個別ファイルから詳細を確認
4. CLI別の調整 → 操作名をCLI固有の形式に変換
5. 指示ファイルの生成 → 適切なディレクトリに配置
6. テンプレート・スクリプトの配置 → .orchestrator/ にコピー
```

## Step 1: ターゲット CLI 確認

まずどのCLIツール向けかを確認:

| CLI ツール | エージェント形式 | 配置先 | 実行方法 |
|-----------|----------------|--------|---------|
| Claude Code | YAML + Markdown | `.claude/instructions/` | `claude --print --prompt-file` |
| GitHub Copilot | YAML + Markdown | `.github/agents/` | `gh copilot suggest` |
| OpenAI Codex | 純粋 Markdown | `AGENTS.md` | `codex --approval-mode full-auto` |
| 汎用 CLI | Markdown | 任意 | CLI固有コマンド |

フォーマット詳細:
- [claude-code.md](references/cli-formats/claude-code.md)
- [github-copilot.md](references/cli-formats/github-copilot.md)
- [openai-codex.md](references/cli-formats/openai-codex.md)
- [generic-cli.md](references/cli-formats/generic-cli.md)

CLIツール間の能力比較: [cli-profiles.md](references/cli-profiles.md)

## Step 2: エージェント選択

[agent-catalog.md](references/agent-catalog.md) を参照し、必要なエージェントを選択。

### プリセット

| プリセット | エージェント | 用途 |
|-----------|-------------|------|
| **Minimal** | Orchestrator, Planner, Implementer | 最小限 |
| **Standard** | + Explorer, Test Runner, Linter, Committer | 一般的 |
| **Full** | 全14種類 | フル機能 |

### 個別選択

**制御**: [Orchestrator](references/instructions/orchestrator.md)

**計画**: [Explorer](references/instructions/explorer.md), [Planner](references/instructions/planner.md), [Plan Reviewer](references/instructions/plan-reviewer.md)

**実装**: [Implementer](references/instructions/implementer.md), [Task Manager](references/instructions/task-manager.md)

**検証**: [Code Reviewer](references/instructions/code-reviewer.md), [Test Runner](references/instructions/test-runner.md), [Linter](references/instructions/linter.md), [Security Scanner](references/instructions/security-scanner.md)

**修正**: [Debugger](references/instructions/debugger.md), [Refactorer](references/instructions/refactorer.md)

**Git**: [Committer](references/instructions/committer.md), [PR Creator](references/instructions/pr-creator.md)

### モデル選択

| クラス | 記号 | エージェント | 用途 |
|--------|-----|-------------|------|
| 🧠 高性能 | opus相当 | Orchestrator, Planner, Plan Reviewer, Code Reviewer, Debugger | 判断・設計・レビュー |
| ⚡ 中程度 | sonnet相当 | Explorer, Implementer, Task Manager, Refactorer, Security Scanner | 分析・コード生成 |
| 💨 軽量 | haiku相当 | Test Runner, Linter, Committer, PR Creator | 定型作業・コマンド実行 |

## Step 3: テンプレート参照

各テンプレートには以下が含まれる:
- 指示内容（フロントマター + 本文）
- tmux実行コンテキスト（ファイルベースIPCの使い方）
- 実行手順
- CLI別の注意事項
- 入出力形式
- 完了条件

## Step 4: CLI 別の調整

テンプレートの操作をターゲットCLIの形式に変換する。

詳細は [cli-profiles.md](references/cli-profiles.md) を参照:
- CLI別の起動コマンド
- プロンプト渡し方式
- 自律実行モードの設定

## Step 5: 指示ファイルの生成

### 配置先

| CLI ツール | ディレクトリ |
|-----------|-------------|
| Claude Code | `plugins/.../instructions/{name}.md` または `.claude/instructions/{name}.md` |
| Copilot | `.github/agents/{name}.agent.md` |
| Codex | `{name}/AGENTS.md` または ルート追記 |

## エージェント間の結果受け渡し

各エージェントはセッションフォルダ内の所定パスに結果を書き出す。Orchestrator はファイル内容をプロンプトに含めず、パスだけをプロンプトファイルに記載する。各エージェントが自分で Read する。

```
.orchestrator/
├── scripts/                     # tmux管理スクリプト
├── templates/                   # 共通テンプレート
├── {連番}-{feature名}/          # セッションフォルダ
│   ├── .config/                 # ランタイム設定
│   │   └── cli-assignments.json # エージェント→CLI割り当て
│   ├── .status/                 # 完了マーカー
│   │   ├── {agent}.done         # 完了時にtouch
│   │   └── {agent}.exit         # 終了コード記録
│   ├── .prompts/                # CLIに渡すプロンプトファイル
│   │   └── {agent}-prompt.md
│   ├── .deps/                   # 依存関係管理
│   │   └── tasks.json
│   ├── explorer/
│   │   └── result.md
│   ├── planner/
│   │   ├── plan.md
│   │   └── tasks.md
│   ├── plan-reviewer/
│   │   └── review-{round}.md
│   ├── task-{id}/
│   │   ├── implementer/
│   │   │   └── result-{round}.md
│   │   ├── test-runner/
│   │   │   └── result-{round}.md
│   │   ├── linter/
│   │   │   └── result-{round}.md
│   │   ├── code-reviewer/
│   │   │   └── review-{round}.md
│   │   ├── refactorer/
│   │   │   └── result-{round}.md
│   │   ├── debugger/
│   │   │   └── report-{round}.md
│   │   └── task-manager/
│   │       └── lifecycle.md
│   ├── test-runner/
│   │   └── result-{round}.md
│   ├── linter/
│   │   └── result-{round}.md
│   ├── debugger/
│   │   └── report-{round}.md
│   ├── security-scanner/
│   │   └── result.md
│   ├── committer/
│   │   └── result.md
│   └── pr-creator/
│       └── result.md
```

## Step 6: テンプレート・スクリプトの配置（必須）

エージェントはランタイムで `.orchestrator/templates/` 内のテンプレートを Read して出力フォーマットを決定する。
**このステップを省略するとエージェントが正しく動作しない。必ず全ファイルをコピーすること。**

まず出力先ディレクトリを作成:

```bash
mkdir -p .orchestrator/templates
mkdir -p .orchestrator/scripts
```

### テンプレートの配置

以下の9ファイルを **1つずつ Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [exploration-result.md](references/templates/exploration-result.md) | `.orchestrator/templates/exploration-result.md` |
| 2 | [implementation-plan.md](references/templates/implementation-plan.md) | `.orchestrator/templates/implementation-plan.md` |
| 3 | [code-review-result.md](references/templates/code-review-result.md) | `.orchestrator/templates/code-review-result.md` |
| 4 | [test-result.md](references/templates/test-result.md) | `.orchestrator/templates/test-result.md` |
| 5 | [plan-review-result.md](references/templates/plan-review-result.md) | `.orchestrator/templates/plan-review-result.md` |
| 6 | [task-lifecycle-result.md](references/templates/task-lifecycle-result.md) | `.orchestrator/templates/task-lifecycle-result.md` |
| 7 | [tasks.md](references/templates/tasks.md) | `.orchestrator/templates/tasks.md` |
| 8 | [agent-prompt.md](references/templates/agent-prompt.md) | `.orchestrator/templates/agent-prompt.md` |
| 9 | [completion-marker.md](references/templates/completion-marker.md) | `.orchestrator/templates/completion-marker.md` |

### スクリプトの配置

以下の9ファイルを **Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [tmux-session-create.sh](references/scripts/tmux-session-create.sh) | `.orchestrator/scripts/tmux-session-create.sh` |
| 2 | [tmux-session-destroy.sh](references/scripts/tmux-session-destroy.sh) | `.orchestrator/scripts/tmux-session-destroy.sh` |
| 3 | [tmux-agent-launch.sh](references/scripts/tmux-agent-launch.sh) | `.orchestrator/scripts/tmux-agent-launch.sh` |
| 4 | [tmux-status-monitor.sh](references/scripts/tmux-status-monitor.sh) | `.orchestrator/scripts/tmux-status-monitor.sh` |
| 5 | [tmux-result-collector.sh](references/scripts/tmux-result-collector.sh) | `.orchestrator/scripts/tmux-result-collector.sh` |
| 6 | [wait-for-completion.sh](references/scripts/wait-for-completion.sh) | `.orchestrator/scripts/wait-for-completion.sh` |
| 7 | [check-dependencies.sh](references/scripts/check-dependencies.sh) | `.orchestrator/scripts/check-dependencies.sh` |
| 8 | [init-session.sh](references/scripts/init-session.sh) | `.orchestrator/scripts/init-session.sh` |
| 9 | [init-task.sh](references/scripts/init-task.sh) | `.orchestrator/scripts/init-task.sh` |

コピー後、実行権限を付与:

```bash
chmod +x .orchestrator/scripts/*.sh
```

## 生成後チェックリスト

- [ ] `.orchestrator/templates/` に9ファイルが配置されている
- [ ] `.orchestrator/scripts/` に9スクリプトが配置されている
- [ ] 全スクリプトに実行権限が付与されている
- [ ] ターゲットCLIの形式に従っている
- [ ] description にトリガー条件が含まれている
- [ ] model が適切に設定されている（🧠/⚡/💨）
- [ ] tmux実行コンテキストセクションが含まれている
- [ ] CLI別の注意事項セクションが含まれている
- [ ] 入出力フォーマットが一貫している
