---
name: herdspace-release
description: Update the herdspace changelog, or build and publish a herdspace release. Use when a change is visible to users, when the person asks for a release, or when you change tools/release.sh.
---

# Changelog and releases

## Update the changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each pull request that a person can see adds a line under `## [Unreleased]`. The line goes below one of these headings: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, or `### Security`. Write one sentence for each change, for the person who uses herdspace. Name a file as text, not as a relative link, because the release page cannot open a relative link.

## Tags

A tag is the version alone, with no v in front, for example `0.1.2`. Use [Semantic Versioning](https://semver.org/spec/v2.0.0.html). A tag with a dash, for example `0.2.0-alpha.1`, becomes a pre-release, and `releases/latest` skips it. `tools/release.sh` refuses a tag that does not start with a digit. The script needs `gh`. It reads the repository from `gh repo view`, or from `--repo owner/name`, and it creates the release on `main`.

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
| `herdspace-<tag>.tar.gz` | Each file that git tracks, and each new file that git does not ignore, except `tests/`, `docs/media/`, and `dist/`. A build with no `--publish` can also hold files that are not committed yet. Only `--publish` needs a clean folder. |
| `install.sh` and `hopen-<tag>.tar.gz` | The install of only `hopen` and its templates. |
| `SHA256SUMS` | The checksums that `bootstrap.sh` and `install.sh` compare. |

The `hopen` in both archives has the tag in `HOPEN_VERSION`. In an early pre-release, the full archive held `HOPEN_VERSION="dev"`, and `bootstrap.sh --check` reported the `hopen` from `install.sh` as changed. If you change `tools/release.sh`, run `tests/test-install.sh`. It builds a release and installs from it.

## After a publish

1. Make sure that `https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh` and `install.sh` return 200.
2. Install `hopen` with `install.sh`, and make sure that `hopen --version` shows the new tag.
3. Run `bootstrap.sh server --check` from `curl`. It changes nothing in the setup. It only downloads the release files.
4. The workflow "Release check" starts by itself for a published release, but not for a pre-release. It installs the release on Linux and macOS runners and tries each feature. Wait for its result:

   ```bash
   gh run list --workflow release.yml --limit 1
   ```

5. Follow the `herdspace-test` skill to run `tests/run-release-check.sh --version <tag>`. It installs the release in fresh sandboxes and tries each feature. Report each sandbox that it skipped.

## Rules

- Do not change a published tag. If a release is wrong, publish a new one. If the tag exists, `--publish` replaces its files and its notes with no question. Run `gh release view <tag>` before `--publish`.
- Do not put install commands in the release notes. The notes link to the install steps.
