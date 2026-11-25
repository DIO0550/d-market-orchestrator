"""Bash のコマンド文字列を、演算子で区切った単純コマンドごとの語の並びに分ける。

bash-write-targets.py と bulk-stage-commands.py が import する。正規表現でコマンド全体を見ると
引用符の中の字面（`grep "git add ."` の `git add .`、`awk '$2 > 5'` の `>`）を誤検出するので、
shlex で引用符を解いてから語の並びとして判定させる。
"""

import shlex

OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", ";;"}


def command_head(command: str) -> str:
    """最初のヒアドキュメントの開きの行までを返す。

    ヒアドキュメントの本文（コミットメッセージや md の引用）はコマンドではないので見ない。
    本文の後ろに続くコマンドも見なくなる（最善努力のガード）。
    """
    head = []
    for line in command.splitlines():
        head.append(line)
        if "<<" in line:
            break
    return "\n".join(head)


def simple_commands(text: str):
    """単純コマンドごとの語の並びのリストを返す。引用符の対応が取れないなら None を返す。"""
    try:
        lexer = shlex.shlex(text.replace("\n", " ; "), posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        tokens = list(lexer)
    except ValueError:
        return None
    commands = []
    current = []
    for tok in tokens:
        if tok in OPERATORS:
            if current:
                commands.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        commands.append(current)
    return commands
