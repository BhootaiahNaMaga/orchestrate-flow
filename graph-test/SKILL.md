---
name: graph-test
description: Test a graph skill (a long-running multi-node agent flow) against real designs without a human in the loop - write a test plan, launch fresh runs in new chats via the agentapi skill, watch and judge them, patch the graph skill, and re-run until it passes. Use when the user asks to test, verify, harden, or regression-check a graph skill, or to resume a run in graphtest/.
---

You are the **harness**. You stand in for the engineer who would otherwise launch the graph, watch it for hours, work out what went wrong, and feed back a fix, 10-20 times. You never do the graph's work yourself: you launch it, answer it, judge it, and patch it. The **state folder** is your memory, not this conversation: a batch lasts days and your context will not.

Terms used throughout:

- **Graph skill**: the skill under test (its repo is `graph_skill`). Launched per design as `foo-graph <design>` (the exact command comes from the graph skill).
- **Node**: one stage of the graph. Each has an **intention**: the outcome that makes it done.
- **Run**: one fresh launch of the graph on one design, in its own chat.
- **Issue**: a place where a run broke an expectation in the test plan. Issues are patched.
- **Finding**: a root cause outside the graph skill (design, tool flow, licenses, agentapi). Findings are reported, never patched.
- **Patch round**: one patch, the runs that test it, and the keep/revert decision.

Formats: test plan [TESTPLAN-FORMAT.md](TESTPLAN-FORMAT.md), judging [JUDGE.md](JUDGE.md), state folder [STATE.md](STATE.md).

## Inputs

| Input | Default |
|---|---|
| `graph_skill` | required: path to the graph skill's git repo |
| `designs` | required: list of designs (1 to 5 typical) |
| `max_rounds` | 10 patch rounds per batch |
| `max_wallclock` | 7 days |
| `max_tries_per_issue` | 5 patches, then `needs-human` |
| `poll_minutes` | 15 |

## agentapi

All chat control goes through Antigravity's built-in **agentapi** skill. Read it in full before step 3. You use five operations, and only these:

| Operation | Used for |
|---|---|
| start chat | a fresh chat per run, with the launch message |
| send message | answering the graph's questions from the answer sheet |
| read transcript / trace | watching and judging |
| status | is the chat running, waiting on a question, or ended |
| stop chat | early abort |

Record the chat id of every run in `state.json` the moment you have it.

## 0. Resume first

List `graphtest/`. If the user named a batch, or exactly one batch has `state.json` with `phase` other than `closed`, read its `state.json`, `log.md`, and the latest `report.md`, then continue from the step its `phase` names. For each run marked `running`, query its chat status before doing anything else. Never restart a batch that has state.

Otherwise create `graphtest/<yyyymmdd>-<slug>/`, record the inputs in `state.json`, and continue with step 1.

## 1. Test plan

Per design:

1. Read the graph skill in full: every skill, subagent, and plan file it uses. Read the design folder enough to know which nodes and items will apply.
2. Write `testplans/<design>.md` in the format of TESTPLAN-FORMAT.md: every node with its intention, whether it must run as a subagent, its loops (exit check, progress measure, round cap), the learnings-log entries it should write, and its hang timeout; plus the **answer sheet**: every question the graph will ask the user, with the fixed answer (`approve` for every gate).
3. Write `reviews/testplan-<design>.md` (status `pending`) and set `phase: awaiting-testplan-approval`.

Nothing launches until the engineer sets `status: approved`. On `changes-requested`, revise and return here. When a later patch changes the graph's structure (nodes, loops, questions), update the test plan and send only the diff back for approval; other patches need no re-approval.

## 2. Branch

In `graph_skill`, create `graphtest/<batch-id>` from its current branch and record the base commit. Every patch is one commit here. Never touch the base branch; merging kept patches is the engineer's call.

## 3. Launch

A run is always **fresh**:

- A clean clone or worktree of the design, recorded in `runs/<run-id>/meta.json`.
- An empty graph run folder: no state, memory, or learnings from earlier runs, except in the learnings-kept run of step 8.
- The graph skill installed from the commit under test (`/skills reload` in the new chat before launching).
- A new chat via agentapi whose first message is the launch command.

Launch all designs that need a run at once, up to the concurrency the engineer allows (none stated: all). Set the run `running`.

The first launch is the **baseline** (`phase: baseline`): every design, unpatched. Its verdicts seed `issues.md`; then go to step 6.

## 4. Watch

Every `poll_minutes`, for each running run:

1. Read the new part of the transcript and trace since the last poll (keep a cursor in `state.json`).
2. **Questions**: the graph is waiting on the user when the chat asks a question **or** a review file on the answer sheet is `pending` in the run's folder. Answer from the answer sheet through its **How** channel: send message, or edit that review file. A question not on the sheet is an issue (`unplanned-question`); answer it with the most conservative option, record exactly what you answered, and carry on.
3. **Early checks** from JUDGE.md "Watch-time checks": a node that should run as a subagent ran inline, a loop missing or broken, a node past its hang timeout with no trace or log growth.
4. **Abort** when an issue is certain to spoil the run (the graph cannot reach a correct end from here): stop the chat, set the run `aborted` with the issue. Stopping a chat does not stop its tool jobs: read live job ids from where the test plan's `jobs` line says, cancel each with its cancel command, and record the result. A job that won't confirm cancelled is a finding and counts against concurrency until it ends. Otherwise record the issue and let the run continue: later nodes still yield evidence.
5. When the chat ends, set the run `ended` and go to step 5 for it.

Append every poll's outcome to `runs/<run-id>/watch.md`. Keep only the run summary in your context; the transcript stays on disk.

## 5. Judge

For each ended or aborted run, dispatch a subagent with JUDGE.md, the test plan, and the run's transcript and trace paths (a full transcript is too large for your context). It writes `runs/<run-id>/verdict.md`. Verify two or three cited evidence lines exist before trusting the verdict.

Classify each failed expectation as an **issue** (root cause in the graph skill) or a **finding** (root cause elsewhere). Merge issues across runs by root cause into `issues.md`, each with an id, the runs that hit it, and its tries so far.

## 6. Patch

Pick the open issue that blocks the most nodes (ties: earliest node in the graph). One patch per round:

1. Read the evidence and every earlier attempt at this issue in `issues.md`. Do not repeat a reverted approach.
2. Edit only files inside `graph_skill`. Commit with the message `graphtest: <issue-id> try <n>: <root cause>`.
3. Relaunch **from scratch** (step 3) on the design that showed the issue only. Watch and judge as usual.
4. **Pass**: the issue is gone and every node's intention on that design is met at least as well as before. Go to step 7.
5. **Fail**: `git revert` the commit, record why it failed, tries +1. At `max_tries_per_issue`, mark the issue `needs-human` with all attempts and move to the next issue.

## 7. Regression check

Run the patched graph from scratch on **all** designs. **Keep** the patch only if the target issue is gone on every design that had it and no node that passed before now fails on any design. Otherwise revert it and count it as a failed try on its issue. Update `report.md` after every round (step 9 format).

Loop back to step 6 until no open issue remains, or `max_rounds` or `max_wallclock` is reached. At a limit, start nothing new, let running runs end, and go to step 9.

## 8. Final confirmation

On the final commit, per design:

1. A fresh run with learnings wiped.
2. A second run with the first run's learnings kept.

Compare the pair as JUDGE.md "Learnings reuse" describes. This is the only place learnings carry over between runs.

## 9. Report

Write `report.md`:

- **Summary**: batch id, graph skill commits (base, final), designs, rounds used, wall-clock used, why it stopped.
- **Per design, per node**: intention met / not met / not reached, subagent correct, loops correct, from the last full run.
- **Issues**: each with status (`fixed`, `needs-human`, `open`), the patches kept and reverted, and the evidence.
- **Learnings log**: the four verdicts from JUDGE.md, and the reuse comparison from step 8.
- **Findings**: root causes outside the graph skill, for the engineer.
- **Went well / didn't**: a few lines each.

Set `phase: closed`. Report in the chat: the branch with kept patches, counts of fixed / needs-human / findings, and the path to `report.md`.

## Rules

- Trust the files over your memory: re-read `state.json` at the start of every poll cycle.
- Write `state.json` after every change (temp file, then rename) and append to `log.md`.
- Never ask the engineer anything outside the review files, except when nothing can progress without them.
- **Write scopes**. Each kind of write has one home:
  - patches: files inside `graph_skill`, on the `graphtest/<id>` branch;
  - harness state: `graphtest/<id>/`;
  - test controls: the review files named on an approved answer sheet, inside a run's own disposable folder.

  The design and the tool flow stay read-only; their problems are findings.
