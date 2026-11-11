# herdspace

A CLI workspace and session manager for Herdr, the terminal multiplexer for coding agents. These instructions are for every coding agent that works in this repository. Claude Code, Codex, and other agents read this file.

## The parts

| Path | What it is |
|------|------------|
| `bin/hopen` | The command that opens the projects of a VS Code workspace file in one Herdr session. Bash, with small Python parts. |
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

Read the skill for the part that you change. Each skill is in `.agents/skills/<name>/SKILL.md`. `.claude/skills/` has a link to each one, so that Claude Code finds them.

| Skill | Use it when you |
|-------|-----------------|
| `herdspace-hopen` | Change `bin/hopen` or a template. |
| `herdspace-bootstrap` | Change a setup script, a configuration file, or a pinned version. |
| `herdspace-docs` | Write or change a doc, the README, or a skill. |
| `herdspace-release` | Update the changelog, or make a release. |
| `simple-english` | Write any text that a person reads. |

## Rules for every change

- A setup script must be safe to run again. A second run changes nothing.
- A setup script must ask before it replaces a file that a person changed.
- Do not add personal data, host names, private project names, or secrets to a file, a commit, an issue, or a pull request. This repository is public.
- Add or change a test for each change in behavior. Make sure that the test fails without the change.
- Before you open a pull request, run the tests that the change touches. Put the `RESULT` lines in the description.
- Shell scripts must pass `shellcheck -S warning` with no output.
- Change the docs in the same pull request as the code.
- Add each change that a person can see to `CHANGELOG.md`, under `## [Unreleased]`.
- Write the docs in simple English. Follow the `simple-english` skill.
- If the person did not ask for a release, do not run `tools/release.sh --publish`.

## Commands

```bash
shellcheck -S warning bootstrap.sh bootstrap/lib/*.sh bootstrap/platforms/*.sh tests/*.sh tools/*.sh install.sh
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
tests/run-prereqs.sh
```

```bash
tests/run-macos.sh
```

```bash
tests/run-linux.sh
```

`tests/run-linux.sh`, `tests/run-systemd.sh`, and `tests/run-client-linux.sh` need Docker. A command that runs for more than two minutes goes in the background, with its output in a log file.

## Pull requests

- Make one change for each branch and pull request.
- Write a commit subject in the imperative mood, for example `Add the both command`.
- Follow `CONTRIBUTING.md`.
