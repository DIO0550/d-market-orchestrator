# shellcheck shell=bash
# spec-orchestrator-plugin のフックが共通で使う関数。各フックから source する。

ORCH_BASE=".plugin-workspace/.orchestrate"

# 標準入力のフック入力 JSON を読み、HOOK_INPUT / HOOK_SESSION_ID / HOOK_TOOL を設定して
# プロジェクトのルートへ移る。run フォルダの相対パスはプロジェクトのルートを基準にしているため。
hook_read_input() {
  HOOK_INPUT=$(cat)
  HOOK_SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty')
  HOOK_TOOL=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // empty')
  local root
  root=${CLAUDE_PROJECT_DIR:-$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty')}
  if [ -n "$root" ] && [ -d "$root" ]; then
    cd "$root" || return 1
  fi
}

# セッションに紐づく run フォルダのうち、STATE が指定した値のどれかであるものを 1 つ探す。
# @param $1 セッション ID
# @param $2.. 対象にする STATE の値
# @returns 見つかれば「run フォルダ<TAB>STATE」を出力して 0、無ければ 1
find_session_run() {
  local sid=$1
  shift
  local dir state wanted
  for dir in "$ORCH_BASE"/[0-9][0-9][0-9]-*/; do
    [ -f "${dir}SESSION" ] || continue
    [ -f "${dir}STATE" ] || continue
    [ "$(tr -d '[:space:]' < "${dir}SESSION")" = "$sid" ] || continue
    state=$(tr -d '[:space:]' < "${dir}STATE")
    for wanted in "$@"; do
      if [ "$state" = "$wanted" ]; then
        printf '%s\t%s\n' "${dir%/}" "$state"
        return 0
      fi
    done
  done
  return 1
}

# パスが run フォルダの置き場（.plugin-workspace/.orchestrate/）の中かを判定する。
# 絶対パス・相対パスのどちらも受け取る。
is_orchestrate_path() {
  case "$1" in
    "$ORCH_BASE"/* | */"$ORCH_BASE"/*) return 0 ;;
    *) return 1 ;;
  esac
}
