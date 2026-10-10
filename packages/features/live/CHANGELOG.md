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
- Added `domain/live_recovery.dart`: `LineDegrader` walks the lines **this source** offered, default line
  first, and stops at `maxSwitches` (4) or when every line has failed. It never crosses to another source -
  that is the `ResolverChain`'s job, and crossing mid-stream would silently move the user to a different
  site's vocabulary of qualities and subtitles. It holds no quality variants at all, so a dead line cannot
  degrade the bitrate the user picked; an earlier draft carried an `allowQualityDegrade` flag that nothing
  read, which is a knob that lies, so it is gone.
- Added `LastWatched` and `LastWatchedStore`: the room, title and variant ids to reopen on the next launch,
  versioned (`v`, and a newer envelope is refused rather than guessed at) and tolerant - an unreadable
  record, a stale timestamp and a line id the source no longer offers all mean "open nothing" or "start on
  the source's default", never "resolve a stream that cannot exist". Keys are namespaced, so two hosts
  sharing one `KeyValueStore` do not read each other's resume record.
- Declared `pure_live_storage` (the resume record needs a store, and features may not reach services'
  persistence through a same-layer dependency).
- Declared `pure_live_utils` and the `test` dev dependency.
