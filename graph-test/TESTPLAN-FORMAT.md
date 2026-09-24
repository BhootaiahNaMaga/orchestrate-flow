# Test Plan Format

One file per design: `testplans/<design>.md`. It is the standard every run is judged against, and the engineer approves it before anything launches. Derive every line from the graph skill's own files and cite them; where the graph skill is silent, write your assumption and mark it `ASSUMED` so the engineer sees it.

```md
# Test plan: <design>
graph_skill: <path> @ <commit>
launch: foo-graph <design>
approved: pending

## Nodes

### <node name>
- intention: <the outcome that makes this node done, checkable from trace or files>
- evidence of done: <file, log line, or trace event>
- runs as: subagent | inline        (source: <graph skill file:line>)
- depends on: <nodes>
- loops:
  - <loop name>: exit check <condition>; progress <measure, direction>; round cap <n>
- learnings: <what this node should log, e.g. "root cause of each failed round">
- hang timeout: <minutes with no trace or log growth>
- expected duration: <range>

## Answer sheet

| # | When asked (node / trigger) | Question (match on meaning) | Answer |
|---|---|---|---|
| 1 | plan gate | approve the plan? | approve |
| 2 | interview | which base branch? | main |

## Assumptions
- ASSUMED: <anything the graph skill does not state>
```

## Rules

- An **intention** must be checkable by the judge from the transcript, trace, or files. "Writes good tests" is not; "tb compiles and the smoke test passes (log line `SMOKE PASS`)" is.
- A node is `subagent` when the graph skill dispatches it as one, or when its instructions say it runs in its own context. Say which.
- Every question the graph can ask belongs in the answer sheet. Find them by reading every gate, `ask_question` call, and interview step in the graph skill. `approve` for every gate unless the engineer says otherwise.
- Hang timeout: at least 2× the longest silent stretch the node's tool can normally produce (a long synthesis step prints nothing for a while). When unsure, err long and mark `ASSUMED`.
