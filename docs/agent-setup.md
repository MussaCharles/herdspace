# Ask an agent to do the setup

Scope: what to say to a coding agent, so that it can do the setup for you. An agent can read the skill files in [skills](../skills/) and follow them.

```mermaid
sequenceDiagram
  actor You
  participant Agent
  participant Computer
  You->>Agent: Read this skill file and follow it
  Agent->>Computer: Check the system and the tools
  Agent->>You: Show the plan
  You->>Agent: Agree
  Agent->>Computer: Run the bootstrap script
  Computer-->>Agent: Log and warnings
  Agent->>Computer: Run the checks
  Agent->>You: Report the result
```

| Skill file | Use |
|------------|-----|
| [skills/bootstrap-herdr-server/SKILL.md](../skills/bootstrap-herdr-server/SKILL.md) | Set up a Linux or macOS server |
| [skills/bootstrap-herdr-client/SKILL.md](../skills/bootstrap-herdr-client/SKILL.md) | Set up the Mac that you use for SSH |
| [skills/update-herdr-bootstrap/SKILL.md](../skills/update-herdr-bootstrap/SKILL.md) | Add a tool or a setting to this repository |

## Before you ask

Start the agent on the computer that you want to set up, in the folder of this repository. A skill runs commands on that computer.

If you name the path of a skill file, the agent reads it. You do not need to install the skill.

## What to say

To set up a server, paste this prompt:

```text
Read skills/bootstrap-herdr-server/SKILL.md in this repository and follow it to set up this computer. Show me the plan before you change anything.
```

To set up a client, paste this prompt, and replace the server names:

```text
Read skills/bootstrap-herdr-client/SKILL.md in this repository and follow it to set up this Mac. My servers are my-server and my-other-server. Show me the plan before you change anything.
```

To add something new, paste this prompt, and replace the last sentence:

```text
Read skills/update-herdr-bootstrap/SKILL.md in this repository and follow it. I want to add this tool: <name of the tool and why you want it>.
```

## What stays with you

The agent must stop and ask you in these cases:

- `sudo` or the Homebrew installer asks for a password.
- A step replaces a file that is not from this repository, and you did not agree.
- A step stops a running Herdr server. A stop closes every pane.

## Install a skill for regular use

To make a skill available in every session of Claude Code, copy its folder:

```bash
cp -R skills/bootstrap-herdr-server ~/.claude/skills/
```
