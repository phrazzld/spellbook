# Close the review score → skill evolution feedback loop

Priority: medium
Status: pending
Estimate: M

## Goal

Turn `.groom/review-scores.ndjson` from passive data into an active feedback
loop that improves review quality over time. When review patterns emerge
(repeated low scores in a dimension, persistent false positives), surface
them and suggest skill instruction changes.

## Design

1. **Score enforcement**: `/code-review` MUST append to review-scores.ndjson
   after every review (currently "wired but operationally empty")
2. **Trend detection**: `/groom` Velocity investigator analyzes score trends
   and flags regressions (e.g., "correctness scores declining over last 5 reviews")
3. **Skill tuning suggestions**: When a pattern is detected, `/reflect` proposes
   concrete skill instruction changes (not just observations)
4. **Calibration**: Periodically compare agent review findings against actual
   bugs found post-merge to measure review effectiveness

## Oracle

- [ ] Every `/code-review` invocation appends a score entry
- [ ] `/groom` reports score trends when 5+ entries exist
- [ ] `/reflect` proposes skill changes based on score patterns
- [ ] False positive rate is tracked (reviews that flagged non-issues)

## Non-Goals

- Automatic skill modification (human approves changes)
- External dashboards
