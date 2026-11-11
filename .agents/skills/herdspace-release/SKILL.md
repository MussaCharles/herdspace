---
name: herdspace-release
description: Update the herdspace changelog, or build and publish a herdspace release. Use when a change is visible to users, when the person asks for a release, or when you change tools/release.sh.
---

# Changelog and releases

## Update the changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each pull request that a person can see adds a line under `## [Unreleased]`. The line goes below one of these headings: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, or `### Security`. Write one sentence for each change, for the person who uses herdspace. Name a file as text, not as a relative link, because the release page cannot open a relative link.

## Tags

A tag is the version alone, with no v in front, for example `0.1.2`. Use [Semantic Versioning](https://semver.org/spec/v2.0.0.html). A tag with a dash, for example `0.2.0-alpha.1`, becomes a pre-release, and `releases/latest` skips it. `tools/release.sh` refuses a tag that starts with v.

## Make a release

Follow these steps only when the person asks for a release.

1. In `CHANGELOG.md`, change `## [Unreleased]` to `## [<tag>] - <date>`, and add a new empty `## [Unreleased]` above it. Change the links at the end of the file.
2. Run all tests. `docs/testing.md` lists them. All tests must pass.
3. Merge the change to `main`.
4. Build the files:

   ```bash
   tools/release.sh 0.1.2
   ```

5. Show `dist/0.1.2.notes.md` to the person. It is the changelog section of the tag, with a link to the install steps at the top.
6. When the person agrees, publish:

   ```bash
   tools/release.sh 0.1.2 --publish
   ```

If the folder has a change or an untracked file, `--publish` stops. If `CHANGELOG.md` has no section for the tag, it stops too.

## What a release holds

| File | Use |
|------|-----|
| `bootstrap.sh` | The setup, with the tag written in it. From `curl`, it downloads the archive of its own tag. |
| `herdspace-<tag>.tar.gz` | Every tracked file except `tests/` and `docs/media/`. |
| `install.sh` and `hopen-<tag>.tar.gz` | The install of only `hopen` and its templates. |
| `SHA256SUMS` | The checksums that `bootstrap.sh` and `install.sh` compare. |

The `hopen` in both archives has the tag in `HOPEN_VERSION`.

## After a publish

1. Make sure that `https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh` and `install.sh` return 200.
2. Install `hopen` with `install.sh`, and make sure that `hopen --version` shows the new tag.
3. Run `bootstrap.sh server --check` from `curl`. It changes nothing.
4. Follow the `herdspace-test` skill to run `tests/run-release-check.sh --version <tag>`. It installs the release in fresh sandboxes and tries each feature. Report each sandbox that it skipped.

## Rules

- Do not change a published tag. If a release is wrong, publish a new one.
- Do not put install commands in the release notes. The notes link to the install steps.
