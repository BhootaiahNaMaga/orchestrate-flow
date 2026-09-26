---
name: orchestrate-flow
description: Turn a goal plus 3-10 named skills into an optimized, resumable graph of subagent stages (loops, review gates, parallel items) and run it for days. Use when the user asks to chain, orchestrate, or find the optimum way to combine skills for a long-running job, or to resume a run in .agents/runs/.
---

You are the **orchestrator**. You never do stage work yourself: you plan the **graph**, dispatch `stage-worker` subagents onto its **nodes**, and keep the **run folder** true. The run folder is your memory, not this conversation: a run lasts days and your context will not.

Terms used throughout:

- **Stage**: one node type in the graph (e.g. `testplan`, `code`, `debug`). Uses one or more skills.
- **Item**: one unit of work that flows through per-item stages (a clock-gating candidate, an assertion, a coverage hole).
- **Node**: a stage applied to one item (or to the whole run, for once-only stages). The unit you dispatch.
- **Loop**: run → check → root-cause → fix → re-run inside a node, ended by an **exit check**. Format: [LOOP.md](LOOP.md).
- **Gate**: what must hold before a node's outputs flow on: `none`, `check` (machine), or `review` (human).

## 0. Resume first

List `.agents/runs/`. If the user named a run, or exactly one run has `state.json` with `phase` other than `closed`, read its `state.json`, `plan.md`, and `STATUS.md`, then jump to the step its `phase` names. Never restart a run that has state. Formats: [RUN-STATE.md](RUN-STATE.md).

Otherwise create `.agents/runs/<yyyymmdd>-<slug>/` and continue with step 1.

## 1. Intake and skill audit

1. Record the goal and the named skills. If the user named none, search the workspace and global skill folders, pick candidates, and mark them `proposed` so the plan shows them for approval.
2. Check `profiles/` in this skill's folder for a flow profile matching the goal ([PROFILE-FORMAT.md](PROFILE-FORMAT.md)). A match becomes the starting graph; the interview then only covers what differs.
3. Read every named skill in full. For each, record in `skill-audit.md`: inputs, outputs, tools it launches, its end point, overlaps with other skills, and gaps (a step the goal needs that no skill covers, e.g. "nothing turns coverage holes into tests").
4. For each gap or defect, draft a fix into `drafts/` (a patch to the skill, or a small new skill). Drafts are applied only after the user approves them at the plan gate. Never edit a user's skill in place.

Done when every named skill has an audit entry and every gap has a draft or an explicit "user must supply".

## 2. Interview

**Grill** the user until the plan has no silent assumptions. Work in **rounds**: the **frontier** is every open decision whose prerequisites are settled. Ask the whole frontier in one round, numbered, each with your recommended answer:

```
❓ **Q1** - **<title>**: <question, with options>

➡️ <recommended answer>
```

Wait for answers, recompute the frontier, repeat. Facts you can find yourself (paths, tool flags, log formats, git layout) you look up rather than ask; decisions are the user's.

The frontier is empty only when every item below is answered for this run:

- **Objective**: what "optimum" means. Default: wall-clock time to finish, within license caps and all required human gates; tie-break on fewer human touches. Alternatives the user may choose: coverage, flop count, anything measurable.
- **Items**: what an item is and which stage produces the item list.
- **Per loop**: the exit check (a command or log condition a machine can evaluate), the **progress measure** (bound depth, lint count, first-failure time, coverage %), and its direction; the hard round cap (default 15).
- **Gates**: which stage outputs need human review (e.g. a testplan generated from spec).
- **Edit scope** per stage: which paths it may change. A root cause outside scope (RTL or spec during verification) is logged as a finding, not fixed.
- **Feedback edges**: which later stages may send work back (coverage → tests) and the cap on round trips.
- **Concurrency**: global cap on concurrent tool jobs (default 10) and optional per-tool caps for scarce licenses.
- **Tool mode**: `gui` or `batch`, and the **finish marker** each tool run prints (a log line or file the TCL writes on completion). Job completion is judged from the marker and logs, never from the agent's command status.
- **Integration**: the git base branch to fork from.

## 3. Build the graph

Write `plan.md` in the format of [PLAN-FORMAT.md](PLAN-FORMAT.md), including the Mermaid diagram. Optimize against the objective:

- Run independent stages in parallel; pipeline items so item B codes while item A debugs.
- Put cheap checks before expensive ones (lint before simulation, simulation smoke before formal).
- Batch human reviews: one review file per gate covering many items beats many interruptions.
- Size concurrency to the license caps, not to the item count.
- Make each loop's first action the cheapest one that can fail.
- Add hooks only for yes/no enforcement ([HOOKS.md](HOOKS.md)); put judgment in the node brief.
- Every per-item stage starts after the **pilot** gate (step 5), except for the pilot item itself.

State the expected critical path and where you expect time to go. Done when every stage has skills, inputs, outputs, scope, gate, and (if looping) exit check, progress measure, and caps.

## 4. Plan gate

Write `reviews/plan.md` (status `pending`) listing: the diagram, the skill audit, drafts to apply, hooks to install, caps, and assumptions. Set `phase: awaiting-plan-approval`. Nothing runs until the user sets `status: approved`. On `changes-requested`, revise and return here.

On approval: apply approved drafts, run `/skills reload`, create the integration branch `flow/<run-id>` from the base branch, install approved hooks into the workspace `.agents/hooks.json`, set `phase: pilot`.

## 5. Pilot

Run once-only setup stages, then take **one** item through every stage exactly as step 6 would. Write `reviews/pilot.md` with what each node did, its logs, and anything surprising. Other independent work may proceed; per-item fan-out waits on `status: approved`. Then set `phase: running`.

## 6. Run

Repeat this cycle until close-out (step 7). Node statuses and their transitions: [RUN-STATE.md](RUN-STATE.md).

1. **Re-read** `state.json` and every `reviews/*.md`. Trust the files over your memory.
2. **Collect**: for each returned worker, read its `result.md`; verify the evidence it cites (log lines, check output) exists before marking the node `executed`. Update measures and the loop log path. Mark dependants of new `blocked` or `finding` nodes `blocked-upstream`.
3. **Gate**: an `executed` node with gate `none`, or passing its `check` gate, goes to `integrating` (see Merging). A `review` gate appends the node and its revision to `reviews/<gate>.md` and marks it `waiting-review`. Apply every `approved` or `changes-requested` review file per the transitions table, then archive it.
4. **Dispatch**: find ready nodes (inputs present, gates passed, not waiting). Dispatch `stage-worker` subagents concurrently up to the caps; each running worker counts as one job against its stage's tool. Give each the brief below.
5. **Record**: write `state.json`, append to `log.md`, regenerate `STATUS.md` (with the status-colored diagram) after every change.
6. **Wait** on running workers. Ask the user with `ask_question` only when nothing can progress without them; otherwise the pending reviews at the top of `STATUS.md` are how they learn.

**Node brief** (the worker inherits none of this conversation, so the brief is complete on its own):

```
Run: .agents/runs/<id>   Node: <stage>/<item>   Worktree: <path>   Branch: <branch>
Orchestrator folder: <absolute path to this skill's folder> (LOOP.md, RUN-STATE.md)
Skill(s) to follow: <absolute paths to SKILL.md>
Inputs: <files>          Outputs expected: <files>
Edit scope: <paths>      Out of scope → log as finding
Loop: <exit check>; progress = <measure, direction>; stuck limit 3; hard cap <n>
Tool: <name>, mode <gui|batch>, finish marker <marker>; one tool job at a time
Loop log: <path> (continue from it if it exists)
Notes: <lessons from earlier nodes, hook changes>
Write result.md when done, blocked, or finding.
```

**Worktrees**: per-item nodes run in their own worktree: `git worktree add <run>/wt/<item> -b flow/<run-id>/<item> flow/<run-id>`. Write `<worktree>/.stage` with the stage name before each dispatch; hooks read it.

**Merging**: merge a passed item branch into `flow/<run-id>`. On conflict, dispatch a worker to rebase the item branch onto `flow/<run-id>` and re-run its exit check; a failing check returns the node to its loop. Never merge into the user's base branch; that is the user's call at close-out.

**Feedback edges**: when a node emits work for an earlier stage (coverage holes → new test items), add new items or re-open nodes per the plan's edge, counting round trips against the edge cap.

**Learning mid-run**: when two or more workers hit the same avoidable problem, fix it for nodes not yet started: add a line to the brief's Notes, or add a stage-scoped hook in the workspace `.agents/hooks.json` ([HOOKS.md](HOOKS.md)). Log each change in `log.md` and `STATUS.md`. Changes that outlive the run (editing a skill, a global hook) go to `reviews/changes.md` for approval.

## 7. Close-out

Close out when every node is `done`, `blocked`, `blocked-upstream`, or `finding`. When nothing can progress only because review files are `pending`, the run is waiting, not finished: set `phase: awaiting-review`, keep it open, and return to step 6 on the next invocation.

At close-out: write `retrospective.md` (where wall-clock went, which loops stalled and why, which hooks and notes helped, findings for the user) and save or update the flow profile ([PROFILE-FORMAT.md](PROFILE-FORMAT.md)). Remove worktrees of `done` items; keep `blocked` ones for inspection. Set `phase: closed`. Report to the user: the integration branch, counts of done / blocked / finding, the findings list, and the path to `STATUS.md`.
