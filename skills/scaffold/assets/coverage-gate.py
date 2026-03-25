#!/usr/bin/env python3
"""Coverage ratchet gate. Fails if coverage drops below baseline."""

import json
import os
import re
import sys
from pathlib import Path

BASELINE_PATH = Path(".coverage-baseline.json")
METRICS = ("branches", "functions", "lines", "statements")

# Standard coverage output locations per language
COVERAGE_SOURCES = [
    Path("coverage/coverage-summary.json"),  # TypeScript (vitest/istanbul)
    Path("coverage/tarpaulin-report.json"),   # Rust
    Path("coverage/coverage.out"),            # Go
]


def load_baseline() -> dict:
    if not BASELINE_PATH.exists():
        return {m: 0 for m in METRICS}
    return json.loads(BASELINE_PATH.read_text())


def extract_typescript(path: Path) -> dict | None:
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    total = data.get("total", {})
    return {m: total.get(m, {}).get("pct", 0) for m in METRICS}


def extract_go(path: Path) -> dict | None:
    if not path.exists():
        return None
    text = path.read_text()
    hit = total = 0
    for line in text.splitlines():
        match = re.match(r".+:(\d+)\.\d+,(\d+)\.\d+ (\d+) (\d+)", line)
        if match:
            stmts, count = int(match.group(3)), int(match.group(4))
            total += stmts
            if count > 0:
                hit += stmts
    pct = (hit / total * 100) if total > 0 else 0
    return {m: pct for m in METRICS}


def extract_rust(path: Path) -> dict | None:
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    # tarpaulin top-level coverage field
    pct = data.get("coverage", 0)
    return {m: pct for m in METRICS}


def get_current_coverage() -> dict:
    for path, extractor in [
        (COVERAGE_SOURCES[0], extract_typescript),
        (COVERAGE_SOURCES[1], extract_rust),
        (COVERAGE_SOURCES[2], extract_go),
    ]:
        result = extractor(path)
        if result is not None:
            return result
    print("No coverage data found. Checked:", file=sys.stderr)
    for p in COVERAGE_SOURCES:
        print(f"  {p}", file=sys.stderr)
    sys.exit(1)


def main():
    baseline = load_baseline()
    current = get_current_coverage()

    failures = []
    for metric in METRICS:
        base_val = baseline.get(metric, 0)
        curr_val = current.get(metric, 0)
        if curr_val < base_val:
            failures.append(f"  {metric}: {curr_val:.1f}% < {base_val:.1f}% baseline")

    if os.environ.get("UPDATE_BASELINE") == "true":
        BASELINE_PATH.write_text(json.dumps(current, indent=2) + "\n")
        print(f"Baseline updated: {current}")
        sys.exit(0)

    if failures:
        print("Coverage ratchet FAILED — regression detected:")
        print("\n".join(failures))
        sys.exit(1)

    print(f"Coverage gate passed: {current}")


if __name__ == "__main__":
    main()
