# Claude Code 指示ファイルフォーマット

## 配置先

```
.claude/agents/{agent-name}.md
```

## フォーマット

```markdown
---
name: {agent-name}
description: "{トリガー条件を含む説明}"
model: {opus|sonnet|haiku}
tools: ["read", "edit", "search", "execute", "agent", "todo"]
color: {magenta|cyan|green|yellow|red|blue}
---

# {Agent Name} エージェント

{エージェントの役割説明}

## 指示

{詳細な実行指示}

## 実行手順

1. {ステップ1}
2. {ステップ2}

## 完了条件

{完了の判定基準}
```

## フロントマター項目

| 項目 | 必須 | 説明 |
|------|------|------|
| name | 必須 | エージェント識別名（ハイフン区切り英小文字） |
| description | 必須 | トリガー条件を含むエージェントの説明文 |
| model | 必須 | 使用するモデル（opus / sonnet / haiku） |
| tools | 任意 | 使用するツール一覧 |
| color | 任意 | ターミナルでの表示色 |

## ツール名対応表

| 汎用操作 | Claude Code ツール |
|---------|-------------------|
| ファイル読み込み | `Read` |
| ファイル書き込み | `Write` |
| ファイル編集 | `Edit` |
| ファイル検索 | `Glob` |
| コード検索 | `Grep` |
| コマンド実行 | `Bash` |
| エージェント起動 | `Task` |
| エージェント結果取得 | `TaskOutput` |
| タスク管理 | `TaskCreate`, `TaskUpdate`, `TaskList` |
| ユーザー質問 | `AskUserQuestion` |
| Web検索 | `WebSearch` |
| URL取得 | `WebFetch` |

## tmux版での特記事項

tmux版では Orchestrator が `Bash` ツールを使って tmux コマンドを実行し、他のエージェントを起動する。
各エージェントは独立した `claude` プロセスとして tmux ペインで動作するため、`Task` ツールによるエージェント起動は不要。

代わりに以下のパターンを使用:

```bash
# 自身のペインIDを取得（エージェント完了通知の受信先）
PARENT_PANE=$(tmux display-message -p '#{pane_id}')

# エージェント起動（第6引数に PARENT_PANE を渡す）
bash .orchestrator/scripts/tmux-agent-launch.sh \
  "{TMUX_SESSION}" "explorer" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md" \
  ".orchestrator/{SESSION_ID}" "$PARENT_PANE"

# エージェント完了時、親ペインの入力に以下のメッセージが届く:
#   [AGENT_COMPLETE] explorer done
```
