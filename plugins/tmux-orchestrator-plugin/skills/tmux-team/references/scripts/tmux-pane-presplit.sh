#!/bin/bash
# tmux-pane-presplit.sh
# チームメンバー用にN個のペインを事前分割し、各ペインでCLIを起動する
#
# 使用方法:
#   tmux-pane-presplit.sh <session> <pane-count> <session-dir> [cli-tool] [working-dir]
#
# 引数:
#   session     - tmuxセッション名
#   pane-count  - 作成するペイン数（1〜8）
#   session-dir - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   cli-tool    - CLIツール名（デフォルト: claude）
#   working-dir - 作業ディレクトリ（デフォルト: カレントディレクトリ）
#
# 動作:
#   1. pane-count 個のペインを split-window で作成
#   2. 各ペインにタイトルを設定（team-config.json からカスタム名を取得）
#   3. tiled レイアウトで均等配置
#   4. 各ペインで CLI をインタラクティブモードで起動
#   5. .config/pane-registry.json にペインID→メンバー名の対応を記録
#
# 出力:
#   PANE_REGISTRY={pane-registry.json のパス}
#   member-{N} launched in {pane-id} using {cli-tool}
#   ...

set -euo pipefail

SESSION="${1:-}"
PANE_COUNT="${2:-}"
SESSION_DIR="${3:-}"
CLI_TOOL="${4:-claude}"
WORKING_DIR="${5:-$(pwd)}"

if [ -z "$SESSION" ] || [ -z "$PANE_COUNT" ] || [ -z "$SESSION_DIR" ]; then
  echo "Usage: tmux-pane-presplit.sh <session> <pane-count> <session-dir> [cli-tool] [working-dir]"
  exit 1
fi

if ! [[ "$PANE_COUNT" =~ ^[0-9]+$ ]] || [ "$PANE_COUNT" -lt 1 ] || [ "$PANE_COUNT" -gt 8 ]; then
  echo "Error: pane-count must be a number between 1 and 8"
  exit 1
fi

# ステータス・設定ディレクトリの確認
mkdir -p "${SESSION_DIR}/.config"
mkdir -p "${SESSION_DIR}/.status"

# チーム設定・CLI割り当て設定のパス
TEAM_CONFIG=".orchestrator/team-config.json"
CLI_ASSIGNMENTS="${SESSION_DIR}/.config/cli-assignments.json"

# チーム設定をループ外で一度だけ読み込む
HAS_TEAM_CONFIG=false
TEAM_NAME=""
if [ -f "$TEAM_CONFIG" ] && command -v jq &>/dev/null; then
  HAS_TEAM_CONFIG=true
  TEAM_NAME=$(jq -r '.team_name // empty' "$TEAM_CONFIG" 2>/dev/null)
fi

# pane-registry.json の初期化
REGISTRY_FILE="${SESSION_DIR}/.config/pane-registry.json"
echo '{' > "$REGISTRY_FILE"
echo '  "panes": {' >> "$REGISTRY_FILE"

for i in $(seq 1 "$PANE_COUNT"); do
  MEMBER_NAME="member-${i}"

  # ペインを分割（フォーカスを移動しない）
  TARGET_PANE=$(tmux split-window -t "${SESSION}" -v -d -P -F '#{pane_id}')
  tmux select-layout -t "${SESSION}" tiled

  # チーム設定からメンバー情報を一括取得
  DISPLAY_NAME="$MEMBER_NAME"
  SYSTEM_PROMPT="あなたは ${MEMBER_NAME} です。"
  if [ "$HAS_TEAM_CONFIG" = true ]; then
    MEMBER_CUSTOM_NAME=$(jq -r ".members.\"${MEMBER_NAME}\".name // empty" "$TEAM_CONFIG" 2>/dev/null)
    MEMBER_PERSONALITY=$(jq -r ".members.\"${MEMBER_NAME}\".personality // empty" "$TEAM_CONFIG" 2>/dev/null)

    if [ -n "$MEMBER_CUSTOM_NAME" ]; then
      DISPLAY_NAME="${MEMBER_CUSTOM_NAME} (${MEMBER_NAME})"
      if [ -n "$TEAM_NAME" ]; then
        SYSTEM_PROMPT="あなたは **${TEAM_NAME}** の **${MEMBER_CUSTOM_NAME}**（${MEMBER_NAME}）です。"
      else
        SYSTEM_PROMPT="あなたは **${MEMBER_CUSTOM_NAME}**（${MEMBER_NAME}）です。"
      fi
    fi

    if [ -n "$MEMBER_PERSONALITY" ]; then
      SYSTEM_PROMPT="${SYSTEM_PROMPT} あなたの性格・話し方: ${MEMBER_PERSONALITY}"
    fi
  fi

  # ペインのタイトルを設定
  tmux select-pane -t "$TARGET_PANE" -T "$DISPLAY_NAME"

  # メンバーごとの CLI ツールを決定（claude 以外は非対応のため警告して claude にフォールバック）
  MEMBER_CLI="$CLI_TOOL"
  if [ -f "$CLI_ASSIGNMENTS" ] && command -v jq &>/dev/null; then
    ASSIGNED_CLI=$(jq -r ".assignments.\"${MEMBER_NAME}\" // empty" "$CLI_ASSIGNMENTS" 2>/dev/null)
    if [ -n "$ASSIGNED_CLI" ]; then
      MEMBER_CLI="$ASSIGNED_CLI"
    fi
  fi
  if [ "$MEMBER_CLI" != "claude" ]; then
    echo "Warning: ${MEMBER_CLI} does not support interactive persistent mode. Using claude instead."
    MEMBER_CLI="claude"
  fi

  # ペインで CLI を起動
  tmux send-keys -t "$TARGET_PANE" "cd '${WORKING_DIR}' && claude --permission-mode acceptEdits --append-system-prompt '${SYSTEM_PROMPT}'" C-m

  # pane-registry.json にエントリを追加
  COMMA=""
  if [ "$i" -lt "$PANE_COUNT" ]; then
    COMMA=","
  fi
  cat >> "$REGISTRY_FILE" <<EOF
    "${MEMBER_NAME}": { "pane_id": "${TARGET_PANE}", "cli": "${MEMBER_CLI}" }${COMMA}
EOF

  echo "${MEMBER_NAME} launched in ${TARGET_PANE} using ${MEMBER_CLI}"
done

# pane-registry.json を閉じる
cat >> "$REGISTRY_FILE" <<EOF
  },
  "pane_count": ${PANE_COUNT}
}
EOF

echo "PANE_REGISTRY=${REGISTRY_FILE}"
echo "${PANE_COUNT} panes pre-split and CLI started."
