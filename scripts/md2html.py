#!/usr/bin/env python3
"""Convert the small Markdown subset used in CHANGELOG.md to HTML (stdin -> stdout).

Supports: headings (#..####), "- " list items (with indented continuation lines), paragraphs,
`code`, **bold**, _italic_, [text](url). Used for the release notes shown in Sparkle's update window.
"""
import html
import re
import sys


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w])_([^_]+)_(?![\w])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def convert(md: str) -> str:
    out, para, items = [], [], []

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def flush_list():
        if items:
            out.append("<ul>" + "".join("<li>" + inline(i) + "</li>" for i in items) + "</ul>")
            items.clear()

    for raw in md.splitlines():
        line = raw.rstrip()
        heading = re.match(r"^(#{1,4})\s+(.*)$", line)
        if not line.strip():
            flush_para()
            flush_list()
        elif heading:
            flush_para()
            flush_list()
            level = 4 if len(heading.group(1)) >= 4 else 3   # release notes use ### (and ####)
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
        elif re.match(r"^\s*[-*]\s+", line):
            flush_para()
            items.append(re.sub(r"^\s*[-*]\s+", "", line))
        elif items and raw.startswith(("  ", "\t")):
            items[-1] += " " + line.strip()          # continuation of the previous list item
        else:
            flush_list()
            para.append(line.strip())
    flush_para()
    flush_list()
    return "\n".join(out)


if __name__ == "__main__":
    sys.stdout.write(convert(sys.stdin.read()) + "\n")
