# Hook Patterns

Antigravity hooks live in `.agents/hooks.json` (workspace) or `~/.gemini/config/hooks.json` (global), and apply to every agent in their scope: there is no per-subagent or per-skill scoping. The orchestrator scopes them itself: every hook script first reads `.stage` in the current worktree and exits with no effect unless the stage matches.

The orchestrator may add hooks to the **workspace** file only, and logs each one. Global hooks go to `reviews/changes.md` for the user.

Use hooks for **yes/no enforcement**. Put judgment ("check the clock domain first") in the node brief instead.

## Format

```json
{
  "flow-scope-guard": {
    "PreToolUse": [
      { "matcher": "<tool name>", "hooks": [ { "type": "command", "command": ".agents/runs/<run-id>/hooks/scope-guard.sh" } ] }
    ]
  }
}
```

Events: `PreToolUse`, `PostToolUse`, `PreInvocation`, `PostInvocation`, `Stop`. The script receives JSON on stdin and answers with JSON on stdout. `PreToolUse` can answer `allow`, `deny`, `ask`, or `force_ask`; `Stop` can answer `continue` to send the agent back into its loop (the CLI caps consecutive continues).

Keep hook scripts in `.agents/runs/<run-id>/hooks/` so they travel with the run and are removed at close-out.

## Patterns

| Hook | Event | Does | Typical stage |
|---|---|---|---|
| **scope-guard** | `PreToolUse` on file-edit tools | `deny` edits outside the stage's edit scope (read from the plan by stage name); always `allow` the run folder, where workers write records | every verification stage |
| **lint-after-edit** | `PostToolUse` on file-edit tools | run the fast linter on the edited file, surface errors | code stages |
| **exit-check-on-stop** | `Stop` | re-run the loop's cheap exit check; `continue` if it fails and the stuck/hard caps in `loop.md` are not reached | any looping stage |
| **env-setup-guard** | `PreToolUse` on command tools | `deny` tool launches when the tool environment is not sourced, with the fix in the message | stages that launch CAD tools |

## Unverified behaviour

- Whether a running session picks up edits to `hooks.json` without restart is not documented. Treat a newly added hook as effective only for nodes dispatched after it was added, and say so in `log.md`.
- Whether a hook can modify a tool's input is not documented; use `deny` with an explanatory message instead.
- Field names above follow the Antigravity 2.0 hooks doc (antigravity.google/docs/hooks). Verify against the installed version on first use and correct this file if they differ.
