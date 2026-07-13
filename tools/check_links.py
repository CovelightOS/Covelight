#!/usr/bin/env python3
"""Fail if any relative markdown link points at a file that doesn't exist.

Usage: tools/check_links.py [root]
Exit 0 if every internal link resolves, 1 otherwise (with a list printed).
External (http/https) links and in-page anchors (#foo) are not checked.
"""
import os
import re
import sys

LINK_RE = re.compile(r"\]\(([^)]+)\)")


def find_markdown_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            if name.endswith(".md"):
                yield os.path.join(dirpath, name)


def check(root):
    broken = []
    checked = 0
    for path in find_markdown_files(root):
        text = open(path, encoding="utf-8", errors="ignore").read()
        for link in LINK_RE.findall(text):
            if not link or link.startswith(("http://", "https://", "#", "mailto:")):
                continue
            target_path = link.split("#", 1)[0]
            if not target_path:
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(path), target_path))
            checked += 1
            if not os.path.exists(target):
                broken.append((path, link))
    return checked, broken


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    checked, broken = check(root)
    print(f"checked {checked} internal links")
    if broken:
        print(f"\n{len(broken)} broken link(s):")
        for path, link in broken:
            print(f"  {path} -> {link}")
        return 1
    print("all internal links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
