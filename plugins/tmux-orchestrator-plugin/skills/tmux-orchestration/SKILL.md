---
name: tmux-orchestration
description: "tmuxセッションを使ってタスクを専門エージェントに分散し、複数のAI CLIプロセスとして並列実行するオーケストレーションワークフロー。/tmux-orchestrate コマンド実行時、「tmuxでオーケストレーション」「tmuxで並列実行」、「セッション確認」「セッション破棄」、「tmuxエージェント作成」「tmuxオーケストレーターにエージェント追加」などのリクエスト時に使用。"
disable-model-invocation: true
---

# tmux Orchestration Skill

tmuxセッションで複数のAI CLIエージェントを並列起動し、タスクを分散実行するオーケストレーションワークフロー。
セッションのライフサイクル管理、エージェント指示ファイルの作成もこのスキルで行う。

## トリガー

- `/tmux-orchestrate` コマンドが実行されたとき
- ユーザーが「tmuxでオーケストレーション」「tmuxで並列実行」と指示したとき
- ユーザーが「テスト実行して」「Lint実行して」「コミットして」「PR作って」と指示したとき
- ユーザーが「セッション確認して」「セッション状態を見せて」「セッション破棄して」と指示したとき
- ユーザーが「tmuxエージェント作成」「tmuxオーケストレーターにエージェント追加」と指示したとき

---

# Part 1: オーケストレーション ワークフロー

## ワークフロー概要

```
[Phase 0: 初期化（Launcher 委譲）] ─────────────
    │
    ├── Launcher プロンプト生成（SESSION_ID, PARENT_PANE）
    ├── tmux-agent-launch.sh で Launcher 起動
    ├── [AGENT_COMPLETE] launcher done 受信
    └── .config/ から TMUX_SESSION, PARENT_PANE, cli-assignments を取得
    │
[Phase 1: 探索・計画] ──────────────────────────
    │
    ├── explorer プロンプト生成 → tmux-agent-launch.sh で起動
    │   └── 関連ファイルを探索
    │
    ▼ ([AGENT_COMPLETE] メッセージ受信で完了検知)
    │
    ├── planner プロンプト生成 → tmux-agent-launch.sh で起動
    │   └── 探索結果を基に実装計画を作成
    │       planner 内部（ミニオーケストレーター）:
    │         1. plan-reviewer 起動 → スペシャリスト4名を並列起動 → 統合レビュー
    │         2. Approved → .done に "done" を書き出し
    │         3. Needs Revision → レビュー結果を読んで修正 → plan-reviewer 再起動（最大2回）
    │         4. Rejected → .done に "rejected" を書き出し
    │
    ▼ ([AGENT_COMPLETE] 受信 → .done の状態値で分岐: done → Phase 2 / rejected → ユーザーに報告)
    │
[Phase 2: 実装（タスクごと）] ─────────────────
    │
    ├── check-dependencies.sh でブロック解除済みタスクを取得
    ├── 各タスクについて:
    │   ├── init-task.sh でタスクディレクトリ作成
    │   ├── task-manager プロンプト生成
    │   └── tmux-agent-launch.sh で起動（独立タスクは並列）
    │
    │   task-manager 内部（Task ツールでサブエージェント実行、ペイン増加なし）:
    │     1. implementer 起動（Task ツール） → 実装
    │     2. test-runner + linter 並列起動（Task ツール） → テスト・Lint
    │     3. code-reviewer 起動（Task ツール） → レビュー
    │     4. refactorer 起動（Task ツール） → コード改善（推奨対応時）
    │     5. completed/rejected 判定 → .done に状態値を書き出し
    │     6. rejected → implementer 再起動（最大2回）
    │
    ├── [AGENT_COMPLETE] メッセージ受信で各 task-manager の完了を検知
    ├── 各 task-manager の .done の状態値を確認（completed / rejected）
    ├── 新たにブロック解除されたタスクがあれば繰り返し
    │
    ▼ (全タスク completed → 結果をユーザーに報告 ※結果ファイルは読まない)
    │
[Phase 3: 検証] ─────────────── 自動実行
    │
    ├── test-runner + linter を並列で tmux ペインに起動
    ├── .done の状態値で PASS/FAIL を確認
    ├── FAIL 時 → debugger 起動 → 再実行（最大10回）
    │
    ▼ (全 PASS → 検証結果をユーザーに報告)
    │
    ★ 自動実行停止
    │
[Phase 4: Git操作] ──────────── ユーザー指示で実行
    │
    ├── committer を tmux ペインに起動
    └── pr-creator を tmux ペインに起動
```

## 中間ファイル

tmux版ではファイルベースIPCを使用。`.orchestrator/` ディレクトリ構成:

| ディレクトリ | 内容 | 用途 |
|------------|------|------|
| `.orchestrator/` | `team-config.json` | チーム名・メンバー名設定（プロジェクト単位、任意） |
| `.config/` | `cli-assignments.json` | エージェント→CLI割り当て |
| `.status/` | `{agent}.done`, `{agent}.exit` | 完了マーカー（状態値含む）・終了コード |
| `.prompts/` | `{agent}-prompt.md` | CLIに渡すプロンプトファイル |
| `.deps/` | `tasks.json` | タスク依存グラフ |
| `{agent}/` | `result.md`, `plan.md` 等 | エージェント結果出力 |

## スクリプトパス

スクリプトはこのスキルの `references/scripts/` に配置されている（`.orchestrator/scripts/` へのコピーは不要）。

オーケストレーターは起動時に [tmux-agent-launch.sh](references/scripts/tmux-agent-launch.sh) のパスからディレクトリを取得し、`SCRIPTS_DIR` として保持する。Launcher やエージェントのプロンプト生成時に `{SCRIPTS_DIR}` プレースホルダを実パスに置換する。

以降のコード例では `$SCRIPTS_DIR` を使用する。

## エージェント起動パターン

### tmux ペインでの起動

```bash
# 1. プロンプトファイルを生成
# .orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md に書き出す

# 2. tmux ペインでエージェント起動
bash $SCRIPTS_DIR/tmux-agent-launch.sh \
  "{TMUX_SESSION}" "explorer" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/explorer-prompt.md" \
  ".orchestrator/{SESSION_ID}" "$PARENT_PANE"

# 3. エージェント完了時、オーケストレーターの入力に以下のメッセージが届く:
#    [AGENT_COMPLETE] explorer done
# 4. .done ファイルの状態値を確認して次のアクションを判断
```

> `{TMUX_SESSION}` = `tmux-session-create.sh` が作成した実際のセッション名（例: `Alpha-0003-xxx`）
> `$PARENT_PANE` = オーケストレーター自身のペインID（セッション初期化時に取得）

### 並列起動（依存関係なし）

```bash
# test-runner と linter を同時起動
bash $SCRIPTS_DIR/tmux-agent-launch.sh \
  "{TMUX_SESSION}" "test-runner" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/test-runner-prompt.md" \
  ".orchestrator/{SESSION_ID}" "$PARENT_PANE"

bash $SCRIPTS_DIR/tmux-agent-launch.sh \
  "{TMUX_SESSION}" "linter" "claude" \
  ".orchestrator/{SESSION_ID}/.prompts/linter-prompt.md" \
  ".orchestrator/{SESSION_ID}" "$PARENT_PANE"

# 各エージェント完了時、オーケストレーターの入力に以下のメッセージが届く:
#   [AGENT_COMPLETE] test-runner PASS
#   [AGENT_COMPLETE] linter PASS
# .done ファイルの状態値を確認して次のアクションを判断
```

### 依存関係のあるタスク起動

```bash
# 実行可能なタスクを取得
READY_TASKS=$(bash $SCRIPTS_DIR/check-dependencies.sh \
  ".orchestrator/{SESSION_ID}")

# 各タスクを起動
for TASK_ID in $READY_TASKS; do
  bash $SCRIPTS_DIR/init-task.sh \
    ".orchestrator/{SESSION_ID}" "$TASK_ID"

  # プロンプト生成してtmux起動
  bash $SCRIPTS_DIR/tmux-agent-launch.sh \
    "{TMUX_SESSION}" "task-${TASK_ID}-task-manager" "claude" \
    ".orchestrator/{SESSION_ID}/.prompts/task-${TASK_ID}-task-manager-prompt.md" \
    ".orchestrator/{SESSION_ID}" "$PARENT_PANE"
done

# 各 task-manager 完了時、オーケストレーターの入力に以下のメッセージが届く:
#   [AGENT_COMPLETE] task-1-task-manager completed
#   [AGENT_COMPLETE] task-2-task-manager completed
```

## セッション初期化（Launcher 委譲）

セッション構築はすべて **Launcher エージェント** に委譲する。

### Launcher 起動手順

1. セッション ID を生成:
   ```bash
   NEXT_ID=$(printf "%04d" $(($(ls -d .orchestrator/????-* 2>/dev/null | sed 's/.*\///' | cut -d'-' -f1 | sort -n | tail -1 || echo 0) + 1)))
   FEATURE_NAME="{タスクから生成した英小文字ハイフン区切り名}"
   SESSION_ID="${NEXT_ID}-${FEATURE_NAME}"
   ```

2. Launcher プロンプトディレクトリを作成:
   ```bash
   mkdir -p .orchestrator/${SESSION_ID}/.prompts
   mkdir -p .orchestrator/${SESSION_ID}/.status
   ```

3. [orchestration-launcher-prompt.md](references/templates/orchestration-launcher-prompt.md) を Read し、パラメータ（SESSION_ID, PARENT_PANE）を埋め込んで `.orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md` に Write する

4. 自身のペイン ID を取得:
   ```bash
   PARENT_PANE=$(tmux display-message -p '#{pane_id}')
   ```

5. Launcher を起動:
   ```bash
   bash $SCRIPTS_DIR/tmux-agent-launch.sh \
     "$(tmux display-message -p '#{session_name}')" "launcher" "claude" \
     ".orchestrator/${SESSION_ID}/.prompts/launcher-prompt.md" \
     ".orchestrator/${SESSION_ID}" "$PARENT_PANE"
   ```

6. 「Launcher を起動しました。完了通知を待機中...」と出力して **ターンを終了する**

7. `[AGENT_COMPLETE] launcher done` を受信したら:
   - `.orchestrator/${SESSION_ID}/.config/tmux-session.txt` を Read して TMUX_SESSION を取得
   - `.orchestrator/${SESSION_ID}/.config/parent-pane.txt` を Read して PARENT_PANE を確認
   - Phase 1 へ進む

8. `[AGENT_COMPLETE] launcher error` の場合:
   - `.orchestrator/${SESSION_ID}/launcher/error.md` を Read してエラー内容を確認
   - ユーザーにエラーを報告

## セッション管理

### セッション監視

```bash
# ステータスモニターを起動（control ウィンドウで実行）
bash $SCRIPTS_DIR/tmux-status-monitor.sh ".orchestrator/{SESSION_ID}"
```

### セッション破棄

```bash
# tmuxセッションを破棄
bash $SCRIPTS_DIR/tmux-session-destroy.sh "{TMUX_SESSION}"
```

### 結果収集

```bash
# 全エージェントの結果をサマリーファイルに集約
bash $SCRIPTS_DIR/tmux-result-collector.sh ".orchestrator/{SESSION_ID}"
```

### セッション一覧の確認

```bash
# 全オーケストレーションセッションを表示
tmux ls 2>/dev/null | grep "^orch-"

# セッションディレクトリの一覧
ls -d .orchestrator/????-* 2>/dev/null
```

## オーケストレーターの制約（厳守）

- **自分で調査・探索を行わない**: 情報収集はすべて Explorer に委譲
- **ユーザーが URL を提示した場合**: Explorer のプロンプトに含めて委譲
- **Orchestrator の役割は指揮・監視・報告のみ**: tmux コマンドによるエージェント起動、.status/ の監視、結果のユーザーへの報告に専念
- **結果ファイルを Read しない**: 分岐判断は `.status/{agent}.done` の状態値のみで行う。plan.md, lifecycle.md, review.md 等の中身は読まない
- **ポーリング禁止**: Bash の sleep ループで `.done` や `.ready` ファイルを待機してはならない。エージェント完了は `[AGENT_COMPLETE]` プッシュ通知で検知する
- **自律実行**: Phase 1〜3 はユーザー確認なしで自動完了

## エラーハンドリング

### エージェントがタイムアウトした場合

1. `[AGENT_COMPLETE]` メッセージが一定時間届かない
2. ユーザーに状況を報告
3. 「継続して待つ」「中断する」の選択肢を提示

### エージェントがエラーで終了した場合

1. `.exit` ファイルの終了コードを確認
2. ユーザーにエラー内容を報告
3. 「リトライする」「手動で修正する」の選択肢を提示

### リトライ時の手順

1. 既存のマーカーファイルを削除:
   ```bash
   rm -f .orchestrator/{SESSION_ID}/.status/{agent}.done
   rm -f .orchestrator/{SESSION_ID}/.status/{agent}.exit
   ```
2. 新しいプロンプトファイルを生成（エラー情報を含める）
3. `tmux-agent-launch.sh` で再起動（`$PARENT_PANE` を第6引数に含める）

---

# Part 2: エージェント セットアップ

新規プロジェクトに tmux オーケストレーション環境をセットアップする手順。

## Step 1: ターゲット CLI 確認

まずどのCLIツール向けかを確認:

| CLI ツール | エージェント形式 | 配置先 | 実行方法 |
|-----------|----------------|--------|---------|
| Claude Code | YAML + Markdown | `.claude/instructions/` | `claude --permission-mode acceptEdits` (対話モード) |
| GitHub Copilot | YAML + Markdown | `.github/agents/` | `gh copilot suggest` |
| OpenAI Codex | 純粋 Markdown | `AGENTS.md` | `codex --approval-mode full-auto` |
| 汎用 CLI | Markdown | 任意 | CLI固有コマンド |

フォーマット詳細:
- [claude-code.md](references/cli-formats/claude-code.md)
- [github-copilot.md](references/cli-formats/github-copilot.md)
- [openai-codex.md](references/cli-formats/openai-codex.md)
- [generic-cli.md](references/cli-formats/generic-cli.md)

CLIツール間の能力比較: [cli-profiles.md](references/cli-profiles.md)

## Step 2: エージェント選択

[agent-catalog.md](references/agent-catalog.md) を参照し、必要なエージェントを選択。

### プリセット

| プリセット | エージェント | 用途 |
|-----------|-------------|------|
| **Minimal** | Orchestrator, Planner, Implementer | 最小限 |
| **Standard** | + Explorer, Test Runner, Linter, Committer | 一般的 |
| **Full** | 全22種類 | フル機能 |

### 個別選択

**制御**: [Orchestrator](references/instructions/orchestrator.md)

**計画**: [Explorer](references/instructions/planning/explorer.md), [Planner](references/instructions/planning/planner.md), [Plan Reviewer](references/instructions/planning/plan-reviewer.md)

**実装**: [Implementer](references/instructions/implementation/implementer.md), [Task Manager](references/instructions/implementation/task-manager.md)

**レビュー**: [Code Reviewer](references/instructions/review/code-reviewer.md), [Quality Reviewer](references/instructions/review/quality-reviewer.md), [Bug Reviewer](references/instructions/review/bug-reviewer.md), [Performance Reviewer](references/instructions/review/performance-reviewer.md), [Security Reviewer](references/instructions/review/security-reviewer.md), [Plan Quality Reviewer](references/instructions/review/plan-quality-reviewer.md), [Plan Bug Reviewer](references/instructions/review/plan-bug-reviewer.md), [Plan Performance Reviewer](references/instructions/review/plan-performance-reviewer.md), [Plan Security Reviewer](references/instructions/review/plan-security-reviewer.md), [Test Runner](references/instructions/review/test-runner.md), [Linter](references/instructions/review/linter.md), [Security Scanner](references/instructions/review/security-scanner.md)

**修正**: [Debugger](references/instructions/implementation/debugger.md), [Refactorer](references/instructions/implementation/refactorer.md)

**Git**: [Committer](references/instructions/git/committer.md), [PR Creator](references/instructions/git/pr-creator.md)

### モデル選択

| クラス | 記号 | エージェント | 用途 |
|--------|-----|-------------|------|
| 🧠 高性能 | opus相当 | Orchestrator, Planner, Plan Reviewer, Code Reviewer, Debugger | 判断・設計・レビュー |
| ⚡ 中程度 | sonnet相当 | Explorer, Implementer, Task Manager, Refactorer, Security Scanner, Quality Reviewer, Bug Reviewer, Performance Reviewer, Security Reviewer, Plan Quality Reviewer, Plan Bug Reviewer, Plan Performance Reviewer, Plan Security Reviewer | 分析・コード生成 |
| 💨 軽量 | haiku相当 | Test Runner, Linter, Committer, PR Creator | 定型作業・コマンド実行 |

## Step 3: テンプレート参照

各テンプレートには以下が含まれる:
- 指示内容（フロントマター + 本文）
- tmux実行コンテキスト（ファイルベースIPCの使い方）
- 実行手順
- CLI別の注意事項
- 入出力形式
- 完了条件

## Step 4: CLI 別の調整

テンプレートの操作をターゲットCLIの形式に変換する。

詳細は [cli-profiles.md](references/cli-profiles.md) を参照:
- CLI別の起動コマンド
- プロンプト渡し方式
- 自律実行モードの設定

## Step 5: 指示ファイルの生成

### 配置先

| CLI ツール | ディレクトリ |
|-----------|-------------|
| Claude Code | `plugins/.../instructions/{name}.md` または `.claude/instructions/{name}.md` |
| Copilot | `.github/agents/{name}.agent.md` |
| Codex | `{name}/AGENTS.md` または ルート追記 |

## エージェント間の結果受け渡し

各エージェントはセッションフォルダ内の所定パスに結果を書き出す。Orchestrator はファイル内容をプロンプトに含めず、パスだけをプロンプトファイルに記載する。各エージェントが自分で Read する。

```
.orchestrator/
├── {連番}-{feature名}/          # セッションフォルダ
│   ├── .config/                 # ランタイム設定
│   │   └── cli-assignments.json # エージェント→CLI割り当て
│   ├── .status/                 # 完了マーカー
│   │   ├── {agent}.done         # 完了時にtouch
│   │   └── {agent}.exit         # 終了コード記録
│   ├── .prompts/                # CLIに渡すプロンプトファイル
│   │   └── {agent}-prompt.md
│   ├── .deps/                   # 依存関係管理
│   │   └── tasks.json
│   ├── explorer/
│   │   └── result.md
│   ├── planner/
│   │   ├── plan.md
│   │   └── tasks.md
│   ├── plan-reviewer/
│   │   ├── review-{round}.md
│   │   ├── quality-review-{round}.md
│   │   ├── bug-review-{round}.md
│   │   ├── performance-review-{round}.md
│   │   └── security-review-{round}.md
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
│   ├── test-runner/
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

## Step 6: 設定の配置

スクリプトはスキルの `references/scripts/` から直接実行される（コピー不要）。

出力フォーマットテンプレートはスキルの `references/templates/` にある。オーケストレーターがプロンプト生成時にテンプレート内容を読み込み、エージェントのプロンプトに直接埋め込む。

CLI 割り当てやチーム設定のカスタマイズは `/tmux-config` で行う。
詳細: [tmux-orchestrator-config スキル](../tmux-orchestrator-config/SKILL.md)

## チーム設定のカスタマイズ（任意）

`.orchestrator/team-config.json` を作成すると、チーム名やメンバー名をカスタマイズできる。
このファイルがなくても全て従来通り動作する（完全後方互換）。

```json
{
  "team_name": "Alpha",
  "members": {
    "orchestrator": { "name": "Commander", "personality": "冷静沈着なリーダー" },
    "explorer": { "name": "Scout", "personality": "好奇心旺盛で何でも調べたがる" },
    "planner": { "name": "Architect", "personality": "慎重で論理的" },
    "plan-reviewer": { "name": "Critic" },
    "plan-quality-reviewer": { "name": "Plan Stylist" },
    "plan-bug-reviewer": { "name": "Plan Detective" },
    "plan-performance-reviewer": { "name": "Plan Speedster" },
    "plan-security-reviewer": { "name": "Plan Sentinel" },
    "implementer": { "name": "Builder", "personality": "職人気質で実直" },
    "task-manager": { "name": "Captain" },
    "code-reviewer": { "name": "Inspector" },
    "quality-reviewer": { "name": "Stylist" },
    "bug-reviewer": { "name": "Detective" },
    "performance-reviewer": { "name": "Speedster" },
    "security-reviewer": { "name": "Sentinel" },
    "test-runner": { "name": "Tester" },
    "linter": { "name": "Checker" },
    "security-scanner": { "name": "Guardian" },
    "debugger": { "name": "Medic", "personality": "冷静な分析家" },
    "refactorer": { "name": "Polisher" },
    "committer": { "name": "Recorder" },
    "pr-creator": { "name": "Messenger" }
  }
}
```

各メンバーのフィールドはすべて任意。`name` のみでも、`personality` 付きでも動作する。

### 反映される箇所

| 項目 | デフォルト | カスタマイズ時 |
|------|----------|-------------|
| tmux セッション名 | `orch-{SESSION_ID}` | `{team_name}-{SESSION_ID}` |
| tmux ペインタイトル | `explorer` | `Scout (explorer)` |
| プロンプト冒頭 | `あなたは explorer エージェントです` | `あなたは **Alpha** の **Scout**（explorer）エージェントです` |
| 性格・話し方 | なし | `あなたの性格・話し方: 好奇心旺盛で何でも調べたがる` |
| ステータスモニター | `[RUNNING] explorer` | `[RUNNING] Scout (explorer)` |

### 影響しない箇所

内部識別子・ファイルパス・IPC プロトコルは一切変更されない:
- `.status/explorer.done` — 変わらない
- `explorer/result.md` — 変わらない
- `.prompts/explorer-prompt.md` — 変わらない

## 生成後チェックリスト

- [ ] ターゲットCLIの形式に従っている
- [ ] description にトリガー条件が含まれている
- [ ] model が適切に設定されている（🧠/⚡/💨）
- [ ] tmux実行コンテキストセクションが含まれている
- [ ] CLI別の注意事項セクションが含まれている
- [ ] 入出力フォーマットが一貫している

---

# Part 3: 参照ドキュメント

## アーキテクチャ

- [tmux-architecture.md](references/tmux-architecture.md) - tmuxセッション構成・ペインレイアウト
- [ipc-protocol.md](references/ipc-protocol.md) - ファイルベースIPC仕様
- [session-lifecycle.md](references/session-lifecycle.md) - セッションのライフサイクル
- [dependency-resolution.md](references/dependency-resolution.md) - 依存関係解決の仕組み

## エージェント

- [agent-catalog.md](references/agent-catalog.md) - エージェント一覧・選択ガイド
- [agent-roles.md](references/agent-roles.md) - エージェントの役割定義
- [cli-profiles.md](references/cli-profiles.md) - CLIツール間の能力比較

## テンプレート

- [orchestration-launcher-prompt.md](references/templates/orchestration-launcher-prompt.md) - Launcher エージェント用プロンプトテンプレート

## CLI フォーマット

- [claude-code.md](references/cli-formats/claude-code.md)
- [openai-codex.md](references/cli-formats/openai-codex.md)
- [github-copilot.md](references/cli-formats/github-copilot.md)
- [generic-cli.md](references/cli-formats/generic-cli.md)
