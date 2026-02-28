#!/bin/bash
# notify-parent.sh
# エージェント完了時に親ペインへ排他的に通知を送信する（待ち行列）
#
# 使用方法:
#   notify-parent.sh <session-dir> <agent-name> <parent-pane>
#
# 引数:
#   session-dir   - セッションディレクトリ（.orchestrator/{SESSION_ID}）
#   agent-name    - エージェント名（explorer, planner, etc.）
#   parent-pane   - 通知先の親ペインID
#
# 動作:
#   1. ロックを取得（他のエージェントが送信中なら待機）
#   2. .done ファイルの状態値を読み取り、親ペインに [AGENT_COMPLETE] メッセージを送信
#   3. 親の処理時間を待機（次の通知が割り込まないように）
#   4. ロックを解放
#
# 排他制御:
#   mkdir によるアトミックなロック取得で、複数エージェントの同時送信を防止する。
#   親（Claude Code）が処理中に別の通知が割り込むとフリーズするため、
#   送信後に親の処理完了を待ってからロックを解放する。

set -euo pipefail

SESSION_DIR="${1:-}"
AGENT_NAME="${2:-}"
PARENT_PANE="${3:-}"

if [ -z "$SESSION_DIR" ] || [ -z "$AGENT_NAME" ] || [ -z "$PARENT_PANE" ]; then
  echo "Usage: notify-parent.sh <session-dir> <agent-name> <parent-pane>"
  exit 1
fi

DONE_FILE="${SESSION_DIR}/.status/${AGENT_NAME}.done"
STATUS=$(cat "$DONE_FILE" 2>/dev/null || echo "done")

LOCK_DIR="${SESSION_DIR}/.status/.notify-lock"
LOCK_TIMESTAMP="${LOCK_DIR}/timestamp"
MAX_WAIT=300          # ロック取得の最大待機時間（秒）
STALE_THRESHOLD=60    # これ以上古いロックは失効とみなす（秒）
PROCESS_WAIT=5        # 送信後の親処理待ち時間（秒）

# --- 失効ロックの検出・除去 ---
if [ -d "$LOCK_DIR" ]; then
  LOCK_TIME=$(cat "$LOCK_TIMESTAMP" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  if [ $((NOW - LOCK_TIME)) -gt $STALE_THRESHOLD ]; then
    echo "[${AGENT_NAME}] Removing stale lock (age: $((NOW - LOCK_TIME))s)"
    rm -rf "$LOCK_DIR"
  fi
fi

# --- ロック取得（待ち行列） ---
WAITED=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 1
  WAITED=$((WAITED + 1))
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo "[${AGENT_NAME}] Lock timeout (${MAX_WAIT}s), forcing lock acquisition"
    rm -rf "$LOCK_DIR"
    mkdir -p "$LOCK_DIR" 2>/dev/null || true
    break
  fi
done

# ロックにタイムスタンプを記録（失効検出用）
date +%s > "$LOCK_TIMESTAMP" 2>/dev/null || true

echo "[${AGENT_NAME}] Lock acquired, sending notification..."

# --- 通知送信 ---
# テキストを -l（リテラル）で送信（括弧等の特殊文字の誤解釈を防止）
tmux send-keys -l -t "$PARENT_PANE" "[AGENT_COMPLETE] ${AGENT_NAME} ${STATUS}"

# Enter をリトライ付きで送信
# Claude Code が処理中・描画中だと Enter が効かないことがあるため、
# capture-pane でメッセージが入力行に残っているか検証し、残っていたら再送する
MAX_ENTER_RETRIES=5
for i in $(seq 1 $MAX_ENTER_RETRIES); do
  sleep 1
  tmux send-keys -t "$PARENT_PANE" Enter
  sleep 1

  # 親ペインの末尾数行をキャプチャし、メッセージがまだ入力行に残っているか確認
  PANE_TAIL=$(tmux capture-pane -t "$PARENT_PANE" -p -S -5 2>/dev/null || true)
  if ! echo "$PANE_TAIL" | grep -qF "[AGENT_COMPLETE] ${AGENT_NAME}"; then
    # メッセージが表示から消えた = submit されたと判断
    echo "[${AGENT_NAME}] Notification submitted (attempt ${i})"
    break
  fi

  if [ "$i" -lt "$MAX_ENTER_RETRIES" ]; then
    echo "[${AGENT_NAME}] Enter not registered, retrying (${i}/${MAX_ENTER_RETRIES})..."
  else
    echo "[${AGENT_NAME}] Enter retries exhausted (${MAX_ENTER_RETRIES}), proceeding anyway"
  fi
done

echo "[${AGENT_NAME}] Notification sent to pane ${PARENT_PANE}: ${STATUS}"

# --- 親の処理待ち ---
# 親（Claude Code）が [AGENT_COMPLETE] メッセージを受信・処理する時間を確保する。
# この間にロックを保持することで、次の通知が割り込まない。
sleep "$PROCESS_WAIT"

# --- ロック解放 ---
rm -rf "$LOCK_DIR" 2>/dev/null || true

echo "[${AGENT_NAME}] Lock released"
