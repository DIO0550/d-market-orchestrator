#!/usr/bin/env python3
"""Bash コマンドのうち、変更をまとめてステージする git を 1 行ずつ出力する。

guard-bulk-stage.sh から呼ぶ。標準入力にコマンドを受け取り、出力が空ならまとめてステージする git は無い。
当てるのは、`git add` の -A / --all / -u / --update と、パス指定の `.` / `./` / `:/` / `*`、
`git commit` の -a / --all（`-am` のように短いオプションをつなげたものを含む）と、パス指定の同じ 4 つ
（`git commit .` は追跡中の変更をまとめて載せる）。
`git add src/` のようなディレクトリの指定は通す（どこまでを 1 つに指定するかは計画のファイルの単位で、
ここでは「指定したものだけ」と「作業ツリー全体」を分けるだけ）。
`sh -c` の文字列の中や、ヒアドキュメントの後ろに続くコマンドまでは追わない（最善努力のガード）。
"""

import sys

from bash_commands import command_head, simple_commands

BULK_ADD_LONG = {"--all", "--update"}
BULK_ADD_SHORT = set("Au")
BULK_PATHSPECS = {".", "./", ":/", "*"}
BULK_COMMIT_LONG = {"--all"}
# git commit の短いオプションのうち、値を取るもの。つなげた中でここに当たったら、残りの字はその値
COMMIT_SHORT_WITH_VALUE = set("mFCct")
# git commit の短いオプションのうち、値を同じ語に続けたときだけ取るもの（`-uall` / `-S<keyid>`）
COMMIT_SHORT_WITH_ATTACHED_VALUE = set("uS")
# git commit の長いオプションのうち、`=` を使わずに次の語を値に取り、その値が `-` で始まる文やパス指定の `.` に
# なりうるもの（ほかの長いオプションの値は作者・日付・コミットなどで、そうならない）
COMMIT_LONG_WITH_VALUE = {"--message"}
# git の大域オプションのうち、次の語を値に取るもの
GIT_GLOBAL_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def main() -> int:
    commands = simple_commands(command_head(sys.stdin.read()))
    if commands is None:
        # 引用符の対応が取れないコマンドは判定できない。止めずに通す（最善努力のガード）
        return 0
    for words in commands:
        if is_bulk_stage(words):
            print(" ".join(words))
    return 0


def git_subcommand(words):
    """単純コマンドが git なら (サブコマンド, その後ろの語) を返す。git でなければ None。"""
    args = list(words)
    while args and "=" in args[0] and not args[0].startswith("-"):
        args = args[1:]
    if not args or args[0].rsplit("/", 1)[-1] != "git":
        return None
    i = 1
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_GLOBAL_WITH_VALUE else 1
    if i >= len(args):
        return None
    return args[i], args[i + 1:]


def is_bulk_stage(words) -> bool:
    found = git_subcommand(words)
    if found is None:
        return False
    sub, rest = found
    if sub == "add":
        return is_bulk_add(rest)
    if sub == "commit":
        return is_bulk_commit(rest)
    return False


def is_bulk_add(rest) -> bool:
    for word in rest:
        if word in BULK_PATHSPECS:
            return True
        if word.startswith("--"):
            if word.split("=", 1)[0] in BULK_ADD_LONG:
                return True
        elif word.startswith("-") and BULK_ADD_SHORT & set(word[1:]):
            return True
    return False


def is_bulk_commit(rest) -> bool:
    i = 0
    while i < len(rest):
        word = rest[i]
        i += 1
        if word in BULK_PATHSPECS:
            return True
        if word.startswith("--"):
            if word in BULK_COMMIT_LONG:
                return True
            if word in COMMIT_LONG_WITH_VALUE:
                i += 1
            continue
        if not word.startswith("-") or len(word) == 1:
            continue
        for pos, char in enumerate(word[1:], start=1):
            if char == "a":
                return True
            if char in COMMIT_SHORT_WITH_VALUE:
                # -m の値が同じ語に続いていなければ、次の語が値
                i += 1 if pos == len(word) - 1 else 0
                break
            if char in COMMIT_SHORT_WITH_ATTACHED_VALUE:
                break
    return False


if __name__ == "__main__":
    sys.exit(main())
