---
name: herdspace-docs
description: Write or change the herdspace docs, the README, install.md, a skill, or the screenshots and videos. Use when you add a guide, change a sentence that a person reads, add a link, or record media again.
---

# Write the docs

The docs are for a person who does not know Herdr or herdspace. Write each sentence so that the person understands it on one read.

## Language

Follow the `simple-english` skill for every doc. These rules matter most here:

- Short sentences, active voice, and simple tenses.
- Put a condition before the command: "If the check fails, run it again."
- Use `can`, `must`, and `will`. Do not use `should`, `may`, `might`, or `could`.
- No contractions, no semicolons, and no em-dashes.
- Use one word for one meaning in all docs. For example, "machine" and not "computer".

## Words of this project

| Word | Meaning |
|------|---------|
| server machine | The machine that runs Herdr, the projects, and the agents. |
| client machine | The machine that the person uses. It connects to the server machine with SSH. |
| one machine as both | One machine that is the server machine and the client machine. |
| SSH name | A short name for a server in `~/.ssh/config`, for example `my-server`. |
| list | The file of projects that `hopen` reads: `herdspace.toml` first, and a VS Code workspace file for people who come from VS Code. The example list of the docs is `my-projects`. Do not use `work`, which reads as an ordinary word, or a name with `workspace`, which is one project in Herdr. |
| setup | The script `bootstrap.sh`. Name it in each place where a person runs it. `hopen` is the second part, and the server setup installs it. |

Define each of these at its first use in a doc, before you use it.

## Links

- Link text is a name, not a file name: `[setup guide](docs/setup.md)`, not `[setup.md](docs/setup.md)`. The target keeps `.md`, because GitHub needs it.
- Link to the section that answers the question: `docs/setup.md#one-machine-as-server-and-client`.
- The `curl` commands use `https://github.com/MussaCharles/herdspace/releases/latest/download/`. Do not put a fixed tag in a doc.
- The agent prompts read `install.md` from `main`.
- `CHANGELOG.md` text goes to the release page, where a relative link does not work. In the changelog, name a file as text, for example `docs/hopen.md`.

## Structure

- Each guide starts with a `Scope:` line that says what the guide covers.
- Commands go in their own code block, one command for each block. Explanations go in the text.
- A list is for three or more items. A table is for items with the same fields.
- A fix lives in one doc. Other docs link to it.
- If you add a guide, add it to the Documentation list in `README.md`.
- The community files are in `.github/`: `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, and `SECURITY.md`. GitHub reads that folder first. A link in them starts with `/`, from the root of the repository, for example `[Testing](/docs/testing.md)`. GitHub also shows `CONTRIBUTING.md` on the Contributing tab of the repository, and that tab reads a relative link such as `../AGENTS.md` from the wrong folder. A link that starts with `/` works on both pages. `LICENSE`, `README.md`, `CHANGELOG.md`, `AGENTS.md`, and `install.md` stay in the root folder.

## Add a skill

1. Put a contributor skill in `.agents/skills/<name>/SKILL.md`, and the user skill in `skills/<name>/SKILL.md`.
2. Link each contributor skill for Claude Code, in the same pull request:

   ```bash
   ln -s ../../.agents/skills/<name> .claude/skills/<name>
   ```

3. Add the skill to the table of skills in `AGENTS.md`.
4. Run `tests/test-skills.sh`. It fails for a missing link, a broken link, or a skill that `AGENTS.md` does not list.

If you rename or remove a skill, change or remove its link too.

## Changes that the maintainer asks for

For a wording change that the maintainer asks for, show a preview of the new text first. Change the file only after the maintainer approves it.

## Screenshots and videos

`tests/capture-media.sh` records the images and videos in `docs/media` with real Ghostty and real key presses. The files go to `tests/.work/media`. Before you copy a file to `docs/media`, look at it. The GIF files play 3 times faster than the recording, and `SPEED` changes it.

## Make sure that it works

1. Run `tests/test-links.sh`. It checks each relative link and anchor, and the `/` rule of the community files.
2. Make sure that each new external link opens.
3. Make sure that a new `curl` command runs.
