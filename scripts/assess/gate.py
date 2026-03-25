#!/usr/bin/env python3
"""CI gate for agent-first quality assessments.

Reads JSON output from run.py, gates on the `overall` verdict.
Exit 0 for pass/warn, exit 1 for fail.

Usage:
    python3 gate.py result.json
    python3 gate.py result.json --strict   # fail on warn too
"""

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: gate.py <result.json> [--strict]", file=sys.stderr)
        sys.exit(2)

    result_path = Path(sys.argv[1])
    strict = "--strict" in sys.argv

    if not result_path.exists():
        print(f"error: result file not found: {result_path}", file=sys.stderr)
        sys.exit(2)

    result = json.loads(result_path.read_text())
    overall = result.get("overall", "fail")
    check = result.get("check", "unknown")
    score = result.get("score", "?")
    summary = result.get("summary", "")

    # Print report
    findings = result.get("findings", [])
    critical = [f for f in findings if f.get("severity") == "critical"]
    warnings = [f for f in findings if f.get("severity") == "warning"]

    print(f"{'='*60}")
    print(f"assess-{check}: {overall.upper()} (score: {score}/100)")
    print(f"{'='*60}")

    if critical:
        print(f"\nCritical ({len(critical)}):")
        for f in critical:
            print(f"  {f.get('location', '?')}: {f.get('issue', '?')}")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for f in warnings:
            print(f"  {f.get('location', '?')}: {f.get('issue', '?')}")

    if summary:
        print(f"\nSummary: {summary}")

    print()

    # Gate decision
    if overall == "fail":
        sys.exit(1)
    if strict and overall == "warn":
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
