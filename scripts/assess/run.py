#!/usr/bin/env python3
"""Agent-first quality assessment runner.

Deep module: simple CLI interface, complex internals.
Reads skill rubrics, builds prompts, calls LLM API with structured output,
validates against output contracts, writes JSON results.

Usage:
    python3 run.py --check depth --diff diff.txt --output result.json
    python3 run.py --check tests --diff diff.txt --context src/ --output result.json
    python3 run.py --check depth --full-scan src/ --output result.json
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Output contract envelope — every check must conform
# ---------------------------------------------------------------------------

OUTPUT_SCHEMA = {
    "type": "object",
    "required": ["version", "check", "overall", "score", "findings", "summary"],
    "properties": {
        "version": {"type": "integer", "const": 1},
        "check": {"type": "string"},
        "overall": {"type": "string", "enum": ["pass", "warn", "fail"]},
        "score": {"type": "integer", "minimum": 0, "maximum": 100},
        "findings": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["location", "severity", "issue", "suggestion"],
                "properties": {
                    "location": {"type": "string"},
                    "severity": {
                        "type": "string",
                        "enum": ["critical", "warning", "info"],
                    },
                    "issue": {"type": "string"},
                    "suggestion": {"type": "string"},
                },
            },
        },
        "summary": {"type": "string"},
    },
    "additionalProperties": True,
}

# ---------------------------------------------------------------------------
# Skill discovery — reads SKILL.md to extract rubric
# ---------------------------------------------------------------------------

SKILLS_ROOT = Path(__file__).resolve().parent.parent.parent / "skills"


def find_skill(check_name: str) -> Path:
    """Resolve check name to skill directory."""
    skill_dir = SKILLS_ROOT / f"assess-{check_name}"
    if not skill_dir.is_dir():
        print(f"error: skill directory not found: {skill_dir}", file=sys.stderr)
        sys.exit(2)
    return skill_dir


def load_rubric(skill_dir: Path) -> str:
    """Load the full rubric: SKILL.md body + references/rubric.md if present."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        print(f"error: SKILL.md not found in {skill_dir}", file=sys.stderr)
        sys.exit(2)

    content = skill_md.read_text()

    # Strip YAML frontmatter
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            content = content[end + 3 :].strip()

    # Append detailed rubric reference if available
    rubric_ref = skill_dir / "references" / "rubric.md"
    if rubric_ref.exists():
        content += "\n\n## Detailed Rubric\n\n" + rubric_ref.read_text()

    return content


def load_frontmatter(skill_dir: Path) -> dict[str, Any]:
    """Extract YAML frontmatter from SKILL.md as a dict."""
    skill_md = skill_dir / "SKILL.md"
    content = skill_md.read_text()
    if not content.startswith("---"):
        return {}
    end = content.find("---", 3)
    if end == -1:
        return {}

    # Minimal YAML parsing — avoids pyyaml dependency
    frontmatter = {}
    for line in content[3:end].strip().splitlines():
        line = line.strip()
        if ":" in line and not line.startswith("#"):
            key, _, value = line.partition(":")
            value = value.strip().strip("'\"")
            frontmatter[key.strip()] = value
    return frontmatter


# ---------------------------------------------------------------------------
# Context assembly — builds the user message from diff/files
# ---------------------------------------------------------------------------


def read_diff(diff_path: str) -> str:
    """Read a diff file."""
    path = Path(diff_path)
    if not path.exists():
        print(f"error: diff file not found: {diff_path}", file=sys.stderr)
        sys.exit(2)
    return path.read_text()


def read_context(context_path: str | None) -> str:
    """Read additional context files/directory."""
    if not context_path:
        return ""

    path = Path(context_path)
    if path.is_file():
        return f"\n## Context File: {path.name}\n\n{path.read_text()}"

    if path.is_dir():
        parts = []
        for f in sorted(path.rglob("*")):
            if f.is_file() and f.suffix in {
                ".ts", ".tsx", ".js", ".jsx",
                ".py", ".rs", ".go", ".ex", ".exs",
                ".md", ".json", ".yaml", ".yml", ".toml",
            }:
                try:
                    text = f.read_text()
                    # Skip huge files
                    if len(text) > 50_000:
                        continue
                    parts.append(f"## {f.relative_to(path)}\n\n```\n{text}\n```")
                except (UnicodeDecodeError, PermissionError):
                    continue
        return "\n\n".join(parts)

    return ""


def scan_directory(scan_path: str) -> str:
    """Read all source files in a directory for full-repo audit."""
    return read_context(scan_path)


# ---------------------------------------------------------------------------
# LLM API call — agent-agnostic, configurable via env
# ---------------------------------------------------------------------------


def resolve_model(frontmatter: dict[str, Any]) -> str:
    """Resolve which model to use. Priority: env > frontmatter > default."""
    env_model = os.environ.get("ASSESS_MODEL")
    if env_model:
        return env_model

    tier = frontmatter.get("agent_tier", "weak")
    # Map tiers to model IDs — override via env vars
    tier_map = {
        "weak": os.environ.get("ASSESS_MODEL_WEAK", "claude-sonnet-4-20250514"),
        "strong": os.environ.get("ASSESS_MODEL_STRONG", "claude-opus-4-20250514"),
    }
    return tier_map.get(tier, tier_map["weak"])


def call_llm(
    system_prompt: str,
    user_message: str,
    model: str,
    max_tokens: int = 4096,
) -> dict[str, Any]:
    """Call LLM API and return parsed JSON response.

    Supports Anthropic API. Agent-agnostic interface — swap provider
    by changing the implementation here.
    """
    try:
        import anthropic
    except ImportError:
        print(
            "error: anthropic package not installed. "
            "Run: pip install anthropic",
            file=sys.stderr,
        )
        sys.exit(2)

    api_key = os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("LLM_API_KEY")
    if not api_key:
        print(
            "error: set ANTHROPIC_API_KEY or LLM_API_KEY environment variable",
            file=sys.stderr,
        )
        sys.exit(2)

    client = anthropic.Anthropic(api_key=api_key)

    # Use tool_use for structured output
    tool_schema = {
        "name": "submit_assessment",
        "description": "Submit the quality assessment result",
        "input_schema": OUTPUT_SCHEMA,
    }

    response = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        temperature=0,
        system=system_prompt,
        tools=[tool_schema],
        tool_choice={"type": "tool", "name": "submit_assessment"},
        messages=[{"role": "user", "content": user_message}],
    )

    # Extract tool use result
    for block in response.content:
        if block.type == "tool_use" and block.name == "submit_assessment":
            return block.input

    print("error: LLM did not return structured output", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def validate_output(result: dict[str, Any]) -> list[str]:
    """Validate result against output contract. Returns list of errors."""
    errors = []
    for field in OUTPUT_SCHEMA["required"]:
        if field not in result:
            errors.append(f"missing required field: {field}")

    if "overall" in result and result["overall"] not in ("pass", "warn", "fail"):
        errors.append(f"invalid overall value: {result['overall']}")

    if "score" in result:
        score = result["score"]
        if not isinstance(score, int) or score < 0 or score > 100:
            errors.append(f"score must be int 0-100, got: {score}")

    if "findings" in result and not isinstance(result["findings"], list):
        errors.append("findings must be an array")

    return errors


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def build_system_prompt(rubric: str, check_name: str) -> str:
    """Build system prompt from rubric."""
    return f"""You are a code quality assessor performing the "{check_name}" check.

Your task: analyze the provided code and produce a structured assessment following
the rubric below. Be precise, cite specific file:line locations, and score fairly.

## Scoring Guide
- 90-100: Exemplary. No issues found.
- 70-89: Good. Minor issues only.
- 50-69: Needs improvement. Significant issues.
- 30-49: Poor. Critical issues.
- 0-29: Failing. Fundamental problems.

## Overall Verdict
- "pass": score >= 70 and no critical findings
- "warn": score >= 50 and no more than 2 critical findings
- "fail": score < 50 or 3+ critical findings

## Rubric

{rubric}

## Output Instructions

Use the submit_assessment tool to return your structured result.
Every finding must include a specific location (file:line), severity, issue
description, and concrete suggestion for improvement."""


def build_user_message(
    diff: str | None,
    context: str | None,
    full_scan: str | None,
    check_name: str,
) -> str:
    """Assemble user message from inputs."""
    parts = []

    if diff:
        parts.append(f"## Diff to Assess\n\n```diff\n{diff}\n```")
    if context:
        parts.append(f"## Additional Context\n\n{context}")
    if full_scan:
        parts.append(f"## Full Codebase Scan\n\n{full_scan}")

    if not parts:
        print("error: no input provided (--diff, --context, or --full-scan)", file=sys.stderr)
        sys.exit(2)

    return "\n\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(description="Agent-first quality assessment runner")
    parser.add_argument("--check", required=True, help="Check name (e.g., depth, tests, drift)")
    parser.add_argument("--diff", help="Path to diff file")
    parser.add_argument("--context", help="Path to additional context file or directory")
    parser.add_argument("--full-scan", help="Path to directory for full-repo audit")
    parser.add_argument("--output", required=True, help="Path to write JSON result")
    parser.add_argument("--dry-run", action="store_true", help="Print prompt without calling API")
    args = parser.parse_args()

    # Discover skill and load rubric
    skill_dir = find_skill(args.check)
    rubric = load_rubric(skill_dir)
    frontmatter = load_frontmatter(skill_dir)

    # Build prompts
    system_prompt = build_system_prompt(rubric, args.check)
    diff_text = read_diff(args.diff) if args.diff else None
    context_text = read_context(args.context) if args.context else None
    scan_text = scan_directory(args.full_scan) if args.full_scan else None
    user_message = build_user_message(diff_text, context_text, scan_text, args.check)

    if args.dry_run:
        print("=== SYSTEM PROMPT ===")
        print(system_prompt)
        print("\n=== USER MESSAGE ===")
        print(user_message[:2000] + "..." if len(user_message) > 2000 else user_message)
        return

    # Call LLM
    model = resolve_model(frontmatter)
    result = call_llm(system_prompt, user_message, model)

    # Validate
    errors = validate_output(result)
    if errors:
        print(f"warning: output validation issues: {errors}", file=sys.stderr)
        # Attempt to fix common issues
        if "version" not in result:
            result["version"] = 1
        if "check" not in result:
            result["check"] = args.check

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2) + "\n")

    # Print summary to stderr for CI visibility
    overall = result.get("overall", "unknown")
    score = result.get("score", "?")
    finding_count = len(result.get("findings", []))
    critical_count = sum(
        1 for f in result.get("findings", []) if f.get("severity") == "critical"
    )
    print(
        f"assess-{args.check}: {overall} (score={score}, "
        f"findings={finding_count}, critical={critical_count})",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
