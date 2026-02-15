# CLI プロファイル

tmux-orchestrator が対応する AI CLI ツールのプロファイル一覧。

## 対応 CLI 比較表

| 項目 | Claude Code | OpenAI Codex | GitHub Copilot | 汎用 CLI |
|------|-------------|--------------|----------------|---------|
| コマンド | `claude` | `codex` | `gh copilot` | 任意 |
| プロンプト方式 | `--prompt-file` / `-p` | 位置引数 / `--prompt` | `--prompt` / stdin | 設定による |
| 自律実行モード | `--dangerously-skip-permissions` | `--approval-mode full-auto` | N/A | 設定による |
| ファイル編集 | 可能（Write/Edit ツール） | 可能（内蔵） | エディタ連携 | 設定による |
| コマンド実行 | 可能（Bash ツール） | 可能（内蔵） | `execute` | 設定による |
| サブエージェント | 可能（Task ツール） | 不可 | 不可 | 不可 |
| 出力モード | `--print`（標準出力） | `--quiet` | 対話的 | 設定による |

## Claude Code CLI

### 基本情報

```
コマンド:     claude
インストール: npm install -g @anthropic-ai/claude-code
確認:         claude --version
```

### 起動テンプレート

```bash
# プロンプトファイルから実行（推奨）
claude --print --prompt-file "{PROMPT_FILE}" --output-format text

# 直接プロンプト
claude --print -p "{PROMPT}"

# 許可設定付き（自律実行）
claude --print --prompt-file "{PROMPT_FILE}" --dangerously-skip-permissions
```

### 能力

- ファイル読み書き: Read, Write, Edit ツール
- コマンド実行: Bash ツール
- ファイル検索: Glob, Grep ツール
- サブエージェント: Task ツール（tmux版では不使用）
- Web検索: WebSearch, WebFetch ツール

### tmux での使用上の注意

- `--print` フラグで非対話モードにすること
- プロンプトファイルにセッションパスと出力先を明記すること
- CLAUDE.md が作業ディレクトリに存在すればプロジェクトルールが自動適用される

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
- サブエージェント: 不可（AGENTS.md による指示のみ）

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
- サブエージェント: `#tool:agent/runSubagent`（VS Code内）

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
| Task Manager | claude | サブエージェント管理 |
| Code Reviewer | claude | 詳細なレビュー |
| Test Runner | claude / codex | コマンド実行 |
| Linter | claude / codex | コマンド実行 |
| Security Scanner | claude | セキュリティ知識 |
| Debugger | claude | 複雑な分析 |
| Refactorer | claude / codex | コード変更 |
| Committer | claude / codex | Git操作 |
| PR Creator | claude | PR 記述能力 |
