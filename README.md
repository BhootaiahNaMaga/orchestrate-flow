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

## Preflight

The platform behaviour below came from docs and community reports and is not yet tested against your installed version. Before the first long run, check each item on a small throwaway flow and record it in `.agents/preflight.md`: Antigravity version, date, and for each check the observed result (`works`, `differs: <how>`, or `fails`). Fix the skill files for anything that differs.

- **Dispatch**: `stage-worker` runs as a subagent (frontmatter fields `subagent` and `model` are honoured) and can read its plan and write its records from its worktree.
- **Hooks**: `hooks.json` field names match `orchestrate-flow/HOOKS.md`; whether an edit takes effect without restart; `Stop` → `continue` re-enters the loop.
- **Approval**: setting `status: approved` in a review file is picked up on the next cycle; whether `ask_question` blocks the agent.
- **Stop and resume**: end the session mid-run, run `/orchestrate-flow` again, and confirm it reconciles `ops` and adopts or cancels the live tool job instead of launching a second one.
- **Scheduler**: the status and cancel commands report and stop a real job.

`bash tests/rollback.sh` checks the loop's restore-to-best commands on a throwaway repo.

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

Optional: `max_rounds` (10), `max_wallclock` (7d), `hard_deadline` (none), `max_tries_per_issue` (5), `poll_minutes` (15).

1. It writes `graphtest/<id>/testplans/<design>.md` (per node: intention, subagent or inline, loops, learnings, hang timeout, plus the answer sheet) and waits for you to set `status: approved` in `reviews/testplan-<design>.md`.
2. It runs a fresh baseline on every design, stopping a run early once it is certain to fail (a node inline that should be a subagent, a missing or broken loop, a hang).
3. Per issue it commits one patch on `graphtest/<id>` in the graph skill repo, reruns from scratch on the failing design, then on all designs. Failed patches are reverted; after 5 tries the issue is `needs-human`.
4. It ends with a fresh vs learnings-kept run per design and writes `graphtest/<id>/report.md`, stating whether that confirmation passed (`confirmed`) or was `unconfirmed`, `inconclusive`, or `skipped`.

To resume after a session ends, run `/graph-test` again in the same project. Kept patches stay on the `graphtest/<id>` branch for you to merge.

## Preflight

Record these in the same `.agents/preflight.md`, the same way, before the first batch:

- **agentapi**: the skill's name and how it is called for start chat, send message, read transcript/trace, status, and stop chat; whether stop chat also stops the chat's tool jobs.
- **Polling**: a harness chat can poll for hours, or resumes cleanly from `graphtest/<id>/` when it cannot.
- **Trace**: subagent dispatch is visible clearly enough to tell it apart from work done inline.
- **Approval**: the harness can answer both a chat question and a review-file gate of the graph under test.
