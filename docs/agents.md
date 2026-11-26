# Agents

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: agents in panes: start them, see their state, go to them, and the Herdr integrations.

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

## Agent programs and integrations

herdspace never installs or updates an agent program. Install each agent yourself, and update it as its own docs say.

Herdr shows the state of each agent in its panes, by reading what the agent draws. An integration is a small hook that Herdr adds to the configuration folder of an agent. With it, Herdr gets the state from the agent itself, and it can resume the conversation of the pane after a restart of the server.

The server setup adds the integration of Herdr, and the Herdr skill where the agent reads one, for each agent that it finds:

- A command of the agent is on the `PATH`, with the same names that Herdr uses. For example, Cursor is `cursor-agent`, and the `cursor` command of the Cursor editor does not count.
- The configuration folder of the agent exists. The agent makes it at its first start, so start each agent one time before the setup. If the folder is missing, the setup says so.

| Agent | Command | Integration in Herdr |
|-------|---------|----------------------|
| Claude Code | `claude` | yes |
| Codex | `codex` | yes |
| OpenCode | `opencode` | yes |
| Pi, OMP | `pi`, `omp` | yes |
| GitHub Copilot CLI | `copilot` | yes |
| Cursor Agent CLI | `cursor-agent` | yes |
| Hermes Agent | `hermes` | yes |
| Grok CLI | `grok` | yes |
| Devin CLI, Droid, Kimi Code CLI | `devin`, `droid`, `kimi` | yes |
| Kilo Code CLI | `kilo` or `kilo-code` | yes |
| Qoder CLI, Qwen Code | `qodercli`, `qwen` | yes |
| Letta Code | `letta` | yes, experimental |
| MastraCode | `mastracode` | yes |
| Antigravity CLI | `agy` | yes, the conversation only |
| Gemini CLI | `gemini` | no: Herdr shows the state from the screen only, and cannot resume it |

To see the integrations on a machine, run `herdr integration status`. To add one by hand, run `herdr integration install NAME`, for example `herdr integration install claude`.

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
- [Herdr integrations](https://herdr.dev/tui/docs/integrations/): the hook, the folder, and the files of each integration.
- [Herdr agents](https://herdr.dev/tui/docs/agents/): the state and resume support of each agent.
