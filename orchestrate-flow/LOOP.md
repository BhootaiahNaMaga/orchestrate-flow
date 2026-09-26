# Loop Template

A loop turns a skill set (run a tool, check, debug, fix) into a node that ends on its own. The worker runs it; the loop log on disk, not the worker's memory, is the loop's state.

## One round

1. **Run**: launch the tool through the stage's skill (TCL → queue). Record the queue job id in `loop.md`.
2. **Wait**: poll the finish marker and the log, not the agent's command status. A job with no marker and no log growth for the stage's timeout is a failed round: record it, don't loop on it silently.
3. **Check**: evaluate the exit check. Pass → write `result.md` with `status: done` and the evidence. Stop.
4. **Measure**: read the progress measure and compare with the best so far.
   - **Progress**: better than best → commit, record as new best, reset stuck count.
   - **Stuck**: equal to best, or the same root cause as the previous round → stuck count +1.
   - **Regress**: worse than best → restore the best commit within the edit scope, stuck count +1:
     1. Copy this round's logs and reports to `nodes/<stage>/<item>/round-<k>/` (diagnostics survive the restore).
     2. `git restore --source=<best-sha> --staged --worktree -- <edit scope>` (modified, added, and deleted tracked files), then `git clean -fd -- <edit scope>` (untracked files).
     3. `git diff --quiet <best-sha> -- <edit scope>` must succeed; then `git commit -m "revert to best (round k)"`. If it fails, write `result.md` with `status: blocked` and the diff. Stop.
5. **Root-cause**: use the debug skill (logs, reports, waveform skills) to find why the check failed. Classify where the root cause lives:
   - In edit scope → fix it, commit, next round.
   - Out of scope (RTL or spec during verification, spec during coding) → write `result.md` with `status: finding` and a clear explanation. Stop.
6. **Stop conditions**: stuck count reaches 3, or rounds reach the hard cap → write `result.md` with `status: blocked`, listing what each round tried. Stop.

**Terminal reasons**, the complete list of ways a loop ends: `pass` (step 3), `finding` (step 5), `stuck` and `cap` (step 6), `blocked-decision` (the worker needs a decision only the user can make; `stage-worker.md`). Record the reason in `loop.md` and `result.md`. Any of them may end the loop after one round.

## loop.md

Append one entry per round, written before starting the next:

```md
## Round 4 — 2026-09-23 18:40
- job: 123456 (finish marker seen 18:31)
- tested_commit: 9f8e7d6   (the revision the job measured)
- check: FAIL (assert_cg_en_stable, CEX at depth 37)
- measure: bound 37 (best 37 @ 9f8e7d6, prior 31) → progress
- best_commit: 9f8e7d6
- root cause: TB constraint lets en toggle during reset; in scope
- fix: constrain en low while rst_n==0 (commit a1b2c3d, tested next round)
- stuck: 0/3   rounds: 4/15
```

A worker dispatched onto a node with an existing `loop.md` reads it and continues from the next round, with the recorded best commit and stuck count.

## Measures by kind (examples, set per loop in the plan)

| Loop | Measure | Better is |
|---|---|---|
| lint | error count | lower |
| formal proof | proven bound depth | higher |
| simulation debug | first-failure time, or failing test count | later / lower |
| coverage closure | coverage % | higher |
| synthesis / power | flop count, leakage | lower |

Two rounds with the same root cause count as stuck even if the measure moved within noise.
