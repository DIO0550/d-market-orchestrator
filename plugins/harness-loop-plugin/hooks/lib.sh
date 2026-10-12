# shellcheck shell=bash
# harness-loop-plugin のフックが共通で使う関数。各フックから source する。

RUN_BASE=".plugin-workspace/.harness"

# jq が無いとフックは何も判定できない。黙って素通りすると、ガードが効いていないことに
# 誰も気づけないので、警告を出してから素通りする。
# @returns jq があれば 0、無ければ警告を出力して 1
require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf '%s\n' '{"systemMessage":"[harness-loop-plugin] jq が見つからないため、フェーズのガード・目標の検査・PR のゲート・続行の促しが動いていません。jq をインストールしてください。"}'
  return 1
}

# 標準入力のフック入力 JSON を読み、HOOK_INPUT / HOOK_SESSION_ID / HOOK_TOOL を設定して
# リポジトリのルートへ移る。run フォルダはスキルがリポジトリのルート（git rev-parse --show-toplevel）に
# 作るので、相対パスの基準を揃える。
hook_read_input() {
  HOOK_INPUT=$(cat)
  HOOK_SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty')
  HOOK_TOOL=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // empty')
  local dir root
  dir=${CLAUDE_PROJECT_DIR:-$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty')}
  [ -n "$dir" ] && [ -d "$dir" ] || return 0
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")
  cd "$root" || return 1
}

# セッションに紐づく run フォルダのうち、番号が最大のものを探す。
# 同じセッションで run を作り直したときに、古い run の STATE に反応し続けないため。
# @param $1 セッション ID
# @returns 見つかれば「run フォルダ<TAB>STATE」を出力して 0、無ければ 1
latest_session_run() {
  local sid=$1 dir
  for dir in $(ls -1d "$RUN_BASE"/[0-9][0-9][0-9]-*/ 2>/dev/null | sort -r); do
    [ -f "${dir}SESSION" ] || continue
    [ -f "${dir}STATE" ] || continue
    [ "$(tr -d '[:space:]' < "${dir}SESSION")" = "$sid" ] || continue
    printf '%s\t%s\n' "${dir%/}" "$(tr -d '[:space:]' < "${dir}STATE")"
    return 0
  done
  return 1
}

# セッションの最新の run の STATE が、指定した値のどれかであるかを判定する。
# @param $1 セッション ID
# @param $2.. 対象にする STATE の値
# @returns 当たれば「run フォルダ<TAB>STATE」を出力して 0、当たらなければ 1
find_session_run() {
  local sid=$1 run state wanted
  shift
  run=$(latest_session_run "$sid") || return 1
  state=${run#*$'\t'}
  for wanted in "$@"; do
    if [ "$state" = "$wanted" ]; then
      printf '%s\n' "$run"
      return 0
    fi
  done
  return 1
}

# パスが run フォルダの置き場（.plugin-workspace/.harness/）の中かを判定する。
# 絶対パス・相対パスのどちらも受け取る。.. で外へ抜けるパスは中とみなさない。
is_run_path() {
  case "/$1/" in
    */../*) return 1 ;;
  esac
  case "$1" in
    "$RUN_BASE"/* | */"$RUN_BASE"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# goal.md の完了条件のうち、未達（行頭 □）の行を出力する。
# @param $1 goal.md のパス
unmet_criteria() {
  grep -E '^[[:space:]]*-[[:space:]]*□[[:space:]]*C-[0-9]+' "$1" || true
}
