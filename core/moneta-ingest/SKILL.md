---
name: moneta-ingest
disable-model-invocation: true
description: |
  Parse new financial documents into Moneta. Detect type, run parser, validate output, summarize reconciliation.
user-invocable: true
---

# /moneta-ingest

Parse new financial documents into Moneta.

## Steps

1. Scan `source/` for new files and record expected sources and date ranges.
2. Detect document type from filename prefix. If unclear, sniff content headers or PDF table titles.
3. Map type to parser and run it.
4. Validate parser outputs: count, totals, date range, no duplicate IDs.
5. Update aggregates and lots.
6. Emit reconciliation summary with deltas and any warnings.

Type map:

```
bofa       -> pnpm parse:bofa
river      -> pnpm parse:river
strike     -> pnpm parse:strike
cashapp    -> pnpm parse:all   (includes cashapp PDF parsing)
robinhood  -> pnpm parse:all
w2         -> pnpm parse:all
charitable -> pnpm parse:all
```

## Examples

```bash
# Parse everything and rebuild aggregates
pnpm parse:all
```

```bash
# Parse only BofA CSVs
pnpm parse:bofa
```

## References

- `source/`
- `normalized/transactions.json`
- `normalized/cost-basis.json`
- `normalized/accounts.json`
- `scripts/parse-all.ts`
- `scripts/parse-bofa.ts`
- `scripts/parse-river.ts`
- `scripts/parse-strike.ts`
- `scripts/parse-cashapp.ts`
- `scripts/parse-robinhood.ts`
- `scripts/parse-w2.ts`
- `scripts/parse-charitable.ts`
