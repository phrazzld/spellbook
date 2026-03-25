---
name: assess-docs
description: |
  Assess documentation freshness and accuracy. Detects stale code examples,
  outdated API signatures, dead references, missing feature docs.
  Use per-PR or in /groom for docs health audit.
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /assess-docs

Score documentation accuracy against the actual codebase. Find docs that lie.

## Rubric

Seven dimensions, each producing findings at severity `critical`, `warning`, or `info`.

### 1. Stale Code Examples

Code blocks in docs that no longer match the actual source. Function calls with wrong signatures, removed parameters still shown, deprecated patterns presented as current.

**Signals:** Code examples referencing functions/classes that don't exist, wrong parameter counts, import paths that resolve to nothing, examples using APIs removed in recent commits.

### 2. Outdated API Signatures

Public function/method signatures documented with wrong parameter names, wrong types, wrong return types, or missing parameters added since the docs were written.

**Signals:** Mismatch between documented signatures and actual source. Especially dangerous when the docs show fewer required parameters than the code expects.

### 3. Dead Internal References

Docs referencing files, functions, modules, or sections that no longer exist. Markdown links to deleted files. "See `src/utils/helpers.ts`" when that file was removed.

**Signals:** Relative links to nonexistent files, references to functions/classes not found in the codebase, `CLAUDE.md` or `AGENTS.md` mentioning deleted paths.

### 4. Missing Docs for Public APIs

New public exports, endpoints, CLI commands, or configuration options with no corresponding documentation. Code grew but docs didn't.

**Signals:** Public functions/classes/exports with no mention in any doc file. New CLI flags not in help text or README. New environment variables not in `.env.example`.

### 5. .env.example Drift

`.env.example` missing variables the code actually reads, or listing variables the code no longer uses.

**Signals:** `process.env.X` / `os.environ["X"]` / `env::var("X")` references with no corresponding `.env.example` entry. `.env.example` entries with no code reference.

### 6. README Quick-Start Accuracy

README setup/install/run instructions that no longer work. Wrong commands, missing prerequisites, outdated Docker instructions, incorrect port numbers.

**Signals:** `npm start` documented but `package.json` has no `start` script. Docker Compose file referenced but missing. Port 3000 documented but code defaults to 8080.

### 7. Meta-Doc Integrity

`CLAUDE.md`, `AGENTS.md`, and similar meta-docs referencing files, functions, directories, or architectural patterns that don't exist in the current codebase.

**Signals:** CLAUDE.md references to deleted directories, nonexistent scripts, or removed configuration files. Architectural descriptions that don't match the actual structure.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | Docs accurate. Code examples match source, links resolve, APIs documented. |
| 70-89 | Minor staleness. A few outdated examples or missing entries, nothing misleading. |
| 50-69 | Multiple stale references. Docs lag behind code in several places. |
| 30-49 | Docs actively misleading. Quick-start doesn't work or API docs show wrong signatures. |
| 0-29 | Docs and code disconnected. Following the docs produces errors. |

Score = 100 minus weighted deductions. Critical findings deduct 10-15 each, warnings 3-5, info 1. Floor at 0.

## Output Contract

```json
{
  "score": 68,
  "grade": "50-69",
  "scope": "PR #87",
  "findings": [
    {
      "dimension": "stale-code-examples",
      "severity": "critical",
      "doc_file": "docs/api.md",
      "line": 42,
      "issue": "createUser() example shows 2 params, actual signature requires 3 (added `role` param in PR #71)",
      "referenced_source": "src/api/users.ts:18"
    },
    {
      "dimension": "dead-internal-references",
      "severity": "warning",
      "doc_file": "CLAUDE.md",
      "line": 15,
      "issue": "References scripts/migrate.sh which was deleted in commit a3f9c2d",
      "referenced_source": null
    },
    {
      "dimension": "env-drift",
      "severity": "warning",
      "doc_file": ".env.example",
      "line": null,
      "issue": "Missing REDIS_URL -- referenced in src/cache/client.ts:3 but absent from .env.example",
      "referenced_source": "src/cache/client.ts:3"
    }
  ],
  "top_fixes": [
    "Update createUser() example in docs/api.md to include role parameter (fixes stale example, score +12)",
    "Add REDIS_URL to .env.example (fixes env drift, score +4)",
    "Remove scripts/migrate.sh reference from CLAUDE.md (fixes dead reference, score +4)"
  ]
}
```

All fields required. `findings` ordered by severity descending, then by `doc_file`. `top_fixes` limited to 3, ordered by score impact.

## Modes

| Invocation | Scope | Behavior |
|------------|-------|----------|
| `/assess-docs` (during PR review) | PR diff | Check if changed code has doc references; flag if code changed but docs didn't. |
| `/assess-docs docs/` | Directory | Audit all docs in directory against current source. |
| `/assess-docs --full` | Entire repo | Full docs health audit. Every doc file checked against codebase. |

In PR review mode: if the diff modifies a public API, check whether any doc references that API and whether those references are still accurate. Warn if code changed but doc references were not updated.

## Integration Points

| Workflow | How |
|----------|-----|
| `/pr` | Warn if changed code has doc references but no doc update in the same PR |
| `/autopilot check-quality` | Run assess-docs on diff; fail if score < 50 or any critical finding |
| `/settle` | Include docs score in PR summary |
| `/groom` | Full docs audit to identify stale documentation for cleanup backlog |

## Process

1. Identify scope (diff, directory, or full repo).
2. For each doc file in scope, extract code references (file paths, function names, imports, env vars, links).
3. Resolve each reference against the actual codebase.
4. Classify unresolvable or mismatched references by dimension and severity.
5. Compute score.
6. Rank fixes by impact (critical findings first, then by how many dimensions the fix addresses).
7. Emit JSON output.

## Anti-Patterns

- Penalizing docs for not documenting internal/private APIs -- only public surfaces matter
- Treating intentionally terse docs as stale -- brevity is fine if accurate
- Flagging generated docs (typedoc, rustdoc output) -- those are regenerated, not hand-maintained
- Requiring every function to have prose docs -- only public APIs without any doc coverage are flagged
- Ignoring CLAUDE.md and AGENTS.md -- these are high-leverage docs that rot fast
