"""Pure helpers for the self-healing CI flow."""

from dataclasses import dataclass
from datetime import UTC, datetime
import re

HEALABLE_GATES = {
    "lint-yaml": "Fix YAML syntax or structural issues without changing meaning.",
    "lint-shell": "Fix shellcheck errors without changing script behavior.",
    "lint-python": "Fix Python syntax or import errors without changing behavior.",
    "check-frontmatter": "Fix invalid frontmatter metadata without broad rewrites.",
}


@dataclass(frozen=True, slots=True)
class GateFailure:
    """A failing CI gate extracted from the aggregated check summary."""

    name: str
    detail: str


def parse_check_failures(summary: str) -> list[GateFailure]:
    """Parse failing gates from the human-readable check() summary."""
    failures: list[GateFailure] = []
    current_name: str | None = None
    current_ok = True
    details: list[str] = []

    for line in summary.splitlines():
        match = re.match(r"^\s{2}(PASS|FAIL)\s{2}(.+)$", line)
        if match:
            if current_name and not current_ok:
                failures.append(
                    GateFailure(
                        name=current_name,
                        detail="\n".join(details).strip() or "No stderr captured.",
                    )
                )
            current_ok = match.group(1) == "PASS"
            current_name = match.group(2).strip()
            details = []
            continue

        if current_name and not current_ok and line.startswith("         "):
            details.append(line.strip())

    if current_name and not current_ok:
        failures.append(
            GateFailure(
                name=current_name,
                detail="\n".join(details).strip() or "No stderr captured.",
            )
        )

    return failures


def select_healable_failure(failures: list[GateFailure]) -> GateFailure:
    """Allow exactly one healable lint-style failure at a time."""
    if not failures:
        raise ValueError("heal requires at least one failing gate.")

    unsupported = [failure.name for failure in failures if failure.name not in HEALABLE_GATES]
    if unsupported:
        supported = ", ".join(sorted(HEALABLE_GATES))
        got = ", ".join(sorted(failure.name for failure in failures))
        raise ValueError(
            "heal currently supports one lint-style failure at a time. "
            f"Supported gates: {supported}. Got: {got}."
        )

    if len(failures) != 1:
        got = ", ".join(sorted(failure.name for failure in failures))
        raise ValueError(
            "heal currently supports one failing gate at a time. "
            f"Resolve the other failures first: {got}."
        )

    return failures[0]


def repair_branch_name(gate_name: str) -> str:
    """Create a unique branch name for the repair commit."""
    slug = re.sub(r"[^a-z0-9]+", "-", gate_name.lower()).strip("-")
    timestamp = datetime.now(UTC).strftime("%Y%m%d%H%M%S")
    return f"heal/{slug}-{timestamp}"


def repair_commit_message(gate_name: str) -> str:
    """Create the semantic commit message for a successful repair."""
    return f"ci: heal {gate_name}"
