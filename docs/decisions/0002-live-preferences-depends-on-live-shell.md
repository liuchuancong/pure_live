# 0002 — `live_preferences` depends on `live_shell`

- **Status:** Accepted
- **Date:** 2026-10-13
- **Affects:** `live_preferences`, `live_shell`, `apps/pure_live`

## Context

The desktop settings group needs to store what the close button does, and the shell
needs to decide what that means on a given platform. Both declared the same three
values: `live_shell.CloseAction` and a second enum in `live_preferences`. Two
declarations of one concept drift by exactly one case at a time — adding a fourth
`CloseAction` compiles everywhere and fails at the hand-written mapping in the
application, which is the worst place to discover it because it looks like a setting
that stopped working.

The standard asks for one owner per concept
(`dart-model-and-codegen-standards.md` §12) and an explicit dependency direction
(`package-standards.md` §7.1), so the duplicate has to go in one direction or the other.

## Decision

`live_preferences` depends on `live_shell` and stores `CloseAction` directly. The
duplicate enum is deleted; the value names were identical, so stored documents need
no migration.

The reverse edge was rejected on principle: `live_shell` is pure Dart with two
dependencies (`live_platform`, `meta`) and no storage, which is what lets 143 tests
run headless. Pulling a Hive-backed package into it would end that.

## Alternatives considered

- **Keep both enums, map in the app.** Rejected: the mapping would live in the one
  place with no tests, and its failure mode is silent.
- **Store the close action as a raw string in preferences.** Rejected: loses the
  type at the point where mistakes are made, and every consumer needs its own parse.
- **Move the projection into `live_shell`.** Rejected: it would need to import
  `live_preferences`, which is the forbidden direction.

## Consequences

- The projection (`DesktopPreferencesAsShell`) and the field→consumer table
  (`desktopFieldConsumers`) live in `live_preferences`, where both types are visible,
  and are covered by `test/desktop_preferences_test.dart`.
- Adding a desktop setting now fails a test unless it names its consumer — deliberate
  friction against switches that appear in the UI and do nothing.
- `live_shell` gains a reason to keep its vocabulary additive: a renamed
  `CloseAction` case is a stored-document break, not just a code change.
- The dependency edge is package-level, not module-level: `live_shell_desktop`
  already depended on `live_shell`, so the graph stays acyclic
  (`live_shell_desktop → live_shell ← live_preferences → live_storage`).

## Conditions for reconsideration

If a second consumer of preferences needs shell behaviour without `live_shell`,
extract the shared vocabulary into a foundation package rather than inverting this
edge.
