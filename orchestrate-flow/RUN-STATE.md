# Run Folder Format

Everything a run knows lives in `.agents/runs/<run-id>/`. A fresh orchestrator with no memory must be able to continue from these files alone.

```
.agents/runs/<run-id>/
  state.json          # machine state: phase, nodes, jobs
  plan.md             # approved plan (PLAN-FORMAT.md)
  STATUS.md           # human view, regenerated after every change
  log.md              # append-only event log
  skill-audit.md      # step 1 output
  drafts/             # proposed skill fixes
  reviews/<gate>.md   # human review files
  nodes/<stage>/<item>/
    result.md         # worker's final report for this node
    loop.md           # loop log (LOOP.md)
    attempt-<id>/     # one tool job's outputs, logs, and finish marker
  wt/<item>/          # git worktrees, one per item
  wt/_once/<stage>/   # git worktrees for once-only stages
  retrospective.md    # close-out
```

## state.json

```json
{
  "run_id": "20260923-spec-to-coverage",
  "phase": "intake | interview | awaiting-plan-approval | pilot | running | awaiting-review | closed",
  "integration_branch": "flow/20260923-spec-to-coverage",
  "caps": { "global": 10, "per_tool": { "formal": 4 } },
  "items": ["cg_cand_001", "cg_cand_002"],
  "nodes": {
    "verify/cg_cand_001": {
      "status": "pending | ready | running | executed | waiting-review | integrating | done | blocked | blocked-upstream | finding",
      "tool": "formal",
      "worktree": "wt/cg_cand_001",
      "branch": "flow/20260923-spec-to-coverage/cg_cand_001",
      "rounds": 4,
      "best_measure": 37,
      "best_commit": "9f8e7d6",
      "stuck_count": 1,
      "attempts": [
        {
          "attempt_id": "verify-cg_cand_001-a4",
          "job_id": "123456",
          "tested_commit": "a1b2c3d",
          "output_dir": "nodes/verify/cg_cand_001/attempt-verify-cg_cand_001-a4",
          "state": "queued | running | finished | cancelled | unknown"
        }
      ],
      "updated": "2026-09-23T18:40:00Z",
      "note": "bound 37, stuck at same CEX"
    }
  },
  "feedback_trips": { "cov->tb": 1 }
}
```

Write it after every change; write to a temp file and rename so a crash never leaves it half-written.

## Node statuses

| Status | Meaning |
|---|---|
| `pending` | inputs not yet available (an upstream node is not `done`) |
| `ready` | can be dispatched |
| `running` | a worker owns it |
| `executed` | worker returned `done` and its evidence is verified; not yet through its gate |
| `waiting-review` | its outputs are listed in an open `review` gate file |
| `integrating` | its branch is being merged and checked (Merging in SKILL.md) |
| `done` | gate passed and merged into `flow/<run-id>`; dependants may start |
| `blocked` | loop stuck/regressed 3 times, hit hard cap, or needs a user decision; notes in `loop.md` / `result.md` |
| `blocked-upstream` | a node it depends on is `blocked` or `finding`; re-evaluated when that node changes |
| `finding` | root cause is outside edit scope (RTL, spec); explained in `result.md` |

## Transitions

| From | Event | To |
|---|---|---|
| `pending` | every upstream node `done` | `ready` |
| `pending` | an upstream node `blocked`, `blocked-upstream`, or `finding` | `blocked-upstream` |
| `ready` | dispatched | `running` |
| `running` | `result.md` `done`, evidence verified | `executed` |
| `running` | `result.md` `blocked` or `finding` | `blocked` / `finding` |
| `executed` | gate `none` or `check` (check passes) | `integrating` |
| `executed` | gate `check` fails | `ready` (failure in the brief's Notes) |
| `executed` | gate `review` | `waiting-review` |
| `waiting-review` | review `approved` covering this node at its recorded revision | `integrating` |
| `waiting-review` | review `changes-requested` | `ready` (comments in the brief's Notes) |
| `integrating` | merged and integration check passes | `done` |
| `integrating` | conflict or integration check fails | `ready` (failure in the brief's Notes) |
| `blocked`, `finding` | user resolves it (review or plan change) | `ready` |

## Attempts and tool jobs

The worker records an attempt in `loop.md`, and the orchestrator copies it into `state.json`, **before** waiting on the job: attempt id, scheduler job id, tested commit, and output dir. Every job writes only into its own `attempt-<id>/` dir, and its finish marker counts only there, so a stale job can never complete a newer attempt. Jobs whose state is `queued`, `running`, or `unknown` count against the concurrency caps, whether or not a worker still owns them.

**Recovery.** A `running` node found on resume with no live worker:

1. Query every recorded job that is not `finished` or `cancelled` with the plan's scheduler status command.
2. A job still alive → re-dispatch a worker with `Adopt: <attempt id>` in its brief; it waits on that job instead of launching one.
3. A job that ended → re-dispatch a worker to collect that attempt's outputs and continue from `loop.md`.
4. A job whose state cannot be determined → cancel it and launch a replacement only after the scheduler confirms the cancel. If it cannot be confirmed, mark the attempt `unknown`, keep counting it against the caps, and mark the node `blocked` with the job id.

## result.md (written by the worker)

```md
---
status: done | blocked | finding
terminal_reason: pass | stuck | cap | finding | blocked-decision
measure: <final value>
rounds: <n>
tested_commit: <sha the final measure came from>
best_commit: <sha of the best tree, the one to merge>
---
## Evidence
<exit check command and the log lines proving it passed>

## Root cause / finding
<for blocked or finding: what was found, where, why it is out of scope or stuck>

## Notes for later nodes
<anything the orchestrator should pass on>
```

## reviews/<gate>.md

```md
---
status: pending | approved | changes-requested
round: <n>
items:
  - <stage>/<item> @ <revision sha>
---
## What to review
<files, items, links to logs>

## Comments
<the user writes here>
```

The user approves by editing `status`. An approval covers exactly the nodes listed under `items`, at the listed revisions. Nodes appended while the file is `pending` join the same round, so reviews batch. Once the orchestrator applies an approval or change request, it moves the file to `reviews/archive/<gate>-<round>.md`. Later nodes start a fresh `reviews/<gate>.md` with the next round number, so they never inherit an earlier approval.

## STATUS.md

Regenerated in full, never hand-edited:

````md
# <run-id> — <phase>

## Needs you
- [ ] reviews/testplan.md — testplan for 12 features (pending since 09-23 14:10)
- [ ] 2 blocked items, 1 finding (below)

## Graph
```mermaid
flowchart LR
  ...same graph as plan.md...
  classDef done fill:#2e7d32,color:#fff
  classDef running fill:#1565c0,color:#fff
  classDef waiting fill:#f9a825,color:#000
  classDef blocked fill:#c62828,color:#fff
  class bringup,testplan done
  class review_tp waiting
```

## Counts
done 14 · running 6 · waiting-review 3 · blocked 2 · finding 1 · pending 20

## Blocked and findings
| Node | Status | Summary | Detail |
|---|---|---|---|

## Mid-run changes
<hooks added, brief notes added, with time and reason>
````

A stage's class is the "worst" of its nodes: blocked > waiting > running > done.
