#!/usr/bin/env python3
"""Validate SKILL.md and agent .md frontmatter: required fields, line limits."""

import os
import sys

import yaml


def check_frontmatter(path, required_fields=("name", "description"), max_lines=None):
    """Check a single markdown file's YAML frontmatter. Returns list of errors."""
    errors = []
    with open(path) as f:
        content = f.read()
    lines = content.splitlines()

    if max_lines and len(lines) > max_lines:
        errors.append(f"{path}: {len(lines)} lines (max {max_lines})")

    if not content.startswith("---"):
        return [f"{path}: missing frontmatter"]
    parts = content.split("---", 2)
    if len(parts) < 3:
        return [f"{path}: malformed frontmatter"]
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        return [f"{path}: invalid YAML frontmatter: {e}"]
    if not fm or not isinstance(fm, dict):
        return [f"{path}: empty frontmatter"]

    for field in required_fields:
        if field not in fm:
            errors.append(f"{path}: missing '{field}' in frontmatter")
    return errors


def main():
    errors = []

    for name in sorted(os.listdir("skills")):
        path = f"skills/{name}/SKILL.md"
        if os.path.isfile(path):
            errors.extend(check_frontmatter(path, max_lines=500))

    for name in sorted(os.listdir("agents")):
        if name.endswith(".md"):
            errors.extend(check_frontmatter(f"agents/{name}"))

    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
    print("OK: all frontmatter valid")


if __name__ == "__main__":
    main()
