# 0001 — Generated code is not committed

- **Status:** Accepted
- **Date:** 2026-10-13
- **Affects:** `live_preferences`, `live_iptv`, `live_sites`, `live_library`,
  `live_playback`, `live_interaction`, and any package adopting Freezed or
  `json_serializable`; `.github/workflows/architecture.yml`; `tool/`.

## Context

`packages/*/**.freezed.dart` and `packages/*/**.g.dart` are matched by `.gitignore`,
so a checkout contains only handwritten model sources. That is one of the two
policies `docs/engineering/dart-model-and-codegen-standards.md` §7.3 allows — what it
forbids is mixing them, and it requires that the other one be documented and
enforced:

> If generated files are not committed, CI and all documented build workflows MUST
> generate them before analysis, testing, or compilation.

Neither half of that was true here. The `Architecture` workflow resolved packages
and then ran `flutter analyze`, so a clean checkout of any Freezed package failed
its own analyzer on unresolved `part` directives. Locally the same hole was covered
by accident: `.dart_tool` keeps stale generated output from an earlier run, which
is why the repository looked healthy while the gate was not.

## Decision

Keep generated files out of git, and make CI produce them. The `Architecture` job
now runs `dart run melos run gen` immediately after `flutter pub get` and before
`dart format`, `flutter analyze` or any test.

## Alternatives considered

- **Commit the generated output.** Rejected: 23 packages resolve dependency versions
  through one workspace lockfile, so a generator bump would land dozens of unrelated
  generated diffs on the next contributor who runs it, and review would be reviewing
  machine output. It also cannot be verified cheaply — "regeneration produced no
  diff" needs a full build anyway.
- **Commit nothing and let contributors generate on demand.** Rejected: that is
  today's broken state, where the failure surfaces as an analyzer error in a package
  the reader did not touch.
- **Vendor a `generated/` directory per package.** Rejected: §7.1 requires generated
  files to sit beside their source.

## Consequences

- Any workflow that analyses or tests packages must include the generation step; a
  new workflow that forgets it fails confusingly rather than obviously.
- "Generated output is up to date" cannot be checked with `git diff`, because the
  files are ignored. CI checks the weaker but real property instead: generation
  succeeds and the analyzer passes against freshly generated code.
- A contributor's stale `.dart_tool` output can still differ from a fresh
  generation until they re-run `melos run gen`; the CI run is the authority.

## Conditions for reconsideration

Revisit if generated output ever has to be audited in review (a generator that
cannot be trusted to be deterministic), or if a package is published independently
where consumers build from the archive without a workspace.
