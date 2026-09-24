# State Folder Format

Everything a batch knows lives in `graphtest/<batch-id>/`. A fresh harness chat with no memory must be able to continue from these files alone.

```
graphtest/<batch-id>/
  state.json              # machine state: phase, runs, issues, patches
  log.md                  # append-only event log
  report.md               # latest report, rewritten after every round
  issues.md               # issues by root cause, with every patch attempt
  testplans/<design>.md   # TESTPLAN-FORMAT.md
  reviews/testplan-<design>.md
  runs/<run-id>/
    meta.json             # design, commit, chat id, design clone path, purpose
    watch.md              # one entry per poll
    verdict.md            # JUDGE.md
    transcript/           # transcript and trace exports from agentapi
```

## state.json

```json
{
  "batch_id": "20260923-foo-graph",
  "phase": "testplan | awaiting-testplan-approval | baseline | patching | regression | final | closed",
  "inputs": {
    "graph_skill": "/path/to/foo-graph",
    "designs": ["designA"],
    "max_rounds": 10,
    "max_wallclock": "7d",
    "max_tries_per_issue": 5,
    "poll_minutes": 15
  },
  "started": "2026-09-23T20:00:00Z",
  "branch": "graphtest/20260923-foo-graph",
  "base_commit": "abc1234",
  "head_commit": "def5678",
  "round": 2,
  "runs": {
    "r007": {
      "design": "designA",
      "commit": "def5678",
      "purpose": "baseline | patch-try | regression | final-fresh | final-learnings",
      "issue": "I-02",
      "chat_id": "<from agentapi>",
      "status": "running | aborted | ended | judged",
      "trace_cursor": "<last event seen>",
      "last_growth": "2026-09-23T21:10:00Z",
      "current_node": "debug"
    }
  },
  "issues": {
    "I-02": {
      "summary": "debug node runs inline, not as subagent",
      "status": "open | patching | fixed | needs-human",
      "tries": 2,
      "patches": [
        { "commit": "aa11bb2", "result": "reverted", "why": "still inline on designA" },
        { "commit": "cc33dd4", "result": "testing" }
      ]
    }
  }
}
```

Write it after every change: write to a temp file and rename, so a crash never leaves it half-written.

## Phases

| Phase | Meaning |
|---|---|
| `testplan` | writing test plans |
| `awaiting-testplan-approval` | waiting on `reviews/testplan-<design>.md` |
| `baseline` | first fresh run on every design, unpatched |
| `patching` | a patch try running on one design |
| `regression` | a passed patch running on all designs |
| `final` | fresh + learnings-kept confirmation pair per design |
| `closed` | report written |
