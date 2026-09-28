#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kiểm tra chất lượng localization cho MacOptimizer.

Cách dùng:
    python3 scripts/validate_localizations.py

Kiểm tra:
  1. Mọi file Languages/*.json là JSON hợp lệ, có "_name" và "_flag".
  2. Mọi khóa L("...") trong mã nguồn (kể cả khóa tiếng Việt sinh từ
     L(x.rawValue)) phải có bản dịch trong từng ngôn ngữ không phải "vi".
  3. Format specifier (%d, %@, %.1f...) của bản dịch phải khớp với khóa.
  4. (Thông tin) Các khóa có trong file ngôn ngữ nhưng không còn được dùng.

Thoát mã 1 nếu có lỗi (thiếu bản dịch / sai specifier), 0 nếu đạt.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "AppUninstaller"
LANG_DIR = SRC / "Languages"

VI_RE = re.compile(r"[\u00c0-\u01b0\u1ea0-\u1ef9]")
SPEC_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[a-zA-Z@]")


def strip_comments(src: str) -> str:
    """Bỏ // và /* */ nhưng giữ nguyên nội dung chuỗi literal."""
    out, i, n = [], 0, len(src)
    in_str = False
    while i < n:
        c = src[i]
        if in_str:
            out.append(c)
            if c == "\\":
                if i + 1 < n:
                    out.append(src[i + 1])
                    i += 2
                    continue
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i)
            i = n if j == -1 else j + 2
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return "".join(out)


def decode_swift(s: str) -> str:
    """Giải mã \\\" \\\\ \\n \\t trong literal Swift thành ký tự thật."""
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            if nxt == '"':
                out.append('"')
                i += 2
                continue
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
        out.append(c)
        i += 1
    return "".join(out)


def collect_code_keys() -> set:
    """Gom mọi khóa L(...) trong mã nguồn + rawValue tiếng Việt được bọc L(x.rawValue)."""
    keys = set()
    for path in SRC.rglob("*.swift"):
        if path.name == "LocalizationManager.swift":
            continue
        src = strip_comments(path.read_text(encoding="utf-8"))
        for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', src):
            keys.add(decode_swift(m.group(1)))
        if re.search(r"\bL\([a-zA-Z_.]+\.rawValue\)", src):
            for m in re.finditer(
                r'case\s+\w+\s*=\s*"((?:[^"\\]|\\.)*)"(\s*//.*)?$', src, re.M
            ):
                v = decode_swift(m.group(1))
                if VI_RE.search(v):
                    keys.add(v)
    return keys


def specifiers(s: str) -> list:
    """Trả về danh sách format specifier, bỏ qua %% (percent literal)."""
    return SPEC_RE.findall(s.replace("%%", "\x00"))


def main() -> int:
    errors = []

    # 1. JSON hợp lệ + khóa đặc biệt
    tables = {}
    for path in sorted(LANG_DIR.glob("*.json")):
        try:
            table = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{path.name}: JSON không hợp lệ — {e}")
            continue
        if "_name" not in table:
            errors.append(f"{path.name}: thiếu \"_name\" (tên hiển thị ngôn ngữ)")
        if "_flag" not in table:
            errors.append(f"{path.name}: thiếu \"_flag\" (emoji cờ)")
        tables[path.stem] = {k: v for k, v in table.items() if not k.startswith("_")}

    if not errors:
        code_keys = collect_code_keys()
        vi_table = tables.get("vi", {})

        # 2. Đủ bản dịch cho từng ngôn ngữ
        for code, table in tables.items():
            if code == "vi":
                continue  # tiếng Việt là ngôn ngữ nguồn, khóa trùng chính nó
            missing = sorted(k for k in code_keys if k not in table)
            if missing:
                errors.append(
                    f"{code}.json thiếu {len(missing)} khóa: "
                    + "; ".join(repr(k) for k in missing[:10])
                    + ("..." if len(missing) > 10 else "")
                )

            # 3. Specifier của bản dịch phải khớp với khóa; với khóa legacy
            #    (không phải chuỗi tiếng Việt nguồn) thì so với giá trị vi.json.
            for key, value in table.items():
                if key in ("_name", "_flag"):
                    continue
                reference = vi_table.get(key, key)
                if specifiers(reference) != specifiers(value):
                    errors.append(
                        f"{code}.json: specifier lệch cho khóa {key!r}: "
                        f"{specifiers(reference)} != {specifiers(value)}"
                    )

        # 4. Thông tin: khóa không còn dùng
        used = collect_code_keys()
        for code, table in tables.items():
            unused = sorted(k for k in table if k not in used)
            if unused:
                print(
                    f"[info] {code}.json có {len(unused)} khóa không tìm thấy trong mã "
                    "(có thể là khóa legacy hoặc lỗi chính tả): "
                    + "; ".join(repr(k) for k in unused[:5])
                    + ("..." if len(unused) > 5 else "")
                )

    if errors:
        print("❌ Localization có lỗi:")
        for e in errors:
            print("  -", e)
        return 1

    total = len(collect_code_keys())
    print(f"✅ OK — {len(tables)} ngôn ngữ, {total} khóa trong mã nguồn đều có bản dịch.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
