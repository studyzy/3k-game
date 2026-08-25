#!/usr/bin/env python3
"""从 scripts/data/text_library.gd 提取全部 const 常量，生成权威 Texts JSON。

GDScript 的数组/字符串字面量在结构上等价于 Python 字面量，故用 ast.literal_eval 解析。
输出键名与 GDScript 常量名一致（如 GENERAL_GRADE、skill_names、HJ），供 seed 工具与
服务器 /game/static 下发使用。

用法: python3 extract_texts.py <text_library.gd路径> <输出.json>
"""
import ast
import json
import re
import sys


def find_balanced(s, open_idx):
    """s[open_idx] == '['，返回与之匹配的 ']' 下标（含字符串/转义处理）。"""
    depth = 0
    in_str = False
    esc = False
    i = open_idx
    while i < len(s):
        c = s[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "[":
                depth += 1
            elif c == "]":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return -1


def extract_string(s, start_idx):
    """s[start_idx] == '"'，返回 (value, end_idx)，处理 \\n \\t \\" 转义。"""
    i = start_idx + 1
    buf = []
    while i < len(s):
        c = s[i]
        if c == "\\":
            nxt = s[i + 1] if i + 1 < len(s) else ""
            buf.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        if c == '"':
            return "".join(buf), i
        buf.append(c)
        i += 1
    raise ValueError("unterminated string")


def main(path, out):
    src = open(path, encoding="utf-8").read()
    result = {}
    for m in re.finditer(r"^const\s+([A-Za-z_]\w*)\s*(?::[^=\n]+)?=", src, re.M):
        name = m.group(1)
        p = m.end()
        while p < len(src) and src[p] in " \t":
            p += 1
        if p >= len(src):
            continue
        c = src[p]
        if c == "[":
            end = find_balanced(src, p)
            if end < 0:
                raise ValueError("未闭合数组: %s" % name)
            result[name] = ast.literal_eval(src[p : end + 1])
        elif c == '"':
            result[name], _ = extract_string(src, p)
        else:
            line_end = src.find("\n", p)
            token = src[p:line_end].strip()
            result[name] = ast.literal_eval(token)

    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print("提取 %d 个常量:" % len(result))
    for k, v in result.items():
        if isinstance(v, list):
            print("  %-32s Array[%d]" % (k, len(v)))
        else:
            print("  %-32s %s" % (k, type(v).__name__))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
