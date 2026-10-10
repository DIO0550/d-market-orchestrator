#!/usr/bin/env python3
"""Bash コマンドを字句解析し、ファイルを書き換える先のうち許可されていないものを 1 行ずつ出力する。

guard-phase-writes.sh から呼ぶ。標準入力にコマンド、引数に run フォルダの置き場の相対パスを受け取る。
出力が空なら書き換え先はすべて許可されている（または書き換えていない）。

正規表現でコマンド全体を見ると、`grep "=> "` や `awk '$2 > 5'` のような引用符の中の `>` を
書き込みと誤検出し、逆に `echo x >src/a` のような空白無しのリダイレクトを見逃す。そのため
shlex で引用符を解いてから、リダイレクトの先と書き換え系コマンドの対象引数だけを判定する。
`python -c` の中で開くファイルのような、コマンドの中身までは追わない（最善努力のガード）。
"""

import re
import shlex
import sys

OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", ";;"}
REDIRECTS = {">", ">>", ">|", "&>", "&>>"}
# 書き換え系コマンドと、対象になる引数の位置（all = オプション以外すべて / last = 最後の 1 つ）
WRITE_COMMANDS = {
    "rm": "all", "rmdir": "all", "mkdir": "all", "touch": "all", "tee": "all", "truncate": "all",
    "cp": "last", "mv": "last", "install": "last", "ln": "last", "rsync": "last",
}
# 作業ツリーを書き換える git のサブコマンド
GIT_WRITE_SUBCOMMANDS = {"checkout", "restore", "reset", "stash", "clean", "apply", "rm", "mv", "switch", "merge", "rebase", "cherry-pick", "revert", "commit", "add"}
SAFE_DEVICES = {"/dev/null", "/dev/stdout", "/dev/stderr"}


def main() -> int:
    base = sys.argv[1]
    command = sys.stdin.read()
    # ヒアドキュメントの本文は書き込み先ではないので、最初の << の行までだけを見る
    head = []
    for line in command.splitlines():
        head.append(line)
        if "<<" in line:
            break
    text = "\n".join(head)

    tmp_vars = set(re.findall(r"(\w+)=\"?\$\(\s*mktemp", text))
    in_tmp_cwd = re.search(r"\bcd\s+\"?\$\(\s*mktemp", text) is not None

    try:
        lexer = shlex.shlex(text.replace("\n", " ; "), posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        tokens = list(lexer)
    except ValueError:
        # 引用符の対応が取れないコマンドは判定できない。止めずに通す（最善努力のガード）
        return 0

    def allowed(target: str) -> bool:
        if target in SAFE_DEVICES or re.fullmatch(r"&?\d+", target) or target == "-":
            return True
        if "/../" in f"/{target}/":
            return False
        if f"{base}/" in target or target.startswith("/tmp/") or target == "/tmp":
            return True
        m = re.match(r"\$\{?(\w+)", target)
        if m:
            return m.group(1) in tmp_vars or m.group(1) == "TMPDIR"
        return in_tmp_cwd and not target.startswith("/")

    denied = []
    for words in split_commands(tokens):
        for target in write_targets(words):
            if not allowed(target):
                denied.append(target)
    for target in dict.fromkeys(denied):
        print(target)
    return 0


def split_commands(tokens):
    """演算子で区切った単純コマンドごとの語の並びを返す。"""
    current = []
    for tok in tokens:
        if tok in OPERATORS:
            if current:
                yield current
            current = []
        else:
            current.append(tok)
    if current:
        yield current


def write_targets(words):
    """1 つの単純コマンドが書き換える先を返す。リダイレクトはここで取り除いてから引数を見る。"""
    targets = []
    args = []
    i = 0
    while i < len(words):
        w = words[i]
        # 2>file は shlex で "2" ">" "file" に割れる。fd 番号は引数ではない
        is_fd_number = w.isdigit() and i + 1 < len(words) and words[i + 1] in REDIRECTS | {">&", "<"}
        if w in REDIRECTS:
            if i + 1 < len(words):
                targets.append(words[i + 1])
            i += 2
            continue
        if w in {">&", "<", "<<", "<<<", "<&"}:
            i += 2
            continue
        if not is_fd_number:
            args.append(w)
        i += 1

    while args and re.fullmatch(r"\w+=.*", args[0]):
        args = args[1:]
    if not args:
        return targets
    name = args[0].rsplit("/", 1)[-1]
    operands = [a for a in args[1:] if not a.startswith("-")]

    if name == "git":
        sub = next((a for a in args[1:] if not a.startswith("-")), "")
        if sub in GIT_WRITE_SUBCOMMANDS:
            targets.append(f"git {sub}")
    elif name == "sed" and any(a == "-i" or a.startswith("-i") or a == "--in-place" for a in args[1:]):
        targets.extend(operands[-1:])
    elif name in WRITE_COMMANDS and operands:
        targets.extend(operands if WRITE_COMMANDS[name] == "all" else operands[-1:])
    return targets


if __name__ == "__main__":
    sys.exit(main())
