# CLAUDE.md

このリポジトリは Claude Code 向けプラグインのマーケットプレイス（`d-market-orchestrator`）のソースです。AI エージェントを分担・並列・ループで動かすオーケストレーション系のプラグインを置いています。

## リポジトリ構成

```
.claude-plugin/marketplace.json        # マーケットプレイス登録情報（metadata.version と各プラグインの version）
plugins/
├── orchestrator-plugin/               # サブエージェント並列起動
├── tmux-orchestrator-plugin/          # tmux + ファイルベース IPC
├── copilot-chat-orchestrator-plugin/  # Copilot Chat 版
└── harness-loop-plugin/               # 計画 → 目標確定 → ループ → PR
    ├── .claude-plugin/plugin.json
    ├── agents/                        # サブエージェント定義（frontmatter に model / effort / maxTurns）
    ├── hooks/                         # hooks.json とフックのスクリプト、tests/hook-cases.sh（判定表）
    └── skills/harness-loop/           # SKILL.md・assets/templates/・references/
```

## 開発ルール

### バージョン

**プラグインの中身（スキル・エージェント・フック・テンプレート・参照資料など）を変えたら、同じ PR で次の 3 つを上げる。**

1. 変えたプラグインの `plugin.json` の `version`
2. `.claude-plugin/marketplace.json` の、そのプラグインのエントリの `version`（1 と同じ値にする）
3. `.claude-plugin/marketplace.json` の `metadata.version`

- 上げ方は semver に従う。挙動を変えない修正（誤字・説明の直し）は patch、機能の追加・手順の変更は minor、既存の使い方が壊れる変更（スキル名・引数・run フォルダの形式の変更など）は major
- 1 つの PR で同じプラグインを何度変えても、上げるのは 1 回でよい（main に対して 1 段上がっていればよい）
- README だけ・このファイルだけの変更では上げない

### プラグインの置き方

- プラグインメタデータは各プラグイン直下の `.claude-plugin/plugin.json` に置く（プラグイン直下に直接置くと Claude Code がマニフェストとして認識しない）。`orchestrator-plugin` / `tmux-orchestrator-plugin` / `copilot-chat-orchestrator-plugin` は現状プラグイン直下に `plugin.json` があるので、触るときに移す
- プラグインを追加・改名したら、`.claude-plugin/marketplace.json` のエントリと README の一覧も同じ PR で直す
- エージェントは `plugins/{plugin}/agents/{name}.md`、スキルは `plugins/{plugin}/skills/{name}/SKILL.md`。SKILL.md が長くなったら手順を `references/` に分け、SKILL.md からは「いつ読むか」だけを指す

### harness-loop-plugin

- フックを変えたら判定表を走らせ、すべて通ることを確かめる: `bash plugins/harness-loop-plugin/hooks/tests/hook-cases.sh`
- 判定を足したら、その判定を壊したときに判定表が落ちることも確かめる（落ちないなら判定表にケースを足す）
- エージェントの model は opus（判断が要るもの）と haiku（決まった手順をなぞるもの）の 2 種類に揃える

## コマンド

ビルドの手順はありません。プラグインはマークダウンとシェルスクリプトで構成されており、Claude Code から直接ロードされます。
