# CLI プロファイル

tmux-orchestrator が対応する AI CLI ツールのプロファイル一覧。

## 対応 CLI 比較表

| 項目 | Claude Code | OpenAI Codex | GitHub Copilot | 汎用 CLI |
|------|-------------|--------------|----------------|---------|
| コマンド | `claude` | `codex` | `gh copilot` | 任意 |
| プロンプト方式 | 位置引数（初期プロンプト） | 位置引数 / `--prompt` | `--prompt` / stdin | 設定による |
| 自律実行モード | `--dangerously-skip-permissions` | `--approval-mode full-auto` | N/A | 設定による |
| ファイル編集 | 可能（Write/Edit ツール） | 可能（内蔵） | エディタ連携 | 設定による |
| コマンド実行 | 可能（Bash ツール） | 可能（内蔵） | `execute` | 設定による |
| エージェント管理 | 可能（Task ツール） | 不可 | 不可 | 不可 |
| 実行モード | 対話的（tmuxペイン内） | `--quiet` | 対話的 | 設定による |

## Claude Code CLI

### 基本情報

```
コマンド:     claude
インストール: npm install -g @anthropic-ai/claude-code
確認:         claude --version
```

### 起動テンプレート

```bash
# プロンプトファイルから対話モードで実行（推奨）
claude --dangerously-skip-permissions "$(cat '{PROMPT_FILE}')"

# 直接プロンプト（対話モード）
claude --dangerously-skip-permissions "{PROMPT}"

# 非対話モード（単発出力のみ、ファイル編集不可）
claude -p "{PROMPT}"
```

### 能力

- ファイル読み書き: Read, Write, Edit ツール
- コマンド実行: Bash ツール
- ファイル検索: Glob, Grep ツール
- エージェント管理: Task ツール（tmux版では不使用）
- Web検索: WebSearch, WebFetch ツール

### tmux での使用上の注意

- `--dangerously-skip-permissions` で自律実行モードにすること
- tmux ペイン内で対話的に起動し、エージェントが自律的にツールを使用して作業する
- プロンプトファイルにセッションパスと出力先を明記すること
- CLAUDE.md が作業ディレクトリに存在すればプロジェクトルールが自動適用される
- エージェントは作業完了後、`.done` マーカーを書き出し `notify-parent.sh` で完了通知する

---

## OpenAI Codex CLI

### 基本情報

```
コマンド:     codex
インストール: npm install -g @openai/codex
確認:         codex --version
```

### 起動テンプレート

```bash
# 自律実行（推奨）
codex --approval-mode full-auto --quiet "{PROMPT}"

# プロンプトファイルから（catで渡す）
codex --approval-mode full-auto --quiet "$(cat '{PROMPT_FILE}')"

# AGENTS.md 参照モード
# 作業ディレクトリに AGENTS.md を配置すると自動的に参照される
codex --approval-mode full-auto "{PROMPT}"
```

### 能力

- ファイル読み書き: 内蔵機能
- コマンド実行: 内蔵シェル
- ファイル検索: 内蔵機能
- エージェント管理: 不可（AGENTS.md による指示のみ）

### tmux での使用上の注意

- `--approval-mode full-auto` で完全自律モードにすること
- `--quiet` で余分な出力を抑制すること
- AGENTS.md に詳細な指示を書くことでエージェント動作を制御可能

---

## GitHub Copilot CLI

### 基本情報

```
コマンド:     gh copilot
インストール: gh extension install github/gh-copilot
確認:         gh copilot --version
```

### 起動テンプレート

```bash
# 提案モード
echo "{PROMPT}" | gh copilot suggest -t shell

# 説明モード
echo "{PROMPT}" | gh copilot explain
```

### 能力

- ファイル読み書き: エディタ連携（VS Code）
- コマンド実行: `execute` / `terminalLastCommand`
- エージェント管理: `#tool:agent/runSubagent`（VS Code内）

### tmux での使用上の注意

- Copilot CLI はターミナル単体では機能が限定的
- 本格的なコード生成にはCopilot Coding Agent（GitHub.com経由）の利用を推奨
- tmuxでの使用は主にシェルコマンドの提案・実行に限定される

---

## 汎用 CLI

### 基本情報

```
コマンド:     {CLI_COMMAND}
プロンプト:   {PROMPT_FLAG} {path}
自律モード:   {AUTO_FLAG}
```

### 起動テンプレート

```bash
# 基本形
{CLI_COMMAND} {AUTO_FLAG} {PROMPT_FLAG} "{PROMPT_FILE}"
```

### 設定例

`cli-assignments.json` でカスタムCLIを指定する場合:

```json
{
  "default_cli": "claude",
  "custom_cli": {
    "my-ai-tool": {
      "command": "my-ai-tool",
      "prompt_flag": "--input",
      "auto_flag": "--no-confirm"
    }
  }
}
```

---

## CLI 割り当て設定

`.orchestrator/{SESSION_ID}/.config/cli-assignments.json` でエージェントごとのCLIを設定:

```json
{
  "default_cli": "claude",
  "assignments": {
    "explorer": "claude",
    "planner": "claude",
    "plan-reviewer": "claude",
    "implementer": "codex",
    "task-manager": "claude",
    "code-reviewer": "claude",
    "quality-reviewer": "claude",
    "bug-reviewer": "claude",
    "performance-reviewer": "claude",
    "security-reviewer": "claude",
    "test-runner": "codex",
    "linter": "codex",
    "security-scanner": "claude",
    "debugger": "claude",
    "refactorer": "codex",
    "committer": "claude",
    "pr-creator": "claude"
  }
}
```

### 推奨割り当て

| エージェント | 推奨CLI | 理由 |
|-------------|---------|------|
| Orchestrator | claude | Task ツールによる高度な制御 |
| Explorer | claude | Glob/Grep ツールの充実 |
| Planner | claude | 複雑な判断力 |
| Plan Reviewer | claude | 高度なレビュー能力 |
| Implementer | claude / codex | コード生成能力 |
| Task Manager | claude | ペインでのエージェント管理 |
| Code Reviewer | claude | tmux管理+統合判断 |
| Quality Reviewer | claude | コード品質分析 |
| Bug Reviewer | claude | バグリスク分析 |
| Performance Reviewer | claude | パフォーマンス分析 |
| Security Reviewer | claude | セキュリティ分析 |
| Test Runner | claude / codex | コマンド実行 |
| Linter | claude / codex | コマンド実行 |
| Security Scanner | claude | セキュリティ知識 |
| Debugger | claude | 複雑な分析 |
| Refactorer | claude / codex | コード変更 |
| Committer | claude / codex | Git操作 |
| PR Creator | claude | PR 記述能力 |
