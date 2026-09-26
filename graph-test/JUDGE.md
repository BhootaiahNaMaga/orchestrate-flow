# Judging a Run

The judge reads one run's transcript and trace against the design's test plan and writes `runs/<run-id>/verdict.md`. Every verdict cites evidence: a trace event id, a transcript excerpt, or a file path and line. A verdict without evidence is `unknown`, never `pass`.

## Watch-time checks

The harness runs these every poll, on the new part of the trace only. They are cheap and decide early aborts.

| Check | Fails when | Abort? |
|---|---|---|
| **subagent** | a node marked `subagent` in the test plan runs its work in the parent chat instead (no subagent dispatch event before its tool calls) | yes, once that node's work has started inline |
| **loop present** | a looping node ends without evaluating the exit check, or ends after a failed check without a terminal reason from the test plan | yes |
| **loop broken** | the round counter resets, the same round repeats with no fix between, rounds pass the cap, or the loop exits on a reason not in the test plan's terminal reasons | yes |
| **hang** | no trace or log growth for longer than the node's hang timeout | yes |
| **unplanned question** | the graph asks something not on the answer sheet | no |
| **scope** | a node edits outside the paths the graph skill allows it | no, unless it corrupts later nodes' inputs |

Read a loop's **exit reason** before judging its rounds. A permitted unsuccessful exit (`finding`, `blocked-decision`, `stuck`, `cap`) is an **outcome**: the loop worked, and the run continues with no abort and no patch. Only a **protocol violation** (the rows above) is an issue. A loop with round cap 1 never owes a second round.

## Full verdict

### Per node

| Field | Values |
|---|---|
| intention | `met` / `not-met` / `not-reached` / `unknown` (evidence) |
| runs as | `correct` / `wrong` / `unknown` (expected vs actual) |
| loops | per loop: rounds, exit reason, `correct` / `broken` / `missing` / `unknown` |
| duration | actual vs expected |

### Learnings log

Judge each against the trace, not against the log's own claims. Each verdict may be `unknown` when the trace cannot settle it.

| Verdict | Question |
|---|---|
| **written** | Did every node that should log write entries, in the graph's format? |
| **real** | Does each entry match what the trace shows happened? Flag made-up events, and gaps (a node retried 5 times but logged no reason). |
| **used** | Did any later node read the learnings (a read in the trace) and act differently because of them? |
| **not harmful** | Is any entry wrong, or did one steer a later node into a mistake? |

### Learnings reuse (final confirmation only)

Compare the learnings-kept run with the fresh run on the same design: nodes whose rounds, duration, or outcome changed, and whether each change traces back to a specific learning being read. Report `helped`, `no effect`, or `hurt`, with the learning and the node.

## Classifying failures

For each failed check, name the root cause and where it lives:

- **issue**: in the graph skill (a missing instruction, a wrong dispatch, a loop the instructions never close). Give the file and the line to change.
- **finding**: in the design, tool flow, licenses, or agentapi. Explain precisely; these are not patched.

Two failures with the same root cause are one issue.

## verdict.md

```md
# Verdict: <run-id>
design: <d>   commit: <sha>   ended: <completed | aborted at <node>>

## Nodes
| node | intention | runs as | loops | duration |
|---|---|---|---|---|

## Learnings
written: <verdict + evidence>
real: ...
used: ...
not harmful: ...

## Issues
- <short name>: root cause <...> at <graph skill file:line>; evidence <...>

## Findings
- <...>
```
