#!/usr/bin/env python3
"""
Skill Initializer - Creates a new skill from template.

Usage:
    init_skill.py <skill-name> --path <path>

Examples:
    init_skill.py my-new-skill --path skills
    init_skill.py my-api-helper --path .agents/skills
"""

import sys
from pathlib import Path


SKILL_TEMPLATE = """---
name: {skill_name}
description: |
  [What this skill does in 1-2 sentences]. Use when:
  - [Trigger scenario 1]
  - [Trigger scenario 2]
  Keywords: [specific terms, tool names, file patterns]
---

# {skill_title}

[1-2 sentence purpose statement]

## Workflow

### 1. [First Step]
[Brief guidance]

### 2. [Second Step]
[Brief guidance]

## Key Principles

- [Principle 1]
- [Principle 2]

## References

- `references/[topic].md` - [What it covers]

## Scripts

- `scripts/[script.py]` - [What it does]
"""


def title_case_skill_name(skill_name):
    """Convert hyphenated skill name to Title Case for display."""
    return ' '.join(word.capitalize() for word in skill_name.split('-'))


def init_skill(skill_name, path):
    """Initialize a new skill directory with template SKILL.md."""
    skill_dir = Path(path).resolve() / skill_name

    if skill_dir.exists():
        print(f"[x] Error: Skill directory already exists: {skill_dir}")
        return None

    try:
        skill_dir.mkdir(parents=True, exist_ok=False)
        print(f"[OK] Created skill directory: {skill_dir}")
    except Exception as e:
        print(f"[x] Error creating directory: {e}")
        return None

    # Create SKILL.md from template
    skill_title = title_case_skill_name(skill_name)
    skill_content = SKILL_TEMPLATE.format(
        skill_name=skill_name,
        skill_title=skill_title
    )

    skill_md_path = skill_dir / 'SKILL.md'
    try:
        skill_md_path.write_text(skill_content)
        print("[OK] Created SKILL.md")
    except Exception as e:
        print(f"[x] Error creating SKILL.md: {e}")
        return None

    # Create resource directories
    try:
        (skill_dir / 'references').mkdir(exist_ok=True)
        print("[OK] Created references/")

        (skill_dir / 'scripts').mkdir(exist_ok=True)
        print("[OK] Created scripts/")
    except Exception as e:
        print(f"[x] Error creating directories: {e}")
        return None

    print(f"\n[OK] Skill '{skill_name}' initialized at {skill_dir}")
    print("\nNext steps:")
    print("1. Edit SKILL.md — complete description with trigger terms")
    print("2. Add references/ and scripts/ as needed")
    print("3. Run validate_skill.py to check structure")

    return skill_dir


def main():
    if len(sys.argv) < 4 or sys.argv[2] != '--path':
        print("Usage: init_skill.py <skill-name> --path <path>")
        print("\nExamples:")
        print("  init_skill.py my-new-skill --path skills")
        print("  init_skill.py my-api-helper --path .agents/skills")
        sys.exit(1)

    skill_name = sys.argv[1]
    path = sys.argv[3]

    print(f"Initializing skill: {skill_name}")
    print(f"  Location: {path}")
    print()

    result = init_skill(skill_name, path)
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
