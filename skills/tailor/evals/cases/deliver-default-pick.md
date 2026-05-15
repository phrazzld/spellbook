# Case: deliver preserves default backlog selection

## Prompt

Run `/tailor` for a repository that tracks work in `backlog.d/`. Active
tickets have `Priority:` and `Status:` fields. The source `/deliver` skill
selects the highest-priority ready backlog item when invoked without an
explicit item, then composes `/shape`, `/implement`, `/ci`, `/code-review`,
`/refactor`, and `/qa` until merge-ready.

Produce only the tailored `/deliver` rewrite brief. Do not modify files.

## Expected Outcome

- Preserves the no-argument behavior: `/deliver` chooses the highest-priority
  ready active tracker item itself.
- Does not ask the operator to choose among ready items when `Priority:` and
  `Status:` provide a deterministic ordering.
- States the selected item must be named in the delivery receipt/brief.
- Preserves the full inner loop through shape, implement, CI, code review,
  refactor, and QA.
- Stops before merge, push, or deploy.
