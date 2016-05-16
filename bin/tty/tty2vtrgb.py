#!/usr/bin/env python3

import sys

def color_expr(f):
    for line in f:
        line = line.strip()
        if line.startswith("echo -en"):
            yield parse_line(line)

def parse_line(line):
    """
    :param line: 'echo -en "\e]Pirrggbb" ...'
    :type line: str

    :return: idx, rr, gg, bb
    :rtype: (int, int, int, int)
    """
    tok = line.split('"')
    color_def = tok[1]
    color_tok = (color_def[4], color_def[5:7], color_def[7:9], color_def[9:11])
    return map(lambda x: int(x, 16), color_tok)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        import os
        print("Usage: %s <tty-colors.sh>" % os.path.basename(sys.argv[0]))
        sys.exit(-1)

    colors = {'r': [None] * 16, 'g': [None] * 16, 'b': [None] * 16}

    with open(sys.argv[1], "r") as f:
        for idx, *rgb in color_expr(f):
            for c, val in zip("rgb", rgb):
                colors[c][idx] = val

    for c in "rgb":
        colors_str = map(lambda x: str(x), colors[c])
        line = ",".join(colors_str)
        print(line)
