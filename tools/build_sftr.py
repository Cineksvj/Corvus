#!/usr/bin/env python3
"""Builds the paste-ready "Steal From The Rich" from src/Steal From The Rich.luau.

Executors cut off very long pastes (live: the 1.30 MB file lost its last lines and
failed with a missing "end"; 1.287 MB still ran). The build drops comments,
indentation and blank lines and keeps everything else byte for byte:

  * the token stream of the output is compared with the source's (must be equal)
  * the output is compiled with luau-compile at -O0, like an executor does
  * the output must stay under MAX_BYTES

Usage: python3 tools/build_sftr.py [--check]   (--check: verify the committed output is up to date)
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src", "Steal From The Rich.luau")
OUT = os.path.join(ROOT, "Steal From The Rich")
MAX_BYTES = 1_100_000

LONG_OPEN = re.compile(r"\[(=*)\[")


def tokens(text):
    """Lua/Luau tokenizer: yields (kind, value, had_newline_before, had_space_before)."""
    i, n = 0, len(text)
    newline = space = False
    while i < n:
        c = text[i]
        if c in " \t\r\f\v":
            space = True
            i += 1
            continue
        if c == "\n":
            newline = True
            i += 1
            continue
        if text.startswith("--", i):
            m = LONG_OPEN.match(text, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = text.find(close, m.end())
                if j < 0:
                    raise SyntaxError("unclosed long comment at %d" % i)
                if "\n" in text[i:j]:
                    newline = True
                i = j + len(close)
            else:
                j = text.find("\n", i)
                i = n if j < 0 else j
            space = True
            continue
        m = LONG_OPEN.match(text, i) if c == "[" else None
        if m:
            close = "]" + m.group(1) + "]"
            j = text.find(close, m.end())
            if j < 0:
                raise SyntaxError("unclosed long string at %d" % i)
            yield ("str", text[i:j + len(close)], newline, space)
            i = j + len(close)
            newline = space = False
            continue
        if c in "\"'`":
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == "\n" and c != "`":
                    raise SyntaxError("newline in string at %d" % j)
                j += 1
            yield ("str", text[i:j + 1], newline, space)
            i = j + 1
            newline = space = False
            continue
        m = re.compile(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(\d[\d_]*\.?[\d_]*|\.\d[\d_]*)([eE][+-]?\d+)?").match(text, i)
        if m and (c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit())):
            yield ("num", m.group(0), newline, space)
            i = m.end()
            newline = space = False
            continue
        m = re.compile(r"[A-Za-z_][A-Za-z0-9_]*").match(text, i)
        if m:
            yield ("name", m.group(0), newline, space)
            i = m.end()
            newline = space = False
            continue
        for op in ("...", "..=", "//=", "==", "~=", "<=", ">=", "..", "::", "->", "+=", "-=", "*=", "/=", "%=", "^=", "//"):
            if text.startswith(op, i):
                yield ("op", op, newline, space)
                i += len(op)
                break
        else:
            yield ("op", c, newline, space)
            i += 1
        newline = space = False


def build(text):
    out = []
    prev = None
    for kind, value, newline, space in tokens(text):
        if prev is not None:
            if newline:
                out.append("\n")
            elif space:
                # a space only where two words or numbers would merge, or the source had one around an operator that could fuse
                word = lambda k: k in ("name", "num")
                if (word(prev[0]) and word(kind)) or (prev[0] == "num" and value.startswith(".")) or (prev[1] in ("-", "[", "..") and value[0] in "-[."):
                    out.append(" ")
                elif prev[0] == "op" and kind == "op":
                    out.append(" ")
        out.append(value)
        prev = (kind, value)
    return "".join(out) + "\n"


def main():
    check = "--check" in sys.argv
    src = open(SRC, encoding="utf-8").read()
    out = build(src)
    a = [(k, v) for k, v, _, _ in tokens(src)]
    b = [(k, v) for k, v, _, _ in tokens(out)]
    if a != b:
        for index, (x, y) in enumerate(zip(a, b)):
            if x != y:
                sys.exit("token mismatch at token %d: %r vs %r" % (index, x, y))
        sys.exit("token count differs: %d vs %d" % (len(a), len(b)))
    size = len(out.encode("utf-8"))
    if size > MAX_BYTES:
        sys.exit("output is %d bytes, over the %d limit" % (size, MAX_BYTES))
    if check:
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if current != out:
            sys.exit("Steal From The Rich is out of date: run python3 tools/build_sftr.py")
    else:
        open(OUT, "w", encoding="utf-8").write(out)
    compiler = os.environ.get("LUAU_COMPILE") or os.path.join(os.path.dirname(os.environ.get("LUAU_BIN", "")), "luau-compile")
    if os.path.isfile(compiler):
        res = subprocess.run([compiler, "--binary", "-O0", OUT], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if res.returncode != 0:
            sys.exit("compile error at -O0:\n" + res.stderr)
        compiled = "compiles at -O0"
    else:
        compiled = "compile check skipped (set LUAU_BIN)"
    print("%s: %d bytes (source %d), %d tokens identical, %s" % (os.path.basename(OUT), size, len(src.encode("utf-8")), len(a), compiled))


if __name__ == "__main__":
    main()
