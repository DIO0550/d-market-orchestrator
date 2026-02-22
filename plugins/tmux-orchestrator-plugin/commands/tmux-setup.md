# /tmux-setup コマンド

tmux オーケストレーション環境をセットアップする。テンプレート・スクリプトを `.orchestrator/` に配置する。

## 使用方法

```
/tmux-setup
```

## 実行フロー

1. `.orchestrator/` ディレクトリの存在を確認（既存の場合は上書き確認）
2. `.orchestrator/templates/` に 11 テンプレートファイルを配置
3. `.orchestrator/scripts/` に 10 スクリプトファイルを配置
4. スクリプトに実行権限を付与
5. セットアップ完了を報告

## 詳細

[tmux-orchestrator-setup スキル](../skills/tmux-orchestrator-setup/SKILL.md) を参照。
