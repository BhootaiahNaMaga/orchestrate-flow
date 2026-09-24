# orchestrate-flow for Antigravity

Turns a goal plus 3-10 of your skills into an optimized, resumable graph of subagent stages and runs it for days.

## Install

| File | Global (all projects) | Or per project |
|---|---|---|
| `orchestrate-flow/` | `~/.gemini/config/skills/orchestrate-flow/` | `<project>/.agents/skills/orchestrate-flow/` |
| `agents/stage-worker.md` | `~/.gemini/config/agents/stage-worker.md` | `<project>/.agents/agents/stage-worker.md` |

`~/.gemini/config/` is the global path read by the Antigravity app, IDE, and CLI (2.0). Run `/skills reload` after copying.

## Use

In an **interactive** session (subagents do not survive headless `-p` runs):

```
/orchestrate-flow Spec to coverage closure for the clock-gating block, using bringup, testplan-gen, tb-gen, formal-debug, coverage
```

It audits the skills, interviews you in rounds, writes `plan.md` with a Mermaid graph, and waits for you to set `status: approved` in `.agents/runs/<run-id>/reviews/plan.md`. It then pilots one item, waits for your approval again, and fans out.

Watch `.agents/runs/<run-id>/STATUS.md`: what needs you is at the top. To resume after a session ends, run `/orchestrate-flow` again in the same project.

## Requirements

- Design code in git (each item gets its own worktree and branch; results merge into `flow/<run-id>`, never into your base branch).
- Each tool's TCL flow prints a **finish marker** (a log line or file) when done; the run judges completion by it.

## Verify on first use

These came from docs and community reports and are not yet tested against your installed version:

- `hooks.json` field names, and whether hook edits take effect without restart (`orchestrate-flow/HOOKS.md`).
- Whether `ask_question` blocks the agent.
- Subagent frontmatter fields `subagent` and `model` in `stage-worker.md`.
