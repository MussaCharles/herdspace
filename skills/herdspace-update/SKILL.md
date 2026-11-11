---
name: herdspace-update
description: Add a tool or a setting to the herdspace repository, or update its pinned versions. Use when a person wants a new discovery to become part of this Herdr setup.
---

# Update herdspace

Run this skill in the herdspace repository. Read `docs/updating.md` first.

## Steps

1. Decide where the change belongs: `bootstrap/lib/server.sh` for all servers, one script in `bootstrap/platforms/` for one system, `config/` for a configuration file, or `config/templates/` for a pane template.
2. Add the step with `run_part` and a check function, so that a new run skips it when it is done. Use `install_file` for a file and `ensure_block` for lines in a file that a person owns.
3. On Linux, pin a release file with `tools/update-versions.sh`. Never run `curl | sh` from a new source without the agreement of the person.
4. Add a check to `tests/verify-server.sh`.
5. Update `docs/setup.md` and `docs/cheat-sheet.md`. Use plain English: short sentences, active voice, and one word for one meaning.
6. If a person who uses herdspace can see the change, add one line under `## [Unreleased]` in `CHANGELOG.md`, below the right heading: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, or `### Security`. Follow "Update the changelog" in `CONTRIBUTING.md`.
7. Run `tests/run-linux.sh` and `tests/run-client-linux.sh`. On a Mac, also run `tests/run-macos.sh`. Fix each `FAIL` line.
8. Create a branch and a pull request. Do not merge without the agreement of the person.

## Make a release

Do this only when the person asks for a release. Follow "Make a release" in `docs/updating.md`:

1. In `CHANGELOG.md`, change `## [Unreleased]` to `## [<tag>] - <date>`, add a new empty `## [Unreleased]`, and change the links at the end of the file.
2. Run all tests, and merge. A tag has no v in front, for example `0.1.2`. The docs use the `latest` address, so they do not change.
3. Run `tools/release.sh <tag>`, and show `dist/<tag>.notes.md` to the person.
4. Run `tools/release.sh <tag> --publish` only after the person agrees.

## Rules

- Do not add names, host names, private project names, or secrets. This repository can be public.
- Read the source code of a third-party plugin before you add it, and pin one commit.
- Do not copy a configuration file from another project unless its license allows it.
