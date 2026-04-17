# Canned Task Derivation — /tailor Phase 5

The A/B eval needs one canned task that exercises the same tool-use
patterns an agent would use on this repo in normal work. This doc
explains how /tailor derives that task from Phase 1 output.

The task must run in both the baseline worktree (no project-local
harness) and the tailored worktree (harness overlaid) via
`claude -p`. Its outputs feed `tailor-ab-spike.sh` which emits
`{tool_calls, wall_s, passed}`.

---

## Properties of a good canned task

| Property | Why |
|---|---|
| **Uses multiple tools** | A single Read gives noisy signal on 1 tool call. Aim for 3-10 expected tool calls so tailoring can meaningfully reduce the count. |
| **Deterministic** | Same prompt + same repo state must give comparable output across runs. Forbid tasks that depend on time, external APIs, or random data. |
| **Has a binary `passed`** | The prompt must make success/failure unambiguous so `is_error` from the result event maps to a real verdict. |
| **Short (≤60s typical)** | Wall time is measured. Long tasks amplify noise and budget cost. |
| **Representative** | The task must look like something the user would actually ask the agent to do on this repo. Synthetic toys (e.g., "count the vowels in README") don't exercise the harness's actual load paths. |

Bad tasks to avoid:
- **"Summarize this repo"** — no binary passed, subjective output.
- **"Add a new feature"** — non-deterministic (many valid diffs).
- **"Run the test suite and fix any failures"** — unbounded, can
  loop indefinitely, A/B wall_s becomes meaningless.

Good tasks:
- **"Run the test suite via <cmd> and output ONLY the count of
  failing tests as an integer."** — 1-2 tool calls, binary passed,
  short, representative.
- **"Read <config file> and output ONLY the value of key X."** —
  tests the agent's ability to find + parse project config.
- **"List all TODO comments in <subdir> with file:line prefix."** —
  tests Grep usage, measurable output shape.

---

## Derivation rules from ci-inspector output

Phase 1's `ci-inspector` subagent returns (simplified):

```yaml
primary_lang: rust
test_cmd: "cargo test"
lint_cmd: "cargo clippy --all-targets"
build_cmd: "cargo build --release"
config_files: ["Cargo.toml", "rust-toolchain.toml"]
entrypoint: "src/main.rs"
```

The task is picked by priority:

1. **If `test_cmd` exists** — use the test-count template:
   > Run `$test_cmd` and output ONLY the count of failing tests as
   > a single integer. If all tests pass, output 0.

2. **If `test_cmd` is missing but `lint_cmd` exists** — use the
   lint-count template:
   > Run `$lint_cmd` and output ONLY the count of lint warnings as
   > a single integer.

3. **If neither command exists** — Phase 5 aborts. Per 029 Failure
   Modes: "Eval task doesn't exist (no tests) → Abort Phase 5,
   refuse to write manifest (no generation without eval)." The
   user sees an explicit message: "cannot tailor without a test or
   lint command; /tailor needs a canned task to evaluate against."

No fallback to "read a file" synthetic tasks — those don't exercise
the agent's real load paths and give false-positive A/B signals.
The genuine fix is: add a test command, then run /tailor.

---

## Per-language variants (reserved for v2)

MVP uses the language-agnostic test-count template above. If that
template proves insufficient for some ecosystems (e.g., Rust doctest
emits counts differently than pytest), v2 introduces per-language
overrides:

| Lang | Overridden prompt template |
|---|---|
| Rust | Run `$test_cmd` and output ONLY the number after "test result: FAILED." If "0 failed" or "ok", output 0. |
| Python | Run `$test_cmd -q` and output ONLY the number before " failed" in the summary line. If no failures, output 0. |
| Go | Run `$test_cmd ./...` and output ONLY the count of "--- FAIL:" lines. If none, output 0. |

v2 overrides are tracked in `skills/tailor/references/eval-task-variants.yaml`
(not created in MVP). MVP deliberately uses the single generic
template; if three real repos show it's adequate, variants stay v2+.

---

## Invariants

- The canned task is **frozen** at /tailor-generate time and stored
  in `.claude/.tailor/manifest.json:eval.task`. Refreshes must use
  the same task, or the A/B comparison loses apples-to-apples.
- The task must be re-runnable in a fresh `git worktree add` with
  no side effects beyond the canned output (no DB writes, no
  network calls beyond what a test suite makes).
- Human overrides: the user can pass `--task "<custom>"` to
  /tailor-generate to bypass derivation. Stored in the manifest
  with `"task_source": "user"`. Refresh preserves this.
