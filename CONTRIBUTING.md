# Contributing to herdspace

Thank you for your help. This guide tells you how to report a problem, how to suggest a change, and how to send a pull request.

All people in this project follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Report a bug

1. Search the [issues](https://github.com/MussaCharles/herdspace/issues) first. Somebody can have the same problem.
2. Open a new issue with the bug template.
3. Give the system, the release tag, the command, and the full error text.

Do not report a security problem in an issue. Follow the [security policy](SECURITY.md).

## Suggest a change

Before you write code for a large change, open an issue with the feature template. The issue is the plan, so that we agree on it first. A small fix, such as a typo, can go straight to a pull request.

## Set up a copy for work

```bash
git clone https://github.com/MussaCharles/herdspace.git
```

You need Docker for the Linux tests, and a Mac for the macOS test. [Testing](docs/testing.md) tells you how to run each test.

## Rules for a change

- A setup script must be safe to run again. A second run changes nothing.
- A setup script must ask before it replaces a file that a person changed.
- Shell scripts must pass `shellcheck -S warning` with no output.
- Add or change a test for each change in behavior. The test must fail without the change.
- Change the docs in the same pull request as the code.
- Write the docs in simple English: short sentences, active voice, and one word for one meaning.
- Do not add personal data, host names, or secrets to a file, a commit, or an issue.

## Send a pull request

1. Make a branch from `main`.
2. Make one change for each pull request.
3. Run the tests that your change touches, and put the results in the description of the pull request.
4. Write a commit subject in the imperative mood, for example `Add the both command`.
5. If the change is visible to a person who uses herdspace, add a line to `CHANGELOG.md`. See [Update the changelog](#update-the-changelog).

The maintainer reviews each pull request. When the tests pass and the review is done, the maintainer merges the pull request.

## Update the changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The release notes of each release come from it.

1. Add your line under `## [Unreleased]`, at the top of the file.
2. Put the line under one of these headings. Add the heading if it is not there yet:
   - `### Added` for a new feature.
   - `### Changed` for a change in a feature that exists.
   - `### Deprecated` for a feature that a later release removes.
   - `### Removed` for a feature that this release removes.
   - `### Fixed` for a bug fix.
   - `### Security` for a fix to a security problem.
3. Write one sentence for each change, for the person who uses herdspace. Link the issue or the pull request, for example `(#35)`.

A change that a person cannot see, such as a change to a test, does not go in the changelog.

## License

herdspace uses the [MIT License](LICENSE). When you send a contribution, you agree that it uses the same license.
