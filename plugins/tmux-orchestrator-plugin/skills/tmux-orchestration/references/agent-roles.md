# エージェント役割定義

tmux-orchestrator で使用する14エージェントの役割・責務・実行フェーズの詳細。

## 役割マトリックス

| エージェント | フェーズ | 役割 | モデル | 入力 | 出力 |
|-------------|---------|------|--------|------|------|
| Orchestrator | 全体 | 司令塔・tmux管理 | 🧠 opus | ユーザータスク | 全体制御 |
| Explorer | Phase 1 | コード探索 | ⚡ sonnet | タスク概要 | 探索結果 |
| Planner | Phase 1 | 実装計画 | 🧠 opus | 探索結果 | 計画+タスク |
| Plan Reviewer | Phase 1 | 計画検証 | 🧠 opus | 計画 | レビュー結果 |
| Task Manager | Phase 2 | タスク管理 | ⚡ sonnet | タスク詳細 | ライフサイクル |
| Implementer | Phase 2 | コード実装 | ⚡ sonnet | 計画+タスク | 実装結果 |
| Code Reviewer | Phase 2 | コードレビュー | 🧠 opus | 実装結果 | レビュー結果 |
| Test Runner | Phase 2/3 | テスト実行 | 💨 haiku | 対象コード | テスト結果 |
| Linter | Phase 2/3 | Lint実行 | 💨 haiku | 対象コード | Lint結果 |
| Security Scanner | Phase 3 | セキュリティ検査 | ⚡ sonnet | 実装結果 | 脆弱性レポート |
| Debugger | Phase 2/3 | エラー分析・修正 | 🧠 opus | テスト失敗結果 | デバッグレポート |
| Refactorer | Phase 2 | コード改善 | ⚡ sonnet | レビュー指摘 | リファクタ結果 |
| Committer | Phase 4 | Git コミット | 💨 haiku | 実装ログ | コミット結果 |
| PR Creator | Phase 4 | PR 作成 | 💨 haiku | 実装ログ | PR URL |

## フェーズ別のエージェント構成

### Phase 1: 探索・計画・レビュー

```
Explorer → Planner → Plan Reviewer
  │           │            │
  │           │            └── Needs Revision → Planner 再起動
  │           └── tasks.json + plan.md
  └── result.md
```

### Phase 2: 実装（タスクごと）

```
Task Manager（タスクごとに1つ）
  │
  ├── Implementer → 実装
  ├── Test Runner + Linter → テスト・Lint（並列）
  ├── Code Reviewer → レビュー
  ├── Refactorer → 推奨対応の適用
  └── 完了判定（rejected → Implementer 再起動、最大2回）
```

### Phase 3: 検証

```
Test Runner ──┐
              ├── 並列実行 → 失敗時 → Debugger → 再実行（最大10回）
Linter ───────┘
Security Scanner（任意）
```

### Phase 4: Git

```
Committer → PR Creator
```

## 責務の境界

### Orchestrator がやること
- tmux セッション・ペインの作成・管理
- プロンプトファイルの生成
- `.status/` ディレクトリの監視
- 依存関係に基づくタスク起動順序の制御
- 結果のユーザーへの報告

### Orchestrator がやらないこと
- コードの直接的な調査・探索（→ Explorer）
- 実装・編集（→ Implementer）
- テスト実行（→ Test Runner）
- レビュー判断（→ Code Reviewer / Plan Reviewer）
