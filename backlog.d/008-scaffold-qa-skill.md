# QA as a scaffold skill — project-local QA generation

Priority: medium
Status: done
Estimate: L

## Goal

Redesign /qa from a generic global skill into a scaffold that generates project-local QA skills. Each project gets a customized QA skill with app-specific personas, routes, dev commands, and evidence strategies.

## Why

QA is too repo-specific for a generic global skill. A restaurant SaaS needs "restaurant owner managing their menu" personas, not generic "new user." The dev command, auth mechanism, key routes, and evidence format vary per project.

## The Scaffold Workflow

Invoked via `/harness scaffold qa` (or similar):

### 1. Investigate (parallel sub-agents)
- Map the codebase: web app, CLI, API, or library?
- Find dev command, port, entry points, key routes/features
- Check for sister applications, shared services, existing test infrastructure
- Read CLAUDE.md, README, package.json for context
- Identify auth mechanism and test credentials

### 2. Design (conversation with user)
- Present findings and proposed QA plan
- Create user personas specific to this app
- Select browser tools (Chrome MCP vs Playwright vs Stagehand) based on app characteristics
- Iterate with user until plan is solid

### 3. Deliver (write project-local skill)
- `.claude/skills/qa/SKILL.md` — customized for this app
- `.claude/skills/qa/references/personas.md` — app-specific user personas
- `.claude/skills/qa/references/qa-plan.md` — structured test plan

## Research Needed
- Study skill builder/creator patterns from Anthropic, OpenAI, Vercel, and other frontier labs
- Review how /harness create works today and extend for scaffold mode
- Understand how /groom scaffold bootstraps project infrastructure (reuse patterns)

## Oracle
- [x] `/harness scaffold qa` in a sample repo produces a project-local QA skill
- [x] Generated skill includes app-specific personas (not generic)
- [x] Generated skill knows the dev command and key routes
- [x] Running the generated `/qa` skill exercises the actual app

## Non-Goals
- Don't remove the global /qa skill entirely — it becomes the scaffold template
- Don't auto-discover everything — the scaffold is a conversation, not a one-shot

## What Was Built

Added `scaffold` mode to `/harness` with a generic three-phase workflow
(Investigate -> Design -> Deliver) and a QA-specific template.

**Files changed:**
- `skills/harness/SKILL.md` — new `scaffold` mode in modes table, description
  trigger phrases, argument-hint, and full scaffold workflow section (~60 lines)
- `skills/harness/references/scaffold-qa.md` — QA scaffold template (263 lines)
  with investigation prompts (App Mapper, Route Scout, Context Scout), design
  conversation guide, generated SKILL.md template, and quality gate checklist

**Design decisions:**
- Scaffold is instructions for the agent, not a code generator — pure markdown
- Three parallel investigators produce structured findings, not prose
- Generated skill template matches flywheel-qa exemplar structure (Role,
  Objective, Prerequisites, Critical Paths, Interactive Flows, Regression
  Checks, Console Error Audit, Evidence, Output)
- Template dispatch via `references/scaffold-<name>.md` makes 009 (demo scaffold)
  a single-file addition
- Global /qa skill unchanged — scaffold reads it as reference, never writes it
