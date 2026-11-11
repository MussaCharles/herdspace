# Contributing to herdspace

Thank you for your help. This guide tells you how to report a problem, how to suggest a change, and how to send a pull request.

All people in this project follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Report a bug

1. Search the [issues](https://github.com/MussaCharles/herdspace/issues) first. Somebody can have the same problem.
2. Open a new issue with the bug template.
3. Give the system, the release tag, the command, and the full error text.

Do not report a security problem in an issue. Follow [SECURITY.md](SECURITY.md).

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

The maintainer reviews each pull request. When the tests pass and the review is done, the maintainer merges the pull request.

## License

herdspace uses the [MIT License](LICENSE). When you send a contribution, you agree that it uses the same license.
