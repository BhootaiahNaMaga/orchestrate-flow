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

---

# graph-test for Antigravity

Tests any graph skill against real designs with no human in the loop: writes a test plan, launches fresh runs in new chats via the agentapi skill, watches and judges them, patches the graph skill, and re-runs until it passes.

## Install

| File | Global (all projects) | Or per project |
|---|---|---|
| `graph-test/` | `~/.gemini/config/skills/graph-test/` | `<project>/.agents/skills/graph-test/` |

Run `/skills reload` after copying.

## Use

In an **interactive** session:

```
/graph-test graph_skill=/path/to/foo-graph designs=[designA, designB]
```

Optional: `max_rounds` (10), `max_wallclock` (7d), `max_tries_per_issue` (5), `poll_minutes` (15).

1. It writes `graphtest/<id>/testplans/<design>.md` (per node: intention, subagent or inline, loops, learnings, hang timeout, plus the answer sheet) and waits for you to set `status: approved` in `reviews/testplan-<design>.md`.
2. It runs a fresh baseline on every design, stopping a run early once it is certain to fail (a node inline that should be a subagent, a missing or broken loop, a hang).
3. Per issue it commits one patch on `graphtest/<id>` in the graph skill repo, reruns from scratch on the failing design, then on all designs. Failed patches are reverted; after 5 tries the issue is `needs-human`.
4. It ends with a fresh vs learnings-kept run per design and writes `graphtest/<id>/report.md`.

To resume after a session ends, run `/graph-test` again in the same project. Kept patches stay on the `graphtest/<id>` branch for you to merge.

## Verify on first use

- The agentapi skill's name and how it is called for start chat, send message, read transcript/trace, status, and stop chat.
- That a harness chat can poll for hours (and resume cleanly when it cannot).
- That the trace shows subagent dispatch clearly enough to tell it apart from work done inline.
