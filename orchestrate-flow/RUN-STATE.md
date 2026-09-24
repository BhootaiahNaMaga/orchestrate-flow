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
  wt/<item>/          # git worktrees, one per item
  retrospective.md    # close-out
```

## state.json

```json
{
  "run_id": "20260923-spec-to-coverage",
  "phase": "intake | interview | awaiting-plan-approval | pilot | running | closed",
  "integration_branch": "flow/20260923-spec-to-coverage",
  "caps": { "global": 10, "per_tool": { "formal": 4 } },
  "items": ["cg_cand_001", "cg_cand_002"],
  "nodes": {
    "verify/cg_cand_001": {
      "status": "pending | ready | running | waiting-review | done | blocked | finding",
      "tool": "formal",
      "worktree": "wt/cg_cand_001",
      "branch": "flow/20260923-spec-to-coverage/cg_cand_001",
      "rounds": 4,
      "best_measure": 37,
      "stuck_count": 1,
      "queue_job_ids": ["123456"],
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
| `pending` | inputs not yet available |
| `ready` | can be dispatched |
| `running` | a worker owns it |
| `waiting-review` | a human review gate it depends on is open |
| `done` | exit check passed, evidence verified, merged |
| `blocked` | loop stuck/regressed 3 times or hit hard cap; notes in `loop.md` |
| `finding` | root cause is outside edit scope (RTL, spec); explained in `result.md` |

A `running` node found on resume with no live worker is re-dispatched; its `loop.md` tells the worker where to continue.

## result.md (written by the worker)

```md
---
status: done | blocked | finding
measure: <final value>
rounds: <n>
commit: <sha>
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
---
## What to review
<files, items, links to logs>

## Comments
<the user writes here>
```

The user approves by editing `status`. Items appended to an open review stay in the same file so reviews batch.

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
