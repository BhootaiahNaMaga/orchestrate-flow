# Flow Profile Format

A **flow profile** is a proven graph kept for reuse, saved in `profiles/<slug>.md` inside this skill's folder. It is how "optimum" improves across runs: each run starts from the best graph so far instead of designing from scratch.

## Template

```md
---
slug: spec-to-coverage
goal: Spec → testplan → testbench → verification → coverage closure
skills: [bringup, testplan-gen, tb-gen, formal-debug, coverage]
runs: 3
last_run: 20260923-spec-to-coverage
---
## Graph
<the plan.md Graph and Stages sections from the best run, with tuned caps>

## Tuned settings
- concurrency: global 10, formal 4
- loop caps that worked: lint hard cap 8; formal hard cap 15
- hooks worth installing from the start: scope-guard, lint-after-edit

## Lessons
- <avoidable problem → how the graph, brief, or hook now prevents it>

## Metrics by run
| Run | Items | Done | Blocked | Findings | Wall-clock | Human touches |
|---|---|---|---|---|---|---|
```

## retrospective.md (per run, feeds the profile)

- Where wall-clock went: the actual critical path vs the plan's expected one.
- Loops that stalled, grouped by root cause.
- Mid-run notes and hooks: which helped (keep in the profile) and which did not (drop).
- Findings handed to the user.
- Proposed graph changes for next time.

## Rules

- **Update, don't fork.** A run on the same goal updates its profile; create a new profile only for a different goal or skill set.
- **Only proven changes enter the profile.** A hook or note joins "hooks worth installing" once it measurably helped in a run.
- **A profile is a starting point.** The interview still runs, covering only what differs from the profile.
