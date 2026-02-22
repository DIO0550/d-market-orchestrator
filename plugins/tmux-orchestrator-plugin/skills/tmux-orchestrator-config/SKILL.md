---
name: tmux-orchestrator-config
description: "tmux オーケストレーターの設定カスタマイズ。CLI割り当て（cli-assignments.json）やチーム設定（team-config.json）を対話的に作成・編集する。「tmux設定」「CLI割り当て変更」「チーム設定」などのリクエスト時に使用。"
---

# tmux Orchestrator Config

tmux オーケストレーターの CLI 割り当てやチーム設定を対話的に作成・編集するスキル。

## トリガー

- `/tmux-config` コマンドが実行されたとき
- ユーザーが「tmux設定」「CLI割り当て変更」「チーム設定」と指示したとき
- ユーザーが「エージェントのCLIを変えたい」と指示したとき

---

## 設定項目

### 1. CLI 割り当て設定

`.orchestrator/default-cli-assignments.json` を作成・編集する。
セッション作成時にこのファイルが各セッションの `.config/cli-assignments.json` にコピーされる。

#### 対話フロー

1. 既存の設定ファイルがあれば読み込んで現在の設定を表示
2. ユーザーに変更したいエージェントと CLI を確認
3. 設定ファイルを書き出す

#### デフォルト設定

```json
{
  "default_cli": "claude",
  "assignments": {
    "explorer": "claude",
    "planner": "claude",
    "plan-reviewer": "claude",
    "plan-quality-reviewer": "claude",
    "plan-bug-reviewer": "claude",
    "plan-performance-reviewer": "claude",
    "plan-security-reviewer": "claude",
    "implementer": "claude",
    "task-manager": "claude",
    "code-reviewer": "claude",
    "quality-reviewer": "claude",
    "bug-reviewer": "claude",
    "performance-reviewer": "claude",
    "security-reviewer": "claude",
    "test-runner": "claude",
    "linter": "claude",
    "security-scanner": "claude",
    "debugger": "claude",
    "refactorer": "claude",
    "committer": "claude",
    "pr-creator": "claude"
  }
}
```

#### 対応 CLI ツール

| CLI | コマンド | 備考 |
|-----|---------|------|
| Claude Code | `claude` | 推奨。全エージェントで使用可能 |
| OpenAI Codex | `codex` | 実装系エージェント向き |
| GitHub Copilot | `copilot` | ターミナル単体では機能限定的 |
| カスタム | 任意 | `custom_cli` セクションで定義 |

詳細: [cli-profiles.md](../tmux-orchestration/references/cli-profiles.md)

#### カスタム CLI の追加

ユーザーが独自の CLI ツールを使いたい場合、`custom_cli` セクションを追加:

```json
{
  "default_cli": "claude",
  "assignments": { ... },
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

### 2. チーム設定

`.orchestrator/team-config.json` を作成・編集する。
チーム名やメンバーの表示名をカスタマイズできる。**この設定は任意で、なくても全て動作する。**

#### 対話フロー

1. チーム名を確認（例: `Alpha`）
2. メンバー表示名をカスタマイズするか確認
   - **する場合**: 各エージェントの表示名を対話的に設定
   - **しない場合**: チーム名のみ設定
3. 設定ファイルを書き出す

#### 設定例

```json
{
  "team_name": "Alpha",
  "members": {
    "orchestrator": { "name": "Commander" },
    "explorer": { "name": "Scout" },
    "planner": { "name": "Architect" },
    "plan-reviewer": { "name": "Critic" },
    "implementer": { "name": "Builder" },
    "task-manager": { "name": "Captain" },
    "code-reviewer": { "name": "Inspector" },
    "test-runner": { "name": "Tester" },
    "linter": { "name": "Checker" },
    "debugger": { "name": "Medic" },
    "refactorer": { "name": "Polisher" },
    "committer": { "name": "Recorder" },
    "pr-creator": { "name": "Messenger" }
  }
}
```

#### 反映される箇所

| 項目 | デフォルト | カスタマイズ時 |
|------|----------|-------------|
| tmux セッション名 | `orch-{SESSION_ID}` | `{team_name}-{SESSION_ID}` |
| tmux ペインタイトル | `explorer` | `Scout (explorer)` |
| プロンプト冒頭 | `あなたは explorer エージェントです` | `あなたは **Alpha** の **Scout**（explorer）エージェントです` |
| ステータスモニター | `[RUNNING] explorer` | `[RUNNING] Scout (explorer)` |

#### 影響しない箇所

内部識別子・ファイルパス・IPC プロトコルは一切変更されない:
- `.status/explorer.done` — 変わらない
- `explorer/result.md` — 変わらない
- `.prompts/explorer-prompt.md` — 変わらない

---

## 完了後の案内

```
設定が完了しました。

現在の設定:
  - CLI割り当て: .orchestrator/default-cli-assignments.json
  - チーム設定:  .orchestrator/team-config.json（存在する場合）

オーケストレーションを開始するには:
  /tmux-orchestrate "タスクの説明"
```
