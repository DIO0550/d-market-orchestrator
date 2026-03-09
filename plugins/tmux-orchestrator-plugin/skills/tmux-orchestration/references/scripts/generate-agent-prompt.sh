#!/bin/bash
# generate-agent-prompt.sh
# task-spec とテンプレートからエージェント用の最終プロンプトファイルを生成する
#
# 使用方法:
#   generate-agent-prompt.sh <agent-name> <task-spec-file> <output-file> <scripts-dir>
#
# 引数:
#   agent-name     - エージェント名（explorer, planner, task-manager, etc.）
#   task-spec-file - task-spec ファイルのパス（オーケストレーターが生成した小さな指示ファイル）
#   output-file    - 生成するプロンプトファイルの出力先パス
#   scripts-dir    - スクリプトディレクトリのパス（テンプレートは ../templates/ に配置）
#
# 動作:
#   1. task-spec ファイルをそのまま出力
#   2. agent-name に基づいて出力フォーマットテンプレートを選択し、末尾に追記
#   3. サブエージェントを起動するエージェントにはサブエージェント用フォーマットも追記
#
# task-spec の書き方:
#   オーケストレーターは agent-prompt.md テンプレートを参考に task-spec を書く。
#   ただし以下のセクションはこのスクリプトが自動追記するため task-spec には含めない:
#   - 「出力フォーマット」セクション
#   - 「サブエージェント用出力フォーマット」セクション
#
# 特殊ケース:
#   - launcher: task-spec をそのまま使用（テンプレート追記なし）

set -euo pipefail

AGENT_NAME="${1:-}"
TASK_SPEC_FILE="${2:-}"
OUTPUT_FILE="${3:-}"
SCRIPTS_DIR="${4:-}"

if [ -z "$AGENT_NAME" ] || [ -z "$TASK_SPEC_FILE" ] || [ -z "$OUTPUT_FILE" ] || [ -z "$SCRIPTS_DIR" ]; then
  echo "Usage: generate-agent-prompt.sh <agent-name> <task-spec-file> <output-file> <scripts-dir>"
  exit 1
fi

if [ ! -f "$TASK_SPEC_FILE" ]; then
  echo "Error: Task spec file not found: $TASK_SPEC_FILE"
  exit 1
fi

TEMPLATES_DIR="$(cd "$(dirname "$SCRIPTS_DIR")" && pwd)/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "Error: Templates directory not found: $TEMPLATES_DIR"
  exit 1
fi

# 出力ディレクトリの作成
mkdir -p "$(dirname "$OUTPUT_FILE")"

# エージェント種別を判定（agent-name からベース種別を抽出）
# 例: "task-1-task-manager" → "task-manager", "explorer" → "explorer"
get_agent_type() {
  local name="$1"
  if [[ "$name" =~ ^task-.*-task-manager$ ]]; then
    echo "task-manager"
  elif [[ "$name" =~ ^task-.*-test-runner$ ]]; then
    echo "test-runner"
  elif [[ "$name" =~ ^task-.*-linter$ ]]; then
    echo "linter"
  elif [[ "$name" =~ ^task-.*-code-reviewer$ ]]; then
    echo "code-reviewer"
  elif [[ "$name" =~ ^task-.*-implementer$ ]]; then
    echo "implementer"
  elif [[ "$name" =~ ^task-.*-refactorer$ ]]; then
    echo "refactorer"
  elif [[ "$name" =~ ^task-.*-debugger$ ]]; then
    echo "debugger"
  elif [[ "$name" =~ ^plan-reviewer- ]]; then
    echo "plan-reviewer-specialist"
  else
    echo "$name"
  fi
}

AGENT_TYPE=$(get_agent_type "$AGENT_NAME")

# launcher は特殊: task-spec をそのまま使用
if [ "$AGENT_TYPE" = "launcher" ]; then
  cp "$TASK_SPEC_FILE" "$OUTPUT_FILE"
  echo "Generated prompt for launcher: $OUTPUT_FILE"
  exit 0
fi

# 出力フォーマットテンプレートのマッピング
get_output_formats() {
  local type="$1"
  case "$type" in
    explorer)          echo "exploration-result.md" ;;
    planner)           echo "implementation-plan.md tasks.md" ;;
    plan-reviewer)     echo "plan-review-result.md" ;;
    plan-reviewer-specialist) echo "plan-specialist-review-result.md" ;;
    task-manager)      echo "task-lifecycle-result.md" ;;
    code-reviewer)     echo "code-review-result.md" ;;
    test-runner)       echo "test-result.md" ;;
    *)                 echo "" ;;
  esac
}

# サブエージェント用出力フォーマットのマッピング
get_sub_agent_formats() {
  local type="$1"
  case "$type" in
    planner)       echo "plan-review-result.md plan-specialist-review-result.md" ;;
    plan-reviewer) echo "plan-specialist-review-result.md" ;;
    task-manager)  echo "code-review-result.md specialist-review-result.md test-result.md" ;;
    code-reviewer) echo "specialist-review-result.md" ;;
    *)             echo "" ;;
  esac
}

OUTPUT_FORMAT_FILES=$(get_output_formats "$AGENT_TYPE")
SUB_AGENT_FORMAT_FILES=$(get_sub_agent_formats "$AGENT_TYPE")

# task-spec をそのまま出力ファイルにコピー
cp "$TASK_SPEC_FILE" "$OUTPUT_FILE"

# 出力フォーマットセクションを追記
if [ -n "$OUTPUT_FORMAT_FILES" ]; then
  {
    echo ""
    echo "## 出力フォーマット"
    echo ""
    echo "以下のフォーマットに従って結果を出力してください:"
    echo ""
    for file in $OUTPUT_FORMAT_FILES; do
      filepath="${TEMPLATES_DIR}/${file}"
      if [ -f "$filepath" ]; then
        cat "$filepath"
        echo ""
      else
        echo "Warning: Template not found: $filepath" >&2
      fi
    done
  } >> "$OUTPUT_FILE"
fi

# サブエージェント用出力フォーマットセクションを追記
if [ -n "$SUB_AGENT_FORMAT_FILES" ]; then
  {
    echo ""
    echo "## サブエージェント用出力フォーマット"
    echo ""
    echo "サブエージェントのプロンプトを生成する際、該当する出力フォーマットを「出力フォーマット」セクションに埋め込んでください:"
    echo ""
    for file in $SUB_AGENT_FORMAT_FILES; do
      filepath="${TEMPLATES_DIR}/${file}"
      if [ -f "$filepath" ]; then
        echo "### ${file}"
        echo ""
        cat "$filepath"
        echo ""
      else
        echo "Warning: Template not found: $filepath" >&2
      fi
    done
  } >> "$OUTPUT_FILE"
fi

echo "Generated prompt for ${AGENT_NAME} (type: ${AGENT_TYPE}): $OUTPUT_FILE"
