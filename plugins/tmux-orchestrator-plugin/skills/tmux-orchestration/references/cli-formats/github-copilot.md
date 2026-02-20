# GitHub Copilot 指示ファイルフォーマット

## 配置先

```
.github/agents/{agent-name}.agent.md
```

## フォーマット

```markdown
---
name: {agent-name}
description: "{トリガー条件を含む説明}"
tools:
  - name: execute
  - name: editFiles
  - name: terminalLastCommand
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
| name | 必須 | エージェント識別名 |
| description | 必須 | エージェントの説明文 |
| tools | 任意 | 使用するツール一覧 |

## ツール名対応表

| 汎用操作 | Copilot ツール |
|---------|---------------|
| ファイル読み込み | `#file` ディレクティブ |
| ファイル書き込み | `editFiles` |
| ファイル編集 | `editFiles` |
| コマンド実行 | `execute` |
| エージェント起動 | `#tool:agent/runSubagent` |
| コンテキスト参照 | `@workspace` |

## tmux版での特記事項

Copilot CLI はターミナル単体での自律実行機能が限定的。
tmux版での使用は以下のシナリオに限定される:

1. **シェルコマンドの提案**: `gh copilot suggest -t shell` でコマンドを生成・実行
2. **コード説明**: `gh copilot explain` でコードの解説を取得

本格的なコード生成・編集には Copilot Coding Agent（GitHub.com経由）の利用を推奨。

### tmux での起動例

```bash
echo "このリポジトリのテストを実行するコマンドを提案してください" | \
  gh copilot suggest -t shell
```
