---
name: scaffold
description: |
  Initialize a new project with the full quality stack: strict typing,
  coverage ratchet, CI gates (deterministic + agent-first), pre-commit
  hooks, env validation, mutation testing, and observability. Supports
  TypeScript, Rust, Go, and Elixir.
argument-hint: '--lang typescript|rust|go|elixir [--name project-name]'
---

# /scaffold

One command, full quality stack. No project ships without gates.

**The user's arguments:** $ARGUMENTS

## Phase 1: Detect or Accept Language

1. If `--lang` provided, use it.
2. Otherwise detect from existing files:
   - `package.json` → TypeScript
   - `Cargo.toml` → Rust
   - `go.mod` → Go
   - `mix.exs` → Elixir
3. If no detection, ask the user.

If `--name` provided, use it as project name. Otherwise use current directory name.

## Phase 2: Generate Deterministic Quality Stack

Generate all config files for the detected language. Every file uses the strictest
viable defaults — loosen later, never start loose.

### TypeScript

**`tsconfig.json`**:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "node16",
    "moduleResolution": "node16",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "declaration": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

**`eslint.config.js`** — flat config:
```js
import tseslint from 'typescript-eslint';
import sonarjs from 'eslint-plugin-sonarjs';

export default tseslint.config(
  tseslint.configs.strict,
  sonarjs.configs.recommended,
  {
    rules: {
      'sonarjs/cognitive-complexity': ['error', 10],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'error',
    },
  },
  { ignores: ['dist/', 'coverage/'] },
);
```

**`vitest.config.ts`**:
```ts
import { defineConfig } from 'vitest/config';
import baseline from './.coverage-baseline.json' with { type: 'json' };

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'lcov'],
      thresholds: {
        branches: baseline.branches,
        functions: baseline.functions,
        lines: baseline.lines,
        statements: baseline.statements,
      },
    },
  },
});
```

**`lefthook.yml`**:
```yaml
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.{ts,tsx}"
      run: npx eslint {staged_files}
    typecheck:
      run: npx tsc --noEmit
```

### Rust

**`.cargo/config.toml`**:
```toml
[build]
rustflags = ["-D", "warnings"]
```

**`clippy.toml`**:
```toml
cognitive-complexity-threshold = 10
```

**`deny.toml`**:
```toml
[advisories]
vulnerability = "deny"
unmaintained = "warn"

[licenses]
unlicensed = "deny"
allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "Unicode-3.0"]

[bans]
multiple-versions = "warn"
wildcards = "deny"
```

**`lefthook.yml`**:
```yaml
pre-commit:
  parallel: true
  commands:
    clippy:
      run: cargo clippy --all-targets -- -D warnings
    fmt:
      run: cargo fmt --check
```

### Go

**`.golangci.yml`**:
```yaml
linters:
  enable:
    - gocyclo
    - gocognit
    - dupl
    - nestif
    - goconst
    - errcheck
    - gosec
    - bodyclose
    - prealloc
linters-settings:
  gocyclo:
    min-complexity: 10
  gocognit:
    min-complexity: 10
  nestif:
    min-complexity: 3
  dupl:
    threshold: 100
```

**`lefthook.yml`**:
```yaml
pre-commit:
  parallel: true
  commands:
    lint:
      run: golangci-lint run ./...
    vet:
      run: go vet ./...
```

### Elixir

**`.credo.exs`**:
```elixir
%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: [
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 10},
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Refactor.PerceivedComplexity, max_complexity: 10},
        {Credo.Check.Design.AliasUsage, false},
      ]
    }
  ]
}
```

**`lefthook.yml`**:
```yaml
pre-commit:
  parallel: true
  commands:
    credo:
      run: mix credo --strict
    format:
      run: mix format --check-formatted
    dialyzer:
      run: mix dialyzer --format short
```

## Phase 3: Generate CI Workflows

Create `.github/workflows/` directory if it doesn't exist.

### `.github/workflows/merge-gate.yml`

```yaml
name: merge-gate
on:
  pull_request:
    branches: [main, master]
  push:
    branches: [main, master]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  gate:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
```

Then append language-specific steps:

**TypeScript steps:**
```yaml
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx eslint .
      - run: npx vitest run --coverage
      - name: Coverage ratchet
        run: python3 scripts/coverage-gate.py
      - name: Mutation testing
        if: env.SKIP_MUTATION != 'true'
        run: npx stryker run --incremental --since main
      - name: Secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
```

**Rust steps:**
```yaml
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - run: cargo fmt --check
      - run: cargo clippy --all-targets -- -D warnings
      - run: cargo test
      - run: cargo deny check
      - name: Coverage ratchet
        run: |
          cargo install cargo-tarpaulin --locked
          cargo tarpaulin --out json --output-dir coverage/
          python3 scripts/coverage-gate.py
      - name: Mutation testing
        if: env.SKIP_MUTATION != 'true'
        run: |
          cargo install cargo-mutants --locked
          cargo mutants --timeout 60 --in-diff <(git diff origin/main...HEAD)
      - name: Secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
```

**Go steps:**
```yaml
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go vet ./...
      - run: golangci-lint run ./...
      - run: go test -race -coverprofile=coverage/coverage.out ./...
      - name: Coverage ratchet
        run: python3 scripts/coverage-gate.py
      - name: Mutation testing
        if: env.SKIP_MUTATION != 'true'
        run: |
          go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest
          go-mutesting ./...
      - name: Secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
```

**Elixir steps:**
```yaml
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.17'
          otp-version: '27'
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix credo --strict
      - run: mix format --check-formatted
      - run: mix test --cover
      - name: Coverage ratchet
        run: python3 scripts/coverage-gate.py
      - name: Mutation testing
        if: env.SKIP_MUTATION != 'true'
        run: mix muzak --since main
      - name: Secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
```

### `.github/workflows/agent-review.yml`

```yaml
name: agent-review
on: [pull_request]

jobs:
  assess:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    strategy:
      matrix:
        check: [depth, tests, drift, intent, review, docs]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: |
          git diff origin/${{ github.base_ref }}...HEAD > /tmp/diff.txt
          python3 .assess/run.py --check ${{ matrix.check }} \
            --diff /tmp/diff.txt --output /tmp/result.json
          python3 .assess/gate.py /tmp/result.json
        env:
          LLM_API_KEY: ${{ secrets.LLM_API_KEY }}
```

## Phase 4: Generate Ratchet Baselines

**`.coverage-baseline.json`**:
```json
{
  "branches": 0,
  "functions": 0,
  "lines": 0,
  "statements": 0
}
```

Starts at zero. Only goes up. See `references/coverage-gate.md` for the mechanism.

**`scripts/coverage-gate.py`**: Copy from `assets/coverage-gate.py` in this skill.

## Phase 5: Generate Supporting Files

**`.env.example`** — placeholder with comments:
```
# Required
# DATABASE_URL=postgresql://localhost:5432/myapp

# Optional
# LOG_LEVEL=info
# SENTRY_DSN=
```

**`.spellbook.yaml`** — declare quality primitives:
```yaml
skills:
  - debug
  - autopilot
  - pr
  - settle
```

**`.gitignore` additions** — append if not already present:
```
# Coverage
coverage/
*.lcov

# Build
dist/
target/

# Environment
.env
.env.local
```

## Phase 6: Report

Print a summary table:

```
/scaffold complete

  Language:  TypeScript
  Files:     12 created, 2 modified

  Created:
    tsconfig.json
    eslint.config.js
    vitest.config.ts
    lefthook.yml
    .github/workflows/merge-gate.yml
    .github/workflows/agent-review.yml
    .coverage-baseline.json
    scripts/coverage-gate.py
    .env.example
    .spellbook.yaml

  Next steps:
    1. npm install (installs deps from generated config)
    2. npx lefthook install (activates pre-commit hooks)
    3. git add -A && git commit -m "scaffold: full quality stack"
    4. /focus (pulls spellbook skills declared in .spellbook.yaml)
```

Adapt file list and next steps per language.

## Invariants

- **Never overwrite existing files** without asking. If `tsconfig.json` exists, show diff and ask.
- **Strictness is load-bearing.** Never weaken a default. Users loosen later if needed.
- **Coverage starts at zero.** The ratchet only moves up. This is intentional — it means
  the gate passes on day one but prevents regression from the first test onward.
- **CI must be deterministic.** No flaky steps. Mutation testing is opt-out via `SKIP_MUTATION`.
- **Pre-commit hooks are fast.** Only lint and typecheck on staged files. Tests run in CI.
