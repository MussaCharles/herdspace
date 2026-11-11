# Security policy

## Supported versions

Only the latest release gets security fixes. Before you report a problem, make sure that it occurs in the latest release.

## Report a vulnerability

Do not open a public issue for a security problem.

1. Go to the [Security tab](https://github.com/MussaCharles/herdspace/security) of this repository.
2. Select Report a vulnerability.
3. Give the release tag, the system, and the steps that show the problem.

Only the maintainer can read the report. The maintainer answers in the report. When a fix is in a release, the maintainer tells you there.

## Scope

herdspace downloads releases with `curl`, compares their checksums, and changes shell and terminal files in your home folder. A problem in one of these steps is in scope. A problem in Herdr or in another tool that the setup installs belongs to the project of that tool.
