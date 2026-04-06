# Demo as a scaffold skill — project-local demo generation

Priority: medium
Status: done
Estimate: M

## Goal

Redesign /demo from a generic global skill into a scaffold that generates project-local demo skills. Each project gets a customized demo skill tuned to its artifact types, capture methods, and upload targets.

## Why

Demo artifacts vary widely:
- Web app: GIF walkthroughs, route screenshots
- CLI: terminal session recordings (asciinema, VHS)
- API: request/response captures, cURL examples
- Library: before/after test output, benchmark charts

A generic skill can't encode these differences effectively.

## Scaffold Workflow

Same pattern as QA scaffold (see 008):
1. Investigate codebase to determine app type and artifact strategy
2. Design demo plan with user (which features to demo, what format)
3. Write project-local demo skill with app-specific capture methods

## Oracle
- [x] `/harness scaffold demo` in a web app repo produces GIF-focused demo skill
- [x] `/harness scaffold demo` in a CLI repo produces terminal recording demo skill
- [x] Generated skill knows the app's key features and how to capture them

## Depends On
- 008-scaffold-qa-skill (shared scaffold infrastructure in /harness) — done

## What Was Built
- `skills/harness/references/scaffold-demo.md` (196 lines) — Demo scaffold template
  following the same three-phase pattern as QA scaffold (Investigate → Design → Deliver).
  Three investigators (App Mapper, Feature Scout, Tooling Scout), design conversation
  guide with artifact strategy table (web→GIF, CLI→terminal, API→cURL, library→test diff),
  generated SKILL.md template with Planner→Implementer→Critic workflow, capture plan
  reference template, and quality gates checklist.
- `skills/harness/SKILL.md` — Updated scaffold dispatch to include `demo` alongside `qa`.
