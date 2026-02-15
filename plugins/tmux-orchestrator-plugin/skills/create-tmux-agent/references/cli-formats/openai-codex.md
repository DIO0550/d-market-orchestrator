# OpenAI Codex CLI エージェント定義フォーマット

## 配置先

Codex は `AGENTS.md` ファイルまたは直接プロンプトで指示を受け取る。

```
AGENTS.md              # ルートに配置（全体指示）
{agent-name}/AGENTS.md  # サブディレクトリに配置（エージェント固有指示）
```

## フォーマット

Codex は YAML フロントマターを使用せず、純粋な Markdown で指示を記述する。

```markdown
# {Agent Name} エージェント

{エージェントの役割説明}

## 指示

{詳細な実行指示}

## 実行手順

1. {ステップ1}
2. {ステップ2}

## ファイル操作

- 読み込み: {ファイルパス} を確認
- 書き出し: {出力パス} に結果を保存

## 完了条件

{完了の判定基準}
```

## 起動コマンド

```bash
# 自律実行（推奨）
codex --approval-mode full-auto --quiet "{PROMPT}"

# プロンプトファイルの内容を渡す
codex --approval-mode full-auto --quiet "$(cat '{PROMPT_FILE}')"
```

## approval-mode オプション

| モード | 説明 |
|--------|------|
| `suggest` | 提案のみ（デフォルト） |
| `auto-edit` | ファイル編集は自動、コマンド実行は確認 |
| `full-auto` | すべて自動（tmux版で推奨） |

## tmux版での特記事項

- `--approval-mode full-auto` を必ず指定して自律実行させること
- `--quiet` で不要な対話出力を抑制すること
- AGENTS.md がプロジェクトルートにあると自動的に読み込まれる
- プロンプトファイルの内容を `cat` で展開して引数として渡す

### tmux での起動例

```bash
codex --approval-mode full-auto --quiet \
  "$(cat '.orchestrator/0001-user-auth/.prompts/implementer-prompt.md')"
```
