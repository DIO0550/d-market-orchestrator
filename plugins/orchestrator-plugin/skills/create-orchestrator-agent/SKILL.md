---
name: create-orchestrator-agent
description: "オーケストレーターフロー用のエージェント定義ファイルを作成。Claude Code、GitHub Copilot、OpenAI Codex の各フォーマットに対応。13種類のエージェントテンプレートから必要なものだけを選択して作成可能。ツール非依存の汎用的な指示形式。「エージェント作成」「オーケストレーターにエージェント追加」などのリクエスト時に使用。"
---

# Create Orchestrator Agent

オーケストレーターフローで使用するエージェント定義ファイルを作成するスキル。

## ワークフロー

```
1. ターゲットツール確認 → Claude Code / Copilot / Codex
2. エージェント選択 → カタログから必要なものを選ぶ
2.5 & 5. 分析 → 生成（種別ごとの analyzer/generator ペアを並列起動）
  Phase A: {種別}-analyzer × N を並列起動 → 各プロファイル取得
  Phase B: {種別}-generator × N を並列起動 → プロジェクト固有エージェント生成
6. テンプレートの配置 → .orchestrator/templates/ にコピー
```

## Step 1: ターゲットツール確認

まずどのツール向けかを確認:

| ツール | 形式 | 配置先 | サブエージェント呼び出し |
|--------|------|--------|------------------------|
| Claude Code | YAML + Markdown | `.claude/agents/` | `Task` ツール |
| GitHub Copilot | YAML + Markdown | `.github/agents/` | `#tool:agent/runSubagent` (agentName指定) |
| OpenAI Codex | 純粋 Markdown | `AGENTS.md` | 別ファイル参照 |

フォーマット詳細:
- [claude-code-format.md](references/claude-code-format.md)
- [copilot-format.md](references/copilot-format.md)
- [codex-format.md](references/codex-format.md)

## Step 2: エージェント選択

[agent-catalog.md](references/agent-catalog.md) を参照し、必要なエージェントを選択。

### プリセット

| プリセット | エージェント | 用途 |
|-----------|-------------|------|
| **Minimal** | Orchestrator, Planner, Implementer | 最小限 |
| **Standard** | + Explorer, Test Runner, Linter, Committer | 一般的 |
| **Full** | 全14種類 | フル機能 |

### 個別選択

**制御**: [Orchestrator](references/agents/orchestrator.md), [Orchestrator Copilot版](references/agents/orchestrator-copilot.md)

**計画**: [Explorer](references/agents/explorer.md), [Planner](references/agents/planner.md), [Plan Reviewer](references/agents/plan-reviewer.md)

**実装**: [Implementer](references/agents/implementer.md), [Task Manager](references/agents/task-manager.md), [Task Manager Copilot版](references/agents/task-manager-copilot.md)

**検証**: [Code Reviewer](references/agents/code-reviewer.md), [Test Runner](references/agents/test-runner.md), [Linter](references/agents/linter.md), [Security Scanner](references/agents/security-scanner.md)

**修正**: [Debugger](references/agents/debugger.md), [Refactorer](references/agents/refactorer.md)

**Git**: [Committer](references/agents/committer.md), [PR Creator](references/agents/pr-creator.md)

### モデル選択

各エージェントには推奨モデルが設定されている:

| クラス | 記号 | エージェント | 用途 |
|--------|-----|-------------|------|
| 🧠 高性能 | opus相当 | Orchestrator, Planner, Plan Reviewer, Code Reviewer, Debugger | 判断・設計・レビュー |
| ⚡ 中程度 | sonnet相当 | Explorer, Implementer, Refactorer, Security Scanner | 分析・コード生成 |
| 💨 軽量 | haiku相当 | Test Runner, Linter, Committer, PR Creator | 定型作業・コマンド実行 |

詳細は [agent-catalog.md](references/agent-catalog.md) の「モデル選択ガイド」を参照。

## Step 2.5 & Step 5: プロジェクト分析 → エージェント定義の生成（analyzer/generator ペア並列起動）

Step 2 で選択した各エージェント種別に対し、**専用の analyzer → generator ペア**をバックグラウンドで並列起動する。

### アーキテクチャ

```
選択した各エージェント種別に対して並列実行:

  {種別}-analyzer → プロファイル出力
       ↓
  {種別}-generator → プロジェクト固有のエージェント定義を生成
```

各 analyzer/generator は `agents/analyzers/` および `agents/generators/` に配置されている。

### エージェント一覧

| 種別 | Analyzer | Generator |
|------|----------|-----------|
| Orchestrator | `analyzers/orchestrator-analyzer.md` | `generators/orchestrator-generator.md` |
| Explorer | `analyzers/explorer-analyzer.md` | `generators/explorer-generator.md` |
| Planner | `analyzers/planner-analyzer.md` | `generators/planner-generator.md` |
| Plan Reviewer | `analyzers/plan-reviewer-analyzer.md` | `generators/plan-reviewer-generator.md` |
| Task Manager | `analyzers/task-manager-analyzer.md` | `generators/task-manager-generator.md` |
| Implementer | `analyzers/implementer-analyzer.md` | `generators/implementer-generator.md` |
| Code Reviewer | `analyzers/code-reviewer-analyzer.md` | `generators/code-reviewer-generator.md` |
| Test Runner | `analyzers/test-runner-analyzer.md` | `generators/test-runner-generator.md` |
| Linter | `analyzers/linter-analyzer.md` | `generators/linter-generator.md` |
| Security Scanner | `analyzers/security-scanner-analyzer.md` | `generators/security-scanner-generator.md` |
| Debugger | `analyzers/debugger-analyzer.md` | `generators/debugger-generator.md` |
| Refactorer | `analyzers/refactorer-analyzer.md` | `generators/refactorer-generator.md` |
| Committer | `analyzers/committer-analyzer.md` | `generators/committer-generator.md` |
| PR Creator | `analyzers/pr-creator-analyzer.md` | `generators/pr-creator-generator.md` |

### 起動手順

Step 2 で選択した各エージェント種別に対し、以下を並列実行する:

#### Phase A: Analyzer 並列起動

選択した全種別の analyzer をバックグラウンドで同時起動する。

```yaml
# 各種別に対して並列起動
サブエージェント起動:
  エージェント: {種別}-analyzer  # 例: test-runner-analyzer
  バックグラウンド: true
  プロンプト: |
    対象プロジェクトを分析し、{種別} エージェント生成に必要なプロファイルを出力してください。
```

全 analyzer の完了を待ち、各プロファイルを取得する。

#### Phase B: Generator 並列起動

全 analyzer の完了後、各種別の generator をバックグラウンドで同時起動する。

```yaml
# 各種別に対して並列起動
サブエージェント起動:
  エージェント: {種別}-generator  # 例: test-runner-generator
  バックグラウンド: true
  プロンプト: |
    ## Analyzer プロファイル
    {Phase A で取得した該当種別のプロファイル全文}

    ## テンプレートパス
    references/agents/{種別}.md

    ## ターゲットツール
    {Claude Code / GitHub Copilot / OpenAI Codex}

    ## 出力先
    {配置先ディレクトリ}/{種別}.md

    ## ツール変換ルール
    tool-mapping.md のパス: references/tool-mapping.md
```

全 generator の完了を待つ。

### 配置先

| ツール | ディレクトリ |
|--------|-------------|
| Claude Code | `plugins/.../agents/{name}.md` または `.claude/agents/{name}.md` |
| Copilot | `.github/agents/{name}.agent.md` |
| Codex | `{name}/AGENTS.md` または ルート追記 |

### 並列起動の例

Step 2 で Standard プリセット（7エージェント）を選択した場合:

```
Phase A: analyzer × 7 を同時にバックグラウンド起動
  - orchestrator-analyzer
  - explorer-analyzer
  - planner-analyzer
  - implementer-analyzer
  - test-runner-analyzer
  - linter-analyzer
  - committer-analyzer
→ 全 analyzer の完了を待つ

Phase B: generator × 7 を同時にバックグラウンド起動
  - orchestrator-generator（orchestrator-analyzer のプロファイル + テンプレート）
  - explorer-generator（explorer-analyzer のプロファイル + テンプレート）
  - planner-generator（planner-analyzer のプロファイル + テンプレート）
  - implementer-generator（implementer-analyzer のプロファイル + テンプレート）
  - test-runner-generator（test-runner-analyzer のプロファイル + テンプレート）
  - linter-generator（linter-analyzer のプロファイル + テンプレート）
  - committer-generator（committer-analyzer のプロファイル + テンプレート）
→ 全 generator の完了を待つ
```

### テンプレートの位置づけ

**テンプレート（`references/agents/*.md`）は出力そのものではなく、構造のリファレンスである。**

各 generator はテンプレートを Read して構造・必須セクションを把握した上で、analyzer のプロファイルに基づいてプロジェクト固有のエージェント定義を生成する。テンプレートをそのままコピーしてはならない。

### ツール別の調整

[tool-mapping.md](references/tool-mapping.md) の変換ルールは各 generator が自分で参照する:
- 汎用操作名 → ツール固有名の対応表
- サブエージェント呼び出しの変換方法
- エージェント別の使用操作一覧

## エージェント間の結果受け渡し

各エージェントはセッションフォルダ内の所定パスに結果を書き出す。Orchestrator はファイル内容をプロンプトに含めず、パスだけを渡す。各エージェントが自分で Read する。

```
.orchestrator/
├── templates/                    # 共通テンプレート（セッション外）
├── {連番}-{feature名}/           # セッションフォルダ（例: 0001-user-auth）
│   ├── explorer/
│   │   └── result.md
│   ├── planner/
│   │   ├── plan.md
│   │   └── tasks.md
│   ├── plan-reviewer/
│   │   ├── review-1.md          # ラウンドごとに連番
│   │   └── review-2.md
│   ├── task-{id}/                  # Phase 2: タスク単位
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
│   ├── test-runner/                # Phase 3: セッション全体検証
│   │   └── result-{round}.md
│   ├── linter/
│   │   └── result-{round}.md
│   ├── debugger/
│   │   └── report-{round}.md
│   ├── security-scanner/
│   │   └── result.md
│   ├── committer/                  # Phase 4: Git
│   │   └── result.md
│   └── pr-creator/
│       └── result.md
```

## Step 6: テンプレートの配置（必須）

エージェントはランタイムで `.orchestrator/templates/` 内のテンプレートを Read して出力フォーマットを決定する。
**このステップを省略するとエージェントが正しく動作しない。必ず全ファイルをコピーすること。**

まず出力先ディレクトリを作成:

```bash
mkdir -p .orchestrator/templates
mkdir -p .orchestrator/scripts
```

次に、以下の7ファイルを **1つずつ Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [exploration-result.md](references/templates/exploration-result.md) | `.orchestrator/templates/exploration-result.md` |
| 2 | [implementation-plan.md](references/templates/implementation-plan.md) | `.orchestrator/templates/implementation-plan.md` |
| 3 | [code-review-result.md](references/templates/code-review-result.md) | `.orchestrator/templates/code-review-result.md` |
| 4 | [test-result.md](references/templates/test-result.md) | `.orchestrator/templates/test-result.md` |
| 5 | [plan-review-result.md](references/templates/plan-review-result.md) | `.orchestrator/templates/plan-review-result.md` |
| 6 | [task-lifecycle-result.md](references/templates/task-lifecycle-result.md) | `.orchestrator/templates/task-lifecycle-result.md` |
| 7 | [tasks.md](references/templates/tasks.md) | `.orchestrator/templates/tasks.md` |

**手順**: 各行について Read ツールでファイル内容を取得し、Write ツールで Write 先に書き出す。内容は一切変更しない。

### スクリプトの配置

セッション初期化スクリプトを **Read → Write** でコピーする:

| # | Read 対象（このスキルの参照ファイル） | Write 先 |
|---|--------------------------------------|----------|
| 1 | [init-session.sh](references/scripts/init-session.sh) | `.orchestrator/scripts/init-session.sh` |
| 2 | [init-task.sh](references/scripts/init-task.sh) | `.orchestrator/scripts/init-task.sh` |

コピー後、実行権限を付与:

```bash
chmod +x .orchestrator/scripts/init-session.sh .orchestrator/scripts/init-task.sh
```

## 生成後チェックリスト

- [ ] `.orchestrator/templates/` に7ファイルが配置されている
- [ ] `.orchestrator/scripts/init-session.sh` と `init-task.sh` が配置されている
- [ ] ターゲットツールの形式に従っている
- [ ] description にトリガー条件が含まれている
- [ ] **model が適切に設定されている**（🧠/⚡/💨）
- [ ] 操作がツール固有の形式に変換されている
- [ ] サブエージェント呼び出しが正しい形式
- [ ] 入出力フォーマットが一貫している
- [ ] **エージェント定義がプロジェクト固有化されている**（テンプレートそのままではない）
- [ ] **不要な言語セクションが除去されている**
- [ ] **PM コマンドが具体値で記載されている**（検出テーブルではない）
- [ ] **テスト・Lint コマンドが具体値で記載されている**
