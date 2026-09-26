# Project feedback

Reviewed: 2026-09-26  
Baseline: `ed194ff`, plus the existing untracked session notes.

**Assessment:** This is a thoughtfully structured, instruction-based prototype for long-running agent workflows. The core workflows are expressed in substantial detail, but several contracts conflict at precisely the points that matter for unattended operation: approvals, recovery, judging, and integration. I would resolve those conflicts and demonstrate one complete run with interruption/recovery before relying on multi-day execution.

## What is implemented

| Component | Present in the repository | Implementation status |
|---|---|---|
| `orchestrate-flow` | Skill audit, interview, graph planning, approval gates, pilot, dispatch, merge, feedback, close-out | Agent instructions |
| `stage-worker` | Isolated node execution, scoped edits, loop execution, commits, evidence reports | Agent definition |
| Run persistence | State, review, result, status, and loop formats | Documented formats and examples |
| Hooks | Scope, lint, environment, and stop-check patterns | Example configuration; no executable hook scripts |
| Profiles | Reusable graph, lessons, and performance history | Format only; no populated profiles |
| `graph-test` | Baseline, monitoring, judging, patch/revert, regression, learning reuse | Agent instructions |
| Platform integration | Installation and expected agentapi operations | Instructions; compatibility explicitly unverified |

The repository has 12 tracked Markdown files and one existing untracked session-notes file. There is no application runtime, dependency manifest, executable test suite, or checked-in run evidence. For a skills project, prose is a legitimate implementation medium; however, describing a workflow does not establish that its platform integrations or recovery behavior work.

## What works well

- **Clear responsibility boundaries.** The orchestrator plans and coordinates, the worker executes, and the harness evaluates. The worker receives an explicit brief rather than relying on inherited context.
- **Useful domain constraints.** Scope boundaries, external findings, license caps, completion markers, and measured progress address real CAD/EDA workflow concerns.
- **Evidence-oriented reporting.** Results must cite logs; judges must cite traces; learning claims are checked against observed behavior.
- **Controlled rollout.** Plan approval followed by a pilot is a sensible way to expose incorrect assumptions before fan-out.
- **Good regression intent.** Fresh runs, one patch per round, failure reverts, and cross-design checks make changes easier to attribute.
- **Readable documentation.** Terminology is consistent overall, files are focused, and all existing relative Markdown links resolve.

## Findings and recommended changes

Priorities: **P1** = address before unattended runs; **P2** = address before broader use. Except for the reproduced rollback defect, these findings come from static inspection of the instructions, not observed Antigravity executions. Source line numbers refer to the reviewed baseline.

### 1. P1 — The harness cannot reliably approve this project's own orchestrator

**Evidence:** [graph-test/SKILL.md](../graph-test/SKILL.md), lines 79–84, answers questions through chat messages. [orchestrate-flow/SKILL.md](../orchestrate-flow/SKILL.md), lines 71–77, requires the user to change review-file status. The harness's final rule also prohibits editing anything outside `graph_skill`.

Sending “approve” does not satisfy the documented file-based gate. A run waiting on a review file might not even appear as a chat question, so the harness could leave it waiting until it is classified as hung.

**Recommendation:** Define approval actions in the answer sheet: chat reply or a narrowly scoped review-file update. Explicitly authorize the harness to update specified review files in disposable test runs after the engineer approves the test plan. Clarify that the patch-scope restriction applies to source changes, while harness state and approved test controls have separate write scopes.

### 2. P1 — Valid loop termination can be judged as a broken loop

**Evidence:** [graph-test/JUDGE.md](../graph-test/JUDGE.md), lines 12–13, requires a second round after a failed check and permits only success, stuck limit, or cap as exit reasons. [orchestrate-flow/LOOP.md](../orchestrate-flow/LOOP.md), line 16, explicitly stops on an out-of-scope finding. [agents/stage-worker.md](../agents/stage-worker.md), line 16, also permits blocking on a required decision.

A worker correctly stopping after its first round because the RTL is wrong can therefore trigger an early abort and an unnecessary patch to correct behavior. A one-round hard cap also conflicts with the unconditional second-round requirement.

**Recommendation:** Put permitted terminal reasons in each loop's approved test plan. Distinguish unsuccessful outcomes from protocol violations. Evaluate termination reasons before deciding a retry is missing.

### 3. P1 — The documented rollback does not restore the best tree

**Evidence:** [orchestrate-flow/LOOP.md](../orchestrate-flow/LOOP.md), line 13, uses `git checkout <best-sha> -- .` followed by a commit.

**Reproduced:** In a disposable Git repository, a later commit modified `tracked.txt` and added `extra.txt`. The documented rollback restored `tracked.txt` but retained `extra.txt`; the resulting commit still differed from the best commit.

**Recommendation:** Define restoration of additions, modifications, and deletions within the node's owned paths. Verify the restored tree against the best revision before rerunning. Preserve diagnostic artifacts separately. Record `tested_commit` and `best_commit` explicitly: the example loop log records the fix commit but does not clearly identify the revision that produced the measured result.

### 4. P1 — Losing a worker can duplicate a still-running tool job

**Evidence:** [orchestrate-flow/RUN-STATE.md](../orchestrate-flow/RUN-STATE.md), line 62, re-dispatches when there is no live worker. [orchestrate-flow/LOOP.md](../orchestrate-flow/LOOP.md), lines 7–8, launches a queued tool job and treats inactivity as a failed round. Neither path requires reconciliation or confirmed cancellation of the previous job.

A worker session can disappear while its external job remains alive. Re-dispatch or retry could start another job against the same output paths and consume another license. Similarly, stopping a harness chat is not documented to cancel its tool jobs.

**Recommendation:** Persist a unique attempt ID, scheduler job ID, tested commit, and attempt-specific output paths before waiting. On recovery, inspect the job and existing results before launching anything. Require cancellation acknowledgement before replacement, bind finish markers to attempts, and count surviving jobs against caps. Add the stage timeout to the plan and brief; it is used by the loop but absent from their templates.

### 5. P1 — Gate completion and run closure are underspecified

**Evidence:** [orchestrate-flow/SKILL.md](../orchestrate-flow/SKILL.md), lines 84–85, marks collected nodes done before gate handling and explicitly merges only check-gated nodes. [orchestrate-flow/RUN-STATE.md](../orchestrate-flow/RUN-STATE.md), line 58, defines done as already merged. Close-out is triggered when “no node can progress” at skill line 115.

The instructions do not clearly define merging for `gate: none`, consuming review approval, handling changes requested at ordinary stage gates, or propagating blocked dependencies. A run awaiting human approval also satisfies “no node can progress,” making closure ambiguous.

**Recommendation:** Define a transition table covering execution complete, review pending, approved, integrating, done, and blocked dependencies. Keep waiting runs resumable without closing them. Bind approval to a fixed item list and artifact revision so later additions cannot inherit earlier approval. Explicitly exempt the pilot item from the rule at line 65 that every per-item stage must wait for pilot approval.

### 6. P1 — A clean Git merge is treated as sufficient integration validation

**Evidence:** [orchestrate-flow/SKILL.md](../orchestrate-flow/SKILL.md), lines 105–107, reruns the exit check after a merge conflict, but does not require a check on a conflict-free combined result.

Two item branches can pass independently and merge without textual conflicts while producing an invalid combined testbench or inconsistent configuration.

**Recommendation:** Serialize integration and validate the candidate merged revision before marking an item done. Specify how a failed integration is retained for diagnosis and excluded from accepted integration history. Define one active writer per item worktree, since independent stages for the same item otherwise share both files and `.stage`.

### 7. P2 — Worktree paths and once-only stage execution need a concrete contract

**Evidence:** The brief in [orchestrate-flow/SKILL.md](../orchestrate-flow/SKILL.md), line 93, uses a relative run path. The worker changes into its worktree before reading that path ([agents/stage-worker.md](../agents/stage-worker.md), line 10). Worktrees are specified only for per-item nodes, although the worker always expects one.

A relative run path resolves differently after changing directories. Once-only stages also lack an explicit branch, worktree, and integration policy.

**Recommendation:** Pass absolute run, input, output, and hook paths. Specify once-only stage workspaces. Separate source-edit scope from permission to write result and loop records. Add a startup check proving that each worker can read its plan and write its report from its actual working directory.

### 8. P2 — Harness limits and final confirmation have incomplete transitions

**Evidence:** [graph-test/SKILL.md](../graph-test/SKILL.md), lines 97–118, selects an open issue, checks limits after regression, and describes final confirmation without specifying how its failures return to issue handling.

An all-pass baseline has no issue to select. A sequence of failed patch attempts does not explicitly return through the budget check. The stated wall-clock limit also lets existing runs finish, so it is not a hard deadline. A failure discovered by the final learning-reuse pair has no prescribed disposition.

**Recommendation:** Check budgets before every launch and patch. Route an all-pass baseline directly to final confirmation. Specify whether the deadline stops new work or cancels active work. Give final-confirmation failures and unknown verdicts explicit statuses and reporting rules; do not imply a verified pass when confirmation was skipped or inconclusive.

### 9. P2 — Recovery and platform compatibility remain assumptions

**Evidence:** Both skills create a new run when there is not exactly one active run, including when several exist. State examples omit operation checkpoints for branch creation, patch/revert, dispatch, and merge. [README.md](../README.md) explicitly lists unverified hooks, subagent fields, agentapi operations, and polling behavior.

Atomic replacement protects a JSON file from partial writes, but does not make a Git operation and state update atomic together. Recovery after “commit succeeded, state update did not” remains ambiguous. Multiple active runs can also lead to unintended new runs or date/slug collisions.

**Recommendation:** Select among existing runs instead of silently creating another. Record operation intent and completion, use unique IDs, and reconcile Git/chat/job state on resume. Add versioned state validation and an explicit `unknown` result throughout verdict formats. Complete a platform preflight with a recorded version and actual dispatch, hook, trace, approval, and stop results before starting a long design run.

## Suggested implementation order

1. Fix the approval protocol, loop exit rules, rollback behavior, and gate transitions.
2. Specify attempt ownership, job reconciliation, absolute paths, and integration validation.
3. Add small deterministic fixtures for the contracts: valid finding, review wait/resume, added-file rollback, surviving job, clean-merge regression, and budget exhaustion. These supplement the intended real-design tests.
4. Run one small real design in Antigravity, deliberately interrupt and resume it, and retain its plan, state, trace, verdict, and platform version as reference evidence.
5. Expand to multi-design and multi-day evaluation after the single-design lifecycle is demonstrated.

## Validation performed and limitations

- Read all 13 existing Markdown files, including the untracked session notes, and inspected tracked files and working-tree status.
- Checked existing relative Markdown links: no broken targets found.
- Reproduced the rollback defect in an isolated temporary repository; the project's branches and source files were not changed.
- Did not execute either skill, launch design jobs, or verify external Antigravity documentation or installed-platform compatibility. There is no repository test suite to run.
- Added only this feedback document. The session notes were already untracked before review.
