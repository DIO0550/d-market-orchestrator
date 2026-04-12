# テスト結果

## 指示

テストを実行し、結果を報告する。コードの修正は行わない。

## 事前確認（3段階検証）

1. `CLAUDE.md` を読み、テストに関するルール・カスタムコマンドを確認する
2. `package.json` の `scripts` セクションを確認する（Node.js の場合）
3. ロックファイルでパッケージマネージャーを検出する

### PM検出テーブル

| ロックファイル | PM | テストコマンド |
|--------------|-----|--------------|
| `pnpm-lock.yaml` | pnpm | `pnpm run test` |
| `yarn.lock` | yarn | `yarn run test` |
| `package-lock.json` | npm | `npm run test` |
| `bun.lockb` | bun | `bun run test` |
| `Cargo.toml` | cargo | `cargo test` |
| `pyproject.toml` | python | `pytest` |
| `go.mod` | go | `go test ./...` |

### `--` セパレータの注意

- pnpm: `pnpm run test -t "foo"` (`--` 不要)
- npm: `npm run test -- -t "foo"` (`--` 必要)

### Phase 2（taskId あり）の場合

関連テストファイルのみ実行する:
1. 変更ファイルに対応するテストを探す（`*.test.*`, `*.spec.*`, `test_*`, `*_test.*`）
2. 特定できない場合はフルテストスイートにフォールバック

## 出力フォーマット

実行日時: {timestamp}
実行コマンド: {command}

### サマリー

| 項目 | 値 |
|------|---|
| ステータス | {PASS / FAIL} |
| 総テスト数 | {n} |
| 成功 | {n} |
| 失敗 | {n} |

### 失敗テスト

#### {テスト名}

**ファイル**: {テストファイルパス}
**行**: {行番号}

**期待値**:
```
{expected}
```

**実際の値**:
```
{actual}
```

**考えられる原因**:
1. {原因の推測}

**推奨対応**:
- {対応案}

### 次のステップ

- テスト失敗時: Debugger で原因分析
- テスト成功時: Linter でコード品質チェック
