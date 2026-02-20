# コードレビュー（統合レビュー結果）

レビュー日時: {timestamp}
ラウンド: {round}
対象タスク: task-{taskId}

## 総合評価

**判定**: {Approved / Approved with Suggestions / Request Changes}

## スペシャリストレビュー概要

| スペシャリスト | 指摘数 | 高 | 中 | 低 |
|--------------|--------|---|---|---|
| Quality Reviewer | {n} | {n} | {n} | {n} |
| Bug Reviewer | {n} | {n} | {n} | {n} |
| Performance Reviewer | {n} | {n} | {n} | {n} |
| Security Reviewer | {n} | {n} | {n} | {n} |

## 仕様適合性チェック（Lead Reviewer）

| チェック項目 | 結果 | コメント |
|-------------|------|---------|
| 完了条件の充足 | {OK/NG} | {コメント} |
| スコープ逸脱 | {なし/あり} | {コメント} |

## 統合レビュー結果

### 必須対応（Request Changes の場合）

| # | 出典 | 重要度 | ファイル | 行 | 内容 | 推奨修正 |
|---|------|-------|---------|---|------|---------|
| 1 | {スペシャリスト名} | 高 | {path} | L{n} | {問題} | {修正案} |

### 推奨対応

| # | 出典 | 重要度 | ファイル | 行 | 内容 | 推奨修正 |
|---|------|-------|---------|---|------|---------|
| 1 | {スペシャリスト名} | 中 | {path} | L{n} | {問題} | {修正案} |

## コンフリクト解決（該当時）

| # | スペシャリスト A | スペシャリスト B | 矛盾内容 | Lead Reviewer 判断 |
|---|---------------|---------------|---------|-----------------|

## スペシャリスト詳細レビュー

各スペシャリストの詳細レビューは以下を参照:
- Quality: `{SESSION_DIR}/task-{taskId}/code-reviewer/quality-review-{round}.md`
- Bug: `{SESSION_DIR}/task-{taskId}/code-reviewer/bug-review-{round}.md`
- Performance: `{SESSION_DIR}/task-{taskId}/code-reviewer/performance-review-{round}.md`
- Security: `{SESSION_DIR}/task-{taskId}/code-reviewer/security-review-{round}.md`
