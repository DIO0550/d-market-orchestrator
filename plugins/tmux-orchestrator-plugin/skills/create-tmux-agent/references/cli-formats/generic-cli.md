# 汎用 CLI エージェント定義フォーマット

Claude Code / Codex / Copilot 以外の AI CLI ツールを使用する場合のガイド。

## 要件

tmux-orchestrator で汎用 CLI を使用するには、以下の条件を満たす必要がある:

1. **コマンドラインから起動できる**: ターミナルで実行可能なCLIコマンドがあること
2. **プロンプトを受け取れる**: ファイルまたは引数でプロンプトを渡せること
3. **ファイルを読み書きできる**: プロジェクトのファイルを操作できること
4. **非対話モードがある**: ユーザー入力なしで完了できること

## CLI 登録方法

`cli-assignments.json` の `custom_cli` セクションにプロファイルを追加:

```json
{
  "default_cli": "claude",
  "custom_cli": {
    "my-ai-tool": {
      "command": "my-ai-tool",
      "prompt_flag": "--input",
      "auto_flag": "--no-confirm",
      "file_flag": "--file"
    }
  },
  "assignments": {
    "implementer": "my-ai-tool"
  }
}
```

## 起動テンプレート

`tmux-agent-launch.sh` の汎用ケース:

```bash
# コマンド構築
{CLI_COMMAND} {AUTO_FLAG} {PROMPT_FLAG} "{PROMPT_FILE}"

# 例
my-ai-tool --no-confirm --input ".orchestrator/0001/.prompts/implementer-prompt.md"
```

## プロンプトファイル

汎用 CLI 向けのプロンプトファイルは、CLI 固有のディレクティブを含まないプレーンな Markdown で記述する:

```markdown
# タスク指示

## 概要
{タスクの説明}

## 入力ファイル
- {パス1}: {説明}

## 出力先
- {出力パス}: {説明}

## 手順
1. {ステップ1}
2. {ステップ2}

## 完了条件
- {出力パス} にファイルが作成されていること
```

## 制限事項

- サブエージェント起動は不可（Orchestrator が直接管理）
- CLI 固有の機能（VS Code 連携等）は使用不可
- プロンプトのサイズ制限はCLIツールに依存
