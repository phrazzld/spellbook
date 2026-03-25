# Coverage Ratchet

## How It Works

The coverage ratchet prevents coverage from dropping. Ever.

```
.coverage-baseline.json  →  current coverage  →  comparison  →  pass/fail
```

1. **Baseline** lives in `.coverage-baseline.json`, committed to git.
2. **Current coverage** is read from the standard output location per language:
   - TypeScript: `coverage/coverage-summary.json` (vitest/istanbul json-summary)
   - Rust: `coverage/tarpaulin-report.json`
   - Go: `coverage/coverage.out` (go test -coverprofile)
   - Elixir: `cover/` directory (mix test --cover)
3. **Comparison**: each metric (branches, functions, lines, statements) must be >= baseline.
4. **Verdict**: if any metric dropped, the gate fails with a clear message showing which metric regressed.

## Starting Point

The baseline starts at zero:

```json
{
  "branches": 0,
  "functions": 0,
  "lines": 0,
  "statements": 0
}
```

This means the gate passes on day one. The moment you write your first test,
coverage goes above zero. The ratchet locks in that number.

## How the Ratchet Updates

On merge to main, CI runs with `UPDATE_BASELINE=true`:

```yaml
- name: Update coverage baseline
  if: github.ref == 'refs/heads/main'
  run: UPDATE_BASELINE=true python3 scripts/coverage-gate.py
```

This overwrites `.coverage-baseline.json` with current values. The updated
baseline is committed by CI (or by a bot commit step).

The ratchet only moves up because:
- PRs must meet or exceed the baseline to merge
- Main updates the baseline after merge
- Therefore the baseline only ever increases

## Overriding

Sometimes you legitimately need to lower coverage (deleting well-tested code,
removing a feature). Two options:

1. **Manual override**: edit `.coverage-baseline.json` directly, commit with
   justification in the commit message. PR reviewers should scrutinize this.

2. **Skip gate**: set `SKIP_COVERAGE_GATE=true` in CI env. This is a nuclear
   option — the gate still runs but exits 0 regardless. Use for emergencies only.

Neither option is silent. Both leave an audit trail in git history.

## Per-Language Coverage Extraction

### TypeScript (vitest v8)

Vitest with `json-summary` reporter writes `coverage/coverage-summary.json`:
```json
{
  "total": {
    "lines": { "pct": 85.2 },
    "statements": { "pct": 84.1 },
    "functions": { "pct": 90.0 },
    "branches": { "pct": 78.3 }
  }
}
```

### Rust (cargo-tarpaulin)

Tarpaulin with `--out json` writes JSON with a top-level coverage percentage.
The gate maps this to lines/statements (tarpaulin doesn't distinguish) and
sets branches/functions to 0 if not reported.

### Go (go test -coverprofile)

Parse the coverage.out file and compute line coverage percentage.
Go doesn't natively report branch/function coverage separately — the gate
uses line coverage for all four metrics.

### Elixir (mix test --cover)

Erlang cover tool outputs per-module coverage. The gate computes aggregate
line coverage across all modules.
