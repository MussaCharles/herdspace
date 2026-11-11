# Changelog

All notable changes to herdspace are in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The hopen guide, `docs/hopen.md`, has every `hopen` command, and the steps to install, update, and remove it.
- The herdspace skill, `skills/herdspace`, teaches a coding agent to use `hopen` and the setup. Install it with `npx skills add MussaCharles/herdspace --skill herdspace -g`.
- `AGENTS.md` and the skills in `.agents/skills/` give coding agents the rules of this project.
- The keyboard shortcuts guide, `docs/keyboard-shortcuts.md`, lists each key that the client setup changes.
- The client option `--keep-terminal-keys` keeps the keys of Ghostty and macOS. The setup saves the choice, and `--use-herdspace-keys` changes it back.

### Changed

- The install commands in the docs use the newest release. To install a specific release, add `--version <tag>`.
- The Quick start starts with a table of the options, with a link to each one.

### Removed

- The skills `herdspace-server`, `herdspace-client`, and `herdspace-update`. `install.md`, the herdspace skill, and the `herdspace-bootstrap` skill replace them.

## [0.1.1] - 2026-11-11

The first release of herdspace.

### Added

- `hopen` opens each folder of a VS Code workspace file as a Herdr workspace in one named session. It starts the template programs again after a restart.
- Five pane templates: `plain`, `code`, `agent`, `grid`, and `review`. You can add your own.
- `bootstrap.sh server`, `client`, and `both` set up macOS, Debian, Ubuntu, and Windows with WSL with one command. A run does only what is missing, and it asks before it replaces a file that you changed.
- `install.sh` installs only `hopen` on a machine that has Herdr.
- `install.md` has steps that a coding agent follows to do the setup.
- Guides for setup, SSH, templates, WSL, updating, and testing.

[Unreleased]: https://github.com/MussaCharles/herdspace/compare/0.1.1...HEAD
[0.1.1]: https://github.com/MussaCharles/herdspace/releases/tag/0.1.1
