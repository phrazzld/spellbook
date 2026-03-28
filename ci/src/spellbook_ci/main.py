"""Spellbook CI pipeline — local-first quality gates via Dagger."""

from typing import Annotated

import anyio

import dagger
from dagger import DefaultPath, Doc, Ignore, dag, function, object_type


def _lint_container(source: dagger.Directory) -> dagger.Container:
    """Base container with shellcheck and yamllint installed."""
    return (
        dag.container()
        .from_("python:3.12-slim")
        .with_exec(["apt-get", "update", "-qq"])
        .with_exec(
            [
                "apt-get",
                "install",
                "-y",
                "-qq",
                "--no-install-recommends",
                "shellcheck",
            ]
        )
        .with_exec(["pip", "install", "-q", "yamllint"])
        .with_directory("/src", source)
        .with_workdir("/src")
    )


@object_type
class SpellbookCi:
    """Local CI pipeline for the spellbook repo."""

    @function
    async def lint_yaml(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
            Doc("Repo source directory"),
        ],
    ) -> str:
        """Validate YAML files parse correctly."""
        # Discover yaml files, pass as argv (not f-string interpolation)
        return await (
            _lint_container(source)
            .with_exec([
                "sh", "-c",
                "find . -maxdepth 2 -name '*.yaml' -o -name '*.yml' "
                "| xargs python3 -c "
                "'import sys,yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]'",
            ])
            .stdout()
        )

    @function
    async def lint_shell(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Run shellcheck on all bash scripts (errors only)."""
        # Discover .sh files from filesystem
        return await (
            _lint_container(source)
            .with_exec([
                "sh", "-c",
                "find . -name '*.sh' -not -path './ci/*' "
                "| xargs shellcheck --severity=error",
            ])
            .stdout()
        )

    @function
    async def lint_python(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Syntax-check all Python files via py_compile."""
        # Discover .py files from filesystem
        return await (
            _lint_container(source)
            .with_exec([
                "sh", "-c",
                "find . -name '*.py' -not -path './ci/*' "
                "| xargs -I{} python3 -m py_compile {}",
            ])
            .stdout()
        )

    @function
    async def check_frontmatter(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Validate SKILL.md and agent frontmatter: required fields, line limits."""
        return await (
            _lint_container(source)
            .with_exec(["python3", "scripts/check-frontmatter.py"])
            .stdout()
        )

    @function
    async def check_index_drift(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Verify index.yaml matches what generate-index.sh would produce."""
        # Strip the timestamp comment before diffing — it changes every run
        return await (
            _lint_container(source)
            .with_exec(["sh", "-c", "grep -v '^# Generated:' index.yaml > /tmp/index-committed.yaml"])
            .with_exec(["bash", "scripts/generate-index.sh"])
            .with_exec(["sh", "-c", "grep -v '^# Generated:' index.yaml > /tmp/index-generated.yaml"])
            .with_exec(["diff", "-u", "/tmp/index-committed.yaml", "/tmp/index-generated.yaml"])
            .stdout()
        )

    @function
    async def check_vendored_copies(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Verify vendored copies match their canonical sources."""
        return await (
            _lint_container(source)
            .with_exec(["bash", "scripts/check-vendored-copies.sh"])
            .stdout()
        )

    @function
    async def test_bun(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Run Bun tests for the research skill."""
        return await (
            dag.container()
            .from_("oven/bun:latest")
            .with_directory("/src", source)
            .with_workdir("/src/skills/research")
            .with_exec(["bun", "test"])
            .stdout()
        )

    @function
    async def check(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
            Doc("Repo source directory"),
        ],
    ) -> str:
        """Run all quality gates. Exits non-zero if any fail."""
        results: list[tuple[str, bool, str]] = []

        async def run_gate(name: str, coro):
            try:
                output = await coro
                results.append((name, True, output.strip() if output else "OK"))
            except dagger.ExecError as e:
                results.append((name, False, e.stderr.strip() if e.stderr else str(e)))
            except Exception as e:
                results.append((name, False, str(e)))

        async with anyio.create_task_group() as tg:
            tg.start_soon(run_gate, "lint-yaml", self.lint_yaml(source))
            tg.start_soon(run_gate, "lint-shell", self.lint_shell(source))
            tg.start_soon(run_gate, "lint-python", self.lint_python(source))
            tg.start_soon(run_gate, "check-frontmatter", self.check_frontmatter(source))
            tg.start_soon(run_gate, "check-index-drift", self.check_index_drift(source))
            tg.start_soon(run_gate, "check-vendored-copies", self.check_vendored_copies(source))
            tg.start_soon(run_gate, "test-bun", self.test_bun(source))

        # Format results
        lines = ["Spellbook CI Results", "=" * 40]
        passed = 0
        failed = 0
        for name, ok, msg in sorted(results):
            status = "PASS" if ok else "FAIL"
            if ok:
                passed += 1
            else:
                failed += 1
            lines.append(f"  {status}  {name}")
            if not ok:
                for line in msg.splitlines()[:5]:
                    lines.append(f"         {line}")
        lines.append("=" * 40)
        lines.append(f"{passed} passed, {failed} failed")

        summary = "\n".join(lines)

        if failed > 0:
            raise Exception(summary)

        return summary
