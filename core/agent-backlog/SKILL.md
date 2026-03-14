---
name: agent-backlog
description: |
  Design, audit, and overhaul product backlogs for AI-agent delivery.
  Use when: grooming a backlog, reducing issue sprawl, rewriting tickets to be agent-executable,
  running a full backlog overhaul.
  Keywords: backlog, groom, issues, agent-ready, overhaul, prioritize.
disable-model-invocation: true
---

# Agent Backlog

## Overview

Use this skill to turn a messy backlog into a small, prioritized, agent-executable roadmap.
Treat each issue as both a planning artifact and an execution prompt.

## Core Stance

- Reduce before adding.
- Keep one canonical issue per intent.
- Separate roadmap items from intake noise.
- Prefer deep, outcome-shaped issues over many shallow tickets.
- Write issues so a strong coding agent can execute them without hidden context.

## Workflow

For end-to-end overhaul, read `references/overhaul-workflow.md`.

## Routing

- General backlog strategy, ordering, pruning, and refinement:
  Read `references/backlog-doctrine.md`
- GitHub Issues, issue forms, labels, milestones, sub-issues, dependencies, and Projects:
  Read `references/github-issues.md`
- Writing or rewriting agent-ready issue bodies, acceptance criteria, boundaries, and verification:
  Read `references/agent-issue-writing.md`
- Running a full backlog overhaul:
  Read `references/overhaul-workflow.md`

## Collaboration

- Use `groom` when the session is interactive and exploratory.
- Use `github-cli-hygiene` for GitHub writes through `gh`.
- Follow any repo-local issue standards before posting or editing issues.
