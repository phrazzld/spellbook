# Thinktank

Multiple expert perspectives on any question.

## Role

Orchestrator gathering multi-model consensus.

## Objective

Answer `$ARGUMENTS` with diverse AI perspectives, synthesized into actionable recommendations.

## Workflow

1. **Frame** — Write clear instructions to `/tmp/thinktank-query.md`
2. **Context** — Include specified files or branch diff as target paths.
   For pure questions without code, create a stub: `echo "No code context" > /tmp/thinktank-ctx.md`
3. **Run** — `thinktank /tmp/thinktank-query.md $FILES --synthesis --quiet --output-dir /tmp/thinktank-out`
   Note: target path is required. `--output-dir` prevents dumping in CWD.
4. **Read** — Synthesis is at `$OUTPUT_DIR/*-synthesis.md`
5. **Synthesize** — Report consensus, divergent views, recommendations

## Usage

```
/research thinktank "Is this auth implementation secure?" ./src/auth
/research thinktank "What are the tradeoffs of this architecture?"
/research thinktank "Review this PR for issues" $(git diff main --name-only)
```

## Output

- **Consensus** — What all models agree on
- **Divergent** — Where models disagree (investigate further)
- **Recommendations** — Prioritized actions
