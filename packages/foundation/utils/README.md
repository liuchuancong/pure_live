
# PureLive Utils

Shared pure Dart utilities for the PureLive workspace.

## Principles

- Keep Flutter UI, platform plugins, networking clients, and application-specific business logic out of this package.
- Export supported public APIs through `lib/pure_live_utils.dart`.
- Keep implementation details under `lib/src/`.
- Prefer Dart SDK and established package APIs over duplicate implementations.
- Make asynchronous behavior deterministic and testable.
- Document public APIs and test boundary conditions.
- Keep dependency direction one-way: foundational utilities must not depend on application features.

## Modules

- `async`: asynchronous coordination, cancellation, and lifecycle primitives.
- `collections`: reusable collection algorithms and extensions.
- `result`: explicit success and failure values.
- `errors`: error categorization and normalization.
- `strings`: normalization, comparison, and truncation.
- `conversion`: safe parsing and conversion.
- `time`: clocks, timestamps, and duration helpers.
- `numbers`: numeric parsing and range helpers.
- `types`: common type and nullable-value helpers.
- `validation`: reusable validation primitives.
- `equality`: value and deep equality helpers.
- `identifiers`: identifier parsing and validation.
- `math`: ranges and numeric utilities.

## Dependencies

Runtime dependency: `clock` only, and for one reason — `systemClock()` reads the package-global clock, so
`withClock(...)` in a test reaches code that never received an injected clock. `collection` was dropped: its
`firstOrNull` is an extension member and cannot be forwarded as a function, so the one-line local definition
is what keeps the barrel traceable. No other pub.dev package, and no foundation package.

## Allowed and forbidden imports

- Allowed for consumers: `package:pure_live_utils/pure_live_utils.dart` — the barrel is the only surface.
- Forbidden: `lib/src/**` from any other package, Flutter widgets, io, plugins and any app.
- Forbidden: this package importing another foundation package; it is the L0 leaf alongside `logging`.
The rules and the whitelist live in `docs/architecture/dependency-rules.md`; `tool/check_architecture.dart`
enforces them.

## Platform matrix

Pure Dart: no platform channel, no file system, no isolate. Every symbol runs on Android, Android TV,
Windows, iOS and the web without a conditional import.

## Unverified

- `Disposer`, `OperationGuard`, `CancellationToken.guard`, the `equality`, `identifiers`, `math`, `numbers`,
  `types`, `validation`, `conversion` and `errors` modules have no consumer yet. They exist because the
  duplication they absorb was measured across the repository (see `doc/design-decisions.md` §1), not because
  a caller asked for them; the first consumer's review is when the shape gets fixed.
- Nothing here has run on a device. Package-level `dart analyze` and `dart test` are the only gates passed.

## Development

Run package analysis and tests from the workspace root after dependency resolution:

```bash
dart analyze packages/foundation/utils
dart test packages/foundation/utils/test
```
