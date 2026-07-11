#!/usr/bin/env python3
"""Minify a Lua source file for embedding: strip comments and collapse whitespace
while preserving the EXACT token stream. Used at BUILD time (see the Makefile) to
shrink the embedded Lua before bin2c; the committed .lua source stays fully
commented and is the single source of truth.

Why this is safe
----------------
The scanner classifies the source into segments: whitespace, comment, string
(short or long-bracket), and code. Minifying:
  * drops comments entirely,
  * collapses each whitespace RUN to a single separator (a newline if the run
    contained one, else a space) -- never to nothing, so two tokens that were
    separated stay separated and two that were adjacent stay adjacent,
  * copies string and code segments verbatim.
So the sequence of (string + code) tokens is provably unchanged. After minifying
we RE-SCAN the output and assert its token list is byte-identical to the input's;
any difference is a bug and we exit non-zero to FAIL THE BUILD. Because the CI
"Validate bundled Lua" gate already proves the source parses, an identical token
stream means the minified file parses to the same program.

Usage: lua_minify.py <input.lua> <output.lua>
"""
import sys


def _long_bracket_level(src, i):
    """If src[i:] opens a Lua long bracket ('[' '='* '['), return its level (the
    number of '='); otherwise None. i must index the opening '['."""
    if i >= len(src) or src[i] != '[':
        return None
    j = i + 1
    while j < len(src) and src[j] == '=':
        j += 1
    if j < len(src) and src[j] == '[':
        return j - (i + 1)
    return None


def _find_long_close(src, start, level):
    """Return the index just past the matching long-bracket close (']' '='*level ']'),
    or len(src) if unterminated (invalid source, which the parse gate would reject)."""
    close = ']' + '=' * level + ']'
    idx = src.find(close, start)
    return len(src) if idx == -1 else idx + len(close)


_WS = ' \t\r\n\f\v'


def scan(src):
    """Return a list of (kind, text) segments: 'ws' | 'comment' | 'string' | 'code'."""
    segs = []
    i, n = 0, len(src)
    code_start = None

    def flush(upto):
        nonlocal code_start
        if code_start is not None and upto > code_start:
            segs.append(('code', src[code_start:upto]))
        code_start = None

    while i < n:
        c = src[i]
        if c in _WS:
            flush(i)
            j = i + 1
            while j < n and src[j] in _WS:
                j += 1
            segs.append(('ws', src[i:j]))
            i = j
        elif c == '-' and i + 1 < n and src[i + 1] == '-':
            flush(i)
            lvl = _long_bracket_level(src, i + 2)
            if lvl is not None:                      # --[[ ... ]] long comment
                end = _find_long_close(src, i + 2 + (2 + lvl), lvl)
            else:                                    # -- line comment (to EOL, keep the \n)
                end = i + 2
                while end < n and src[end] != '\n':
                    end += 1
            segs.append(('comment', src[i:end]))
            i = end
        elif c == '"' or c == "'":                   # short string
            flush(i)
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == c:
                    j += 1
                    break
                j += 1
            segs.append(('string', src[i:j]))
            i = j
        elif c == '[' and _long_bracket_level(src, i) is not None:  # [[ ... ]] long string
            lvl = _long_bracket_level(src, i)
            flush(i)
            end = _find_long_close(src, i + (2 + lvl), lvl)
            segs.append(('string', src[i:end]))
            i = end
        else:                                        # code
            if code_start is None:
                code_start = i
            i += 1
    flush(n)
    return segs


def _tokens(segs):
    return [(k, t) for (k, t) in segs if k == 'code' or k == 'string']


def minify(src):
    """LINE-PRESERVING minify: every dropped comment / collapsed whitespace run
    re-emits exactly its original newline count, so each surviving token keeps its
    source line number. This matters operationally: the embedded chunk loads under
    the SOURCE chunkname ("system.lua"), and the red crash screen prints its line
    numbers -- before this, a tester's photographed "system.lua:6500" pointed up to
    ~483 lines away from the real source site (and a python3-less local build,
    which embeds the raw file, reported DIFFERENT coordinates for the same commit).
    Costs ~600 bytes of newlines across the two big files."""
    segs = scan(src)
    out_parts = []
    for kind, text in segs:
        nl = text.count('\n') if kind in ('comment', 'ws') else 0
        if kind == 'comment':
            # A line comment holds no newline (the scanner stops before it) ->
            # emit a space so adjacent tokens stay separated; a long comment
            # re-emits its newlines so line numbers hold.
            out_parts.append('\n' * nl if nl else ' ')
        elif kind == 'ws':
            out_parts.append('\n' * nl if nl else ' ')
        else:
            out_parts.append(text)
    out = ''.join(out_parts)
    if not out.endswith('\n'):
        out += '\n'

    # Provable-equivalence self-check: the token stream must be unchanged.
    t_in = _tokens(segs)
    t_out = _tokens(scan(out))
    if t_in != t_out:
        m = min(len(t_in), len(t_out))
        first = next((k for k in range(m) if t_in[k] != t_out[k]), m)
        raise SystemExit(
            "lua_minify: token stream changed at token %d "
            "(in=%r out=%r); refusing to emit (minifier bug)"
            % (first,
               t_in[first] if first < len(t_in) else None,
               t_out[first] if first < len(t_out) else None))
    return out


def main(argv):
    if len(argv) != 3:
        raise SystemExit("usage: lua_minify.py <input.lua> <output.lua>")
    # surrogateescape so any non-UTF-8 byte inside a string literal round-trips
    # exactly (the scanner treats such chars as opaque code/string content).
    with open(argv[1], 'r', encoding='utf-8', errors='surrogateescape', newline='') as f:
        src = f.read()
    out = minify(src)
    with open(argv[2], 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
        f.write(out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
