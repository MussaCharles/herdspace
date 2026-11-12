# herdspace

A CLI workspace and session manager for Herdr, the terminal multiplexer for coding agents. These instructions are for every coding agent that works in this repository. Claude Code, Codex, and other agents read this file.

## The parts

| Path | What it is |
|------|------------|
| `bin/hopen` | The command that opens the projects of a list (`herdspace.toml`, or a VS Code workspace file) in one Herdr session. Bash, with small Python parts. |
| `config/templates/` | The pane templates of `hopen`. |
| `bootstrap.sh` | The entry point of the setup. It picks a script in `bootstrap/platforms/` from the role and the system. |
| `bootstrap/lib/` | The shared steps of the setup scripts. |
| `config/` | The configuration files that the setup installs. |
| `install.sh` | Installs only `hopen` from a release. |
| `install.md` | Steps that a coding agent follows to install herdspace for a person. |
| `tools/release.sh` | Builds and publishes a release. |
| `tests/` | The tests. `docs/testing.md` explains each one. |
| `skills/herdspace/` | The user skill: it teaches an agent to use herdspace on any machine. |
| `.agents/skills/` | The contributor skills: they teach an agent to change this repository. |

## Skills

Read the skill for the part that you change. Each skill is in `.agents/skills/<name>/SKILL.md`. `.claude/skills/` has a symbolic link to each one, so that Claude Code finds them.

If you add a skill, add its link in the same pull request, and add the skill to the table below:

```bash
ln -s ../../.agents/skills/<name> .claude/skills/<name>
```

If you rename or remove a skill, change or remove its link too. `tests/test-skills.sh` fails for a skill with no link, and for a broken link.

| Skill | Use it when you |
|-------|-----------------|
| `herdspace-hopen` | Change `bin/hopen` or a template. |
| `herdspace-ci` | Change a workflow, a repository setting, or find the cause of a failed CI job. |
| `herdspace-bootstrap` | Change a setup script, a configuration file, or a pinned version. |
| `herdspace-docs` | Write or change a doc, the README, or a skill. |
| `herdspace-release` | Update the changelog, or make a release. |
| `herdspace-test` | Run the tests on the sandboxes of this machine, or check a published release. |
| `simple-english` | Write any text that a person reads. |

## Rules for every change

- A setup script must be safe to run again. A second run changes nothing.
- A setup script must ask before it replaces a file that a person changed.
- Do not add personal data, host names, private project names, or secrets to a file, a commit, an issue, or a pull request. This repository is public.
- Add or change a test for each change in behavior. Make sure that the test fails without the change.
- Before you open a pull request, run the tests that the change touches. Put the `RESULT` lines in the description.
- CI runs the tests again for each pull request. Merge only after every CI job passes. `docs/ci.md` explains the jobs.
- If you change a workflow in `.github/workflows/`, follow the security rules in `docs/ci.md`.
- Shell scripts must pass `shellcheck -S warning` with no output.
- Change the docs in the same pull request as the code.
- Add each change that a person can see to `CHANGELOG.md`, under `## [Unreleased]`.
- Write the docs in simple English. Follow the `simple-english` skill.
- If the person did not ask for a release, do not run `tools/release.sh --publish`.

## Keep the skills current

At the end of each task, before you report that it is done, review the skills:

1. List what you learned in the task that no skill has yet. For example: a mistake that broke something, a quirk of a tool, a rule, a command, or a fact of the code.
2. Find the skill that owns that part, from the table in [Skills](#skills). Add the lesson there, or fix the fact that is no longer true.
3. If no skill covers the part, and the lesson can help in a later task, add a new skill. Link it for Claude Code, and add it to the table.
4. Put the skill change in the same pull request as the task, or in a pull request right after it. Run `tests/test-skills.sh`.

A lesson goes to one skill only. Other skills link to it. Write only public facts: no names of machines, accounts, or private projects.

## Commands

```bash
shellcheck -S warning bin/hopen bin/herdr-update-check bootstrap.sh bootstrap/lib/*.sh bootstrap/platforms/*.sh tests/*.sh tools/*.sh install.sh
```

```bash
tests/test-install.sh
```

```bash
tests/test-hopen-list.sh
```

```bash
tests/test-skills.sh
```

```bash
tests/test-links.sh
```

```bash
tests/test-ui.sh
```

```bash
tests/run-prereqs.sh
```

```bash
tests/run-macos.sh
```

```bash
tests/run-linux.sh
```

`tests/run-linux.sh`, `tests/run-systemd.sh`, `tests/run-client-linux.sh`, `tests/run-prereqs.sh`, `tests/capture-media.sh`, and the Linux part of `tests/run-release-check.sh` need Docker. A command that runs for more than two minutes goes in the background, with its output in a log file.

## Pull requests

- Make one change for each branch and pull request.
- Only the owner, or an agent of the owner, can merge. Follow "Merge a pull request" in the `herdspace-ci` skill.
- Write a commit subject in the imperative mood, for example `Add the both command`.
- Follow `.github/CONTRIBUTING.md`.
