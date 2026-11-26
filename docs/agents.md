# Agents

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: agents in panes: start them, see their state, and go to them.

## Agents in panes

To run two agents side by side in one tab, for example two Claude Code sessions that work together, see [Run agents side by side](tmux.md#run-agents-side-by-side).

| State | Meaning |
|-------|---------|
| `blocked` | The agent waits for you. |
| `done` | The agent finished, and you did not see the result. |
| `working` | The agent is busy. |
| `idle` | The agent waits for a prompt. |

| Task | Command |
|------|---------|
| List the agents | `herdr agent list` |
| Explain the state of an agent | `herdr agent explain <pane>` |
| List the panes | `herdr pane list` |

To make one agent start another agent, mention Herdr in the prompt. Add the last two sentences of this prompt each time:

```text
Use Herdr to start an opencode agent named coder in a split next to you. Give it the plan in docs/plan.md and wait until it finishes. If the other agent is blocked on a permission or approval prompt, do not answer it. Stop and tell me.
```

The skill works for each agent program that the server setup found. Every program in a pane can read and type into other panes. Do not let one agent answer the approval prompt of another agent.

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
