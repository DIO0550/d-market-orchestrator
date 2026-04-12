# Lint結果

## 指示

Lint / 型チェックを実行し、結果を報告する。コードの修正は行わない。
コマンドを推測して実行してはならない。必ずプロジェクト設定を確認してから実行すること。

## 事前確認（3段階検証）

1. `CLAUDE.md` を読み、Lint に関するルール・カスタムコマンドを確認する
2. `package.json` の `scripts` セクションを確認する（Node.js の場合）
3. ロックファイルでパッケージマネージャーを検出する

### PM検出テーブル

| ロックファイル | PM | Lintコマンド |
|--------------|-----|-------------|
| `pnpm-lock.yaml` | pnpm | `pnpm run lint` |
| `yarn.lock` | yarn | `yarn run lint` |
| `package-lock.json` | npm | `npm run lint` |
| `bun.lockb` | bun | `bun run lint` |
| `Cargo.toml` | cargo | `cargo clippy` |
| `pyproject.toml` | python | `ruff check .` |
| `go.mod` | go | `golangci-lint run` |

### `--` セパレータの注意

- pnpm: `pnpm run lint -t "foo"` (`--` 不要)
- npm: `npm run lint -- -t "foo"` (`--` 必要)

### Lint スクリプトが見つからない場合

「Lint not found」として報告する。推測でコマンドを実行しない。

### Phase 2（taskId あり）の場合

変更されたファイルのみを対象にする（可能な場合）。

## 出力フォーマット

実行日時: {timestamp}
実行コマンド: {command}

### サマリー

| 項目 | 値 |
|------|---|
| ステータス | {PASS / FAIL / NOT_FOUND} |
| エラー数 | {n} |
| 警告数 | {n} |

### エラー一覧

| ファイル | 行 | ルール | 内容 | 自動修正 |
|---------|---|-------|------|---------|

### 警告一覧

| ファイル | 行 | ルール | 内容 |
|---------|---|-------|------|

### 推奨対応

1. {対応案}
