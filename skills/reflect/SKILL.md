---
name: reflect
description: |
  Session retrospective, operator coaching, harness postmortem, and codification.
  Distill learnings into hooks/rules/skills while upgrading the user's prompts,
  technical specificity, and reusable vocabulary.
  Use when: "done", "wrap up", "what did we learn", "retro", "reflect",
  "calibrate", "how could I have asked better", "prompt better",
  "teach me from this session", "what should I learn from this".
  Trigger: /reflect, /retro, /calibrate.
argument-hint: "[distill|calibrate|coach|tune-repo|append] [context]"
---

# /reflect

Structured reflection that improves both the harness and the operator.

Every finding becomes one of three things:
- a codified artifact
- a concrete coaching note
- an explicit justification for not codifying

## Execution Stance

You are the executive orchestrator.
- Keep severity ranking, responsibility split, codification target selection,
  and final teaching points on the lead model.
- Delegate evidence gathering and drift scanning to focused subagents.
- Run evidence-gathering subagents in parallel by default.

## Routing

| Mode | Intent | Reference |
|------|--------|-----------|
| **distill** (default) | End-of-session retrospective -> codified artifacts + operator coaching | `references/distill.md` |
| **calibrate** | Mid-session harness postmortem — fix the harness before the code | `references/calibrate.md` |
| **coach** | Deep dive on prompt quality, technical specificity, and concept building | `references/coach.md` |
| **tune-repo** | Refresh context artifacts, detect drift, update repo guidance | `references/tune-repo.md` |
| **append** | Append issue-scoped retro notes for `/groom` to consume later | `references/retro-format.md` |

If the first argument matches a mode name, route to that reference.
If no mode is provided, run `distill`.

Interpret natural-language requests as:
- "how could I have asked better", "teach me from this", "help me prompt better"
  -> `coach`
- "why did you do that", "you made the wrong call", "fix your instructions"
  -> `calibrate`
- "tune this repo", "refresh AGENTS", "context drift"
  -> `tune-repo`

## Responsibility Split

Reflection must separate three classes of failure:

1. **Harness failure** — the instructions, skills, tools, or codebase should
   have prevented the problem
2. **Shared ambiguity** — both sides left important constraints implicit
3. **Operator-spec gap** — the decisive information lived only in the user's
   head, so a tighter prompt would have reduced search space

Do not dump harness failures onto the user. If the repo, docs, or available
context already contained the answer, that is not a prompt-quality critique.

## Default Deliverables

Even in `distill`, inspect both lanes:
- **System lane** — instructions, skills, hooks, tests, CI, AGENTS.md, docs
- **Operator lane** — prompt rewrites, vocabulary, stack concepts, next-session moves

System codification is mandatory.
Operator coaching is mandatory to assess, but only mandatory to emit when there
is concrete, high-leverage feedback. Otherwise say so explicitly instead of
manufacturing generic advice.

Use `coach` when the user wants the operator lane expanded into a deeper lesson.

## Codification Hierarchy

When encoding knowledge, always target the highest-leverage mechanism:

```
Type system > Lint rule > Hook > Test > CI > Skill/reference > AGENTS.md > Memory
```

## Gotchas

- **Blaming the user for missing repo context**: If the agent could have found
  it, it is a harness or retrieval failure.
- **Giving generic prompt advice**: "Be more specific" is not feedback. Name
  the missing constraint, example, acceptance test, or boundary.
- **Skipping the operator lane**: A retro that only mutates harness artifacts
  leaves user leverage on the table.
- **Turning coaching into scolding**: Start with what the prompt achieved, then
  show the stronger version and why it improves the search space.
- **Teaching concepts without anchoring them to the session**: Vocabulary only
  sticks when tied to a concrete decision, bug, or design tradeoff.
