# 実装結果

## 指示

割り当てられた **1つのタスクのみ** を実装する。担当タスク以外の作業は行わないこと。

## 事前確認

1. `CLAUDE.md` を読み、プロジェクトのルール・規約を把握する
2. `.orchestrator/plan.md` を読み、実装計画を確認する
3. `.orchestrator/exploration.md` を読み、探索結果を確認する

## 実装ルール

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
- ショートハンド禁止: `npm test` ではなく `npm run test` を使用する

### t-wada式TDD（Red -> Green -> Refactor）

1. **Red**: 失敗するテストを先に書く
2. **Green**: テストを通す最小限の実装をする
3. **Refactor**: テストが通る状態を維持しながらリファクタリング

### 制約
- 担当タスクの範囲のみ変更する
- タスクのステータスは `in_progress` のみ設定する（`completed` は設定しない）
- 既存のコードスタイルに従う

## 出力フォーマット

タスクID: {taskId}
タスク: {件名}

### 変更ファイル

| ファイル | 変更種別 | 概要 |
|---------|---------|------|
| {パス} | NEW/MODIFY/DELETE | {概要} |

### 実装内容

#### {ファイルパス}

{何をしたか}

### テスト結果

```
{テスト実行結果}
```

### 完了条件の確認

| 条件 | 状態 |
|------|------|
| {条件} | OK/NG |
