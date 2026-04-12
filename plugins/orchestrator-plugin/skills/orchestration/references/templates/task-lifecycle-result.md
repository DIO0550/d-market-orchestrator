# タスクライフサイクル結果

## 指示

割り当てられた **1つのタスク** のライフサイクルを管理する。
コードの変更は自分では行わず、サブエージェントに委譲する。

## ライフサイクルフロー

```
1. Implementer 起動 → 完了待ち
2. 3つのレビューエージェント並列起動 → 全完了待ち
   (quality-reviewer / logic-reviewer / performance-reviewer)
3. レビュー結果集約 → 最終判定
4. 全員 Approved かつ推奨対応あり → Refactorer 起動
5. completed / rejected 判定
6. rejected → Implementer 再起動（最大2回リトライ）
```

## サブエージェント起動パターン

各サブエージェントには以下の形式で prompt を渡す:

```
prompt: |
  あなたは{role}です。

  ## 対象タスク
  - タスクID: {taskId}
  - 件名: {subject}
  - 完了条件: {完了条件}

  ## 入力（該当する場合）
  {前のエージェントの出力}

  ## 指示
  `.orchestrator/templates/{template}.md` を読み、その指示に従ってください。
  結果を標準出力で返してください。
```

### テンプレート対応表

| エージェント | テンプレート |
|---|---|
| Implementer | `implementation-result.md` |
| Quality Reviewer | `quality-review-result.md` |
| Logic Reviewer | `logic-review-result.md` |
| Performance Reviewer | `performance-review-result.md` |
| Refactorer | `refactoring-result.md` |

### 3つのレビューエージェントの並列起動

**必ず1つのメッセージ内で3つの Task tool を同時に呼び出すこと（並列実行）。**

## レビュー結果の集約

### 判定ルール
- **全員 Approved** → Approved（推奨対応があれば Refactorer に渡す）
- **1つでも Request Changes** → Request Changes（差し戻し）

### 差し戻し時

差し戻し理由を記録し、Implementer を再起動する。リトライは最大 **2回** まで。
2回失敗した場合は rejected として結果を返す。

## 完了判定

### completed にする基準
- 完了条件が概ね満たされている
- 変更対象ファイルが変更されている
- 重大なスコープ逸脱がない
- レビューエージェントから致命的な指摘がない

### rejected にする基準
- 完了条件の主要項目が満たされていない
- 明らかに間違った実装がされている
- レビューエージェントから致命的な指摘がある

### 迷った場合
- 軽微な問題は completed + 注意事項として記録
- **過度に厳格にならない** -- Phase 3（テスト・Lint）で品質検証される

## 出力フォーマット

タスクID: {taskId}
最終判定: {completed / rejected}

### Implementer 実装結果
{サマリー}

### レビュー結果（実施時）

#### Quality Reviewer
{サマリー}

#### Logic Reviewer
{サマリー}

#### Performance Reviewer
{サマリー}

#### 最終判定
{Approved / Request Changes}

### Refactorer リファクタリング結果（実施時）
{サマリー}

### 完了判定

| チェック項目 | 結果 | 備考 |
|-------------|------|------|
| 変更対象ファイル | OK/NG | {詳細} |
| 完了条件の充足 | OK/NG | {詳細} |
| スコープの逸脱 | OK/NG | {詳細} |
| レビュー指摘 | OK/NG/N/A | {詳細} |

### リトライ回数
{0-2回}
