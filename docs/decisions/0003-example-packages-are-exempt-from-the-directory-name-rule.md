# 0003 — `example/` packages are exempt from the directory-name rule

- **Status:** Accepted
- **Date:** 2026-10-13
- **Affects:** `tool/validate_packages.ps1`, every package that ships an example
  (`live_uikit_background/example` today), `docs/engineering/package-standards.md` §3.1 §5

## Context

`package-standards.md` §3.1 requires that the directory name exactly match the
`pubspec.yaml` `name:`, and §5 requires `README.md`, `CHANGELOG.md` and `test/` of
every package. `tool/validate_packages.ps1` enforces both.

The pub package format reserves the directory name `example/` for the runnable demo
that accompanies a package: publishing tooling and pub.dev look for that path, and a
sample is conventionally named `<package>_example`. Those two rules collide exactly:
`packages/live_uikit_background/example` holding
`name: live_uikit_background_example` can satisfy the directory rule only by moving
out of `example/`, which would make it stop being an example as pub understands it.

The validator reported three findings for that one directory, and they were not
findings worth fixing — which is how a gate loses its authority.

## Decision

`validate_packages.ps1` treats a workspace member whose path ends in `example` as a
sample rather than a deliverable:

- exempt from the directory-name match (the name is reserved by the package format);
- exempt from `CHANGELOG.md` (nobody reads the change history of a demo to decide
  whether to upgrade) and from `test/` (its behaviour is verified by running it, and
  a test directory in a sample is a placeholder waiting for content);
- still required to have `README.md` and `analysis_options.yaml`, and still checked
  for duplicate names, `resolution: workspace`, and cross-package private imports.

## Alternatives considered

- **Rename the directory to `live_uikit_background_example/`.** Rejected: it stops
  being the example pub publishes and shows, which is the whole reason it exists.
- **Drop examples from the workspace.** Rejected: an example must resolve against the
  workspace lockfile, or it tests a different dependency set than the package it
  demonstrates — the failure mode being "the demo worked, the app does not".
- **Leave the three findings as permanent noise.** Rejected: the gate runs in CI as a
  report precisely so its findings mean something; encoding a real convention is the
  fix, ignoring it is not.

## Consequences

- The exemption is path-based (`/example`), not name-based. Placing a real deliverable
  package in a directory named `example` would hide it from these checks — which is
  why packages are not allowed to nest a deliverable under `example/`.
- `tool/check_architecture.ps1` applies the same reasoning by name (`*_example`): the
  rule "UI adapters must not depend on each other" counted
  `live_uikit_background_example` as an adapter depending on `live_uikit_background`, which
  is precisely what a demo must do. Without that exemption the fatal CI guard failed on
  the day the first example was added.
- `package-standards.md` §3.1 and §5 are now slightly narrower than written. Update
  the standard text if this exemption survives its first two additions; if examples
  start needing changelogs, revisit instead of extending the exception.

## Conditions for reconsideration

If a package is published independently and its example is distributed as a separate
artifact with its own version history, it stops being an `example/` in this sense and
should be given a matching directory name and the full required-file set.
