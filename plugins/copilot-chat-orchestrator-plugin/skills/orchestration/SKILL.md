---
name: orchestration
description: "タスクを専門エージェントに分散して並列実行するオーケストレーションワークフロー。Copilot Chat の #tool:agent/runSubagent を使用。"
disable-model-invocation: true
---

# Orchestration Skill（Copilot Chat版）

タスクを専門エージェントに分散して並列実行するオーケストレーションワークフロー。
Copilot ではサブエージェントのネストが不可のため、フラット構造で全エージェントを Orchestrator が直接起動する。

## トリガー

- ユーザーがタスクのオーケストレーション（分散・並列実行）を依頼したとき
- ユーザーが「テスト実行して」「Lint実行して」「コミットして」「PR作って」と指示したとき

## ワークフロー概要

```
[Phase 0: セッション初期化] ─────────────────────────
    │
    └── init-session.sh で SESSION_DIR を生成
    │
[Phase 1: 探索・計画] ───────────────────────────────
    │
    ├── explorer（バックグラウンド）
    │   └── 関連ファイルを探索
    │
    ▼ (explorer 完了待ち)
    │
    ├── planner（バックグラウンド・探索結果パスを入力）
    │   └── 探索結果を基にタスクを分析し実装計画を作成
    │
    ▼ (planner 完了待ち)
    │
    ├── plan-reviewer（バックグラウンド・計画パスを入力）
    │   └── 計画の妥当性を検証（Needs Revision → planner 再起動）
    │
    ▼ (plan-reviewer 完了待ち → 計画をユーザーに提示し Phase 2 へ)
    │
[Phase 2: 実装（フラット構造）] ──────────────────────
    │
    ├── Orchestrator がタスク一覧を確認
    ├── ブロック解除済みタスクごとに以下を Orchestrator が直接起動:
    │   │
    │   ├── 1. implementer → 実装
    │   ├── 2. test-runner + linter → TDD検証（並列）
    │   │      失敗 → implementer 再起動（Step 1 に戻る）
    │   ├── 3. refactorer → コード改善
    │   ├── 4. code-reviewer → レビュー
    │   └── 5. task-manager → 完了判定（判定のみ）
    │          completed → 次のタスクへ
    │          rejected → implementer 再起動（最大2回リトライ）
    │
    ├── 独立タスクは implementer を並列起動
    │
    ▼ (全タスク completed → 結果をユーザーに報告)
    │
    ★ 自動実行停止
    │
[Phase 3: 検証] ─────────────── ユーザー指示で実行
    │
    ├── test-runner（バックグラウンド）
    ├── linter（バックグラウンド・並列）
    │   失敗 → debugger で原因分析・修正 → 再検証（最大10回）
    │
[Phase 4: Git操作] ────────────── ユーザー指示で実行
    │
    ├── committer（バックグラウンド）
    └── pr-creator（バックグラウンド）
```

## セッション管理

オーケストレーションでは `.orchestrator/` ディレクトリ配下のセッションフォルダを使用してエージェント間で情報を共有する：

```
.orchestrator/
├── templates/                    # 共通テンプレート
├── scripts/                      # 初期化スクリプト
├── {連番}-{feature名}/           # セッションフォルダ（例: 0001-user-auth）
│   ├── explorer/
│   │   └── result.md
│   ├── planner/
│   │   ├── plan.md
│   │   └── tasks.md
│   ├── plan-reviewer/
│   │   └── review-{round}.md
│   ├── task-{id}/
│   │   ├── implementer/
│   │   │   └── result-{round}.md
│   │   ├── test-runner/
│   │   │   └── result-{round}.md
│   │   ├── linter/
│   │   │   └── result-{round}.md
│   │   ├── code-reviewer/
│   │   │   └── review-{round}.md
│   │   ├── refactorer/
│   │   │   └── result-{round}.md
│   │   ├── debugger/
│   │   │   └── report-{round}.md
│   │   └── task-manager/
│   │       └── lifecycle.md
│   ├── test-runner/              # Phase 3
│   │   └── result-{round}.md
│   ├── linter/
│   │   └── result-{round}.md
│   ├── debugger/
│   │   └── report-{round}.md
│   ├── security-scanner/
│   │   └── result.md
│   ├── committer/
│   │   └── result.md
│   └── pr-creator/
│       └── result.md
```

## サブエージェント起動方法

**重要**: Copilot ではツール名を明示的に指定しないとサブエージェントを起動しない。

```
#tool:agent/runSubagent を使って探索処理をサブエージェントで実行してください。

- prompt: "タスク: {ユーザーのタスク}"
- description: "Explorer起動"
- agentName: explorer
```

### 前提条件（VS Code）
- `chat.customAgentInSubagent.enabled: true` が必要
- Orchestrator の `tools` を省略して全ツールを有効にする（親のツール設定がサブエージェントに継承されるため）

## エージェント起動パターン

### 並列起動（依存関係なし）

```
Phase 1: explorer → planner を直列でバックグラウンド起動
Phase 2: blockedBy なしのタスクに対する implementer を同時にバックグラウンド起動
Phase 3: test-runner + linter を同時にバックグラウンド起動
```

### 直列起動（依存関係あり）

```
Phase 1 内: explorer → planner（探索結果を計画に反映）
Phase 1 → Phase 2: 計画完了後に実装開始
Phase 2 内: implementer → test-runner + linter → refactorer → code-reviewer → task-manager
Phase 2 内: blockedBy のあるタスクは前提タスクの完了を待って起動
Phase 3 → Phase 4: テスト成功後にコミット
```

### Phase 2 の実装ループ（Orchestrator が直接制御）

```
while (pendingタスクが残っている):
  1. タスク一覧でブロック解除済みの pending タスクを取得
  2. 各タスクに対して以下を Orchestrator が直接実行:
     a. implementer を起動
     b. implementer 完了後、test-runner + linter を並列起動（TDD検証）
     c. テスト/Lint 失敗 → implementer 再起動（Step a に戻る、リトライ回数に含む）
     d. テスト/Lint 成功後、refactorer を起動
     e. refactorer 完了後、code-reviewer を起動
     f. code-reviewer 完了後、task-manager を起動（判定のみ）
     g. task-manager の判定:
        - completed → タスク完了、次へ
        - rejected → implementer 再起動（最大2回リトライ）
  3. 独立タスクは implementer を並列起動し、完了次第即座に次のステップへ
  4. 新たにブロック解除されたタスクがあれば 1 に戻る
```

## コンテキストの渡し方（パス渡し方式）

各サブエージェントはセッションフォルダ内の所定パスに結果を書き出す。Orchestrator はファイル内容をプロンプトに含めず、パスだけを渡す。各エージェントが自分で読み込む。

### 起動例

```
#tool:agent/runSubagent を使って実装処理をサブエージェントで実行してください。

- prompt: |
    セッションパス: .orchestrator/{SESSION_ID}
    以下の1つのタスクのみを実装してください。
    - タスクID: {taskId}
    - 件名: {subject}
    - 説明: {description}
    - 完了条件: {completionCriteria}
    - 計画: {SESSION_DIR}/planner/plan.md
    - 探索結果: {SESSION_DIR}/explorer/result.md
- description: "Implementer起動"
- agentName: implementer
```

### 並列起動例（2タスク同時処理）

```
# タスク1を処理
#tool:agent/runSubagent を使って実装処理をサブエージェントで実行してください。
- prompt: |
    セッションパス: .orchestrator/{SESSION_ID}
    以下の1つのタスクのみを実装してください。
    - タスクID: 1
    - 件名: ...
- description: "Implementer起動(タスク1)"
- agentName: implementer

# タスク2を同時に処理
#tool:agent/runSubagent を使って実装処理をサブエージェントで実行してください。
- prompt: |
    セッションパス: .orchestrator/{SESSION_ID}
    以下の1つのタスクのみを実装してください。
    - タスクID: 2
    - 件名: ...
- description: "Implementer起動(タスク2)"
- agentName: implementer
```

## プロジェクトタイプ検出

テスト・Lintコマンドを自動検出するロジック：

```
1. package.json が存在する場合:
   - test: {pm} run test
   - lint: {pm} run lint

2. Cargo.toml が存在する場合:
   - test: cargo test
   - lint: cargo clippy

3. pyproject.toml が存在する場合:
   - test: pytest
   - lint: ruff check .

4. go.mod が存在する場合:
   - test: go test ./...
   - lint: golangci-lint run
```

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: URL取得、コード検索、ファイル内容の調査など、情報収集に類する作業はすべて Explorer に委譲すること
- **ユーザーが URL（GitHub Issue、仕様書リンク等）を提示した場合**: その URL を含めて Explorer のプロンプトに渡し、Explorer に取得・分析させること。Orchestrator 自身で内容を確認してはならない
- **Orchestrator の役割は指揮・監視・報告のみ**: エージェントの起動、進捗の監視、結果のユーザーへの報告に専念すること
- **サブエージェントからサブエージェントは呼び出せない**: Copilot の制約により、全エージェントの起動は Orchestrator が直接行う

## オーケストレーターの責務

1. **タスク受付**: ユーザーからの要求を受け取る
2. **セッション初期化**: `init-session.sh` でセッションフォルダを作成
3. **タスク管理**: Plannerが作成したタスクの依存関係を監視し、実行順序を制御
4. **エージェント起動**: ブロック解除済みタスクに対して適切なエージェントを直接起動
5. **進捗監視**: バックグラウンドエージェントの出力を監視し、タスク完了時に次のブロック解除を確認
6. **結果統合**: 各エージェントの結果を統合してユーザーに報告
7. **エラーハンドリング**: 失敗時のリトライや代替処理の提案

## エラーハンドリング

### エージェントがタイムアウトした場合

1. タイムアウトを検出
2. ユーザーに状況を報告
3. 「継続して待つ」「中断する」の選択肢を提示

### エージェントがエラーで終了した場合

1. エラー内容を確認
2. ユーザーにエラー内容を報告
3. 可能であれば修正方法を提案
4. 「リトライする」「手動で修正する」の選択肢を提示

### テストやLintが失敗した場合

1. 失敗内容をユーザーに報告
2. debugger を起動して原因分析・修正
3. 修正後に test-runner と linter を再実行（最大10回リトライ）
