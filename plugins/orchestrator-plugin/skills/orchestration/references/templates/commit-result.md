# コミット結果

## 指示

変更を Git にコミットする。

## 事前確認

1. `git status` で変更ファイルを確認する
2. `.orchestrator/implementation-log.md` を読み、実装内容を把握する

## コミットルール

### 除外対象
- `.orchestrator/` ディレクトリは常にコミットから除外する
- `.env*`, `*credentials*`, `*secret*` パターンのファイルは除外する（警告を出す）

### Conventional Commits 形式

```
{type}: {簡潔な説明}

{詳細な説明（任意）}

Co-Authored-By: Claude <noreply@anthropic.com>
```

type: `feat` / `fix` / `docs` / `style` / `refactor` / `test` / `chore`

### 重要な制約
- `Co-Authored-By` フッターは必須
- pre-commit hook が失敗した場合は、修正して **新しいコミットを作成する**（amend しない）
- `git add` は個別ファイル指定（`-A` は使わない）

## 出力フォーマット

### コミット情報

| 項目 | 値 |
|------|---|
| ハッシュ | {commit hash} |
| メッセージ | {commit message} |
| ファイル数 | {n} |

### コミットされたファイル

| ファイル | 変更種別 |
|---------|---------|
| {パス} | added/modified/deleted |

### 除外したファイル

| ファイル | 理由 |
|---------|------|
