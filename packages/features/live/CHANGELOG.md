# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `LiveSession` is immutable and its transitions return the next state. `active`, `pending`,
  `currentTicket` and the mutable `variants` list are no longer writable from outside, because the
  "commit only after the player opened it" rule could be skipped by any caller assigning to them.
- **Breaking**: `requestSwitch` returns a `(LiveSession, SwitchRequest)` pair (`SwitchAccepted` /
  `SwitchNoop` / `SwitchRefused`) instead of a bool, and `commitSwitch` / `abandonSwitch` now require the
  `SwitchAttempt` they answer for.
- **Fixed**: one shared pending slot meant a second switch overwrote the first, and `commitSwitch()` then
  committed whatever was pending - so the late "opened successfully" callback of the line the user had
  already abandoned rewrote the selection to a stream nobody was playing. Attempts are now per axis and
  identified, and a superseded attempt cannot commit.
- **Fixed**: a switch could name a variant the source never offered. It is now refused with the axis and id
  named, while switching to the already-selected variant is a no-op rather than an error (a d-pad repeat
  event must not look like a failure).
- Selections are now two independent values (`LiveSelection.quality` and `.line`), so a session can hold
  "line 2 at 1080p"; one `active` field could not represent that, and a quality switch erased the line.
- `withVariants` releases a committed selection or an in-flight attempt whose variant disappeared;
  `withTicket` keeps selections but voids in-flight attempts, since an old url's callback describes nothing
  that still exists.
- `SwitchFailure` reports through `DomainFailure`, so a refused switch carries the same shape as every other
  named failure in the repository.
- Declared `pure_live_utils` and the `test` dev dependency.
