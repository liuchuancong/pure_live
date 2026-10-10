# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `ChannelZapper` is immutable; `zapUp` / `zapDown` return a `ZapStep` (`ZapMoved` /
  `ZapEmpty`) instead of a nullable channel, `setGroupFilter` became `withGroup`, and a typed remote entry
  is `select(number)` (1-based against the visible scope). The zapper no longer owns hidden mutable state a
  second key-press can race with.
- **Fixed**: `ZapChannel.primaryUrl` was `urls.first` and threw `StateError` on the entries that routinely
  appear in imported playlists (a group header parsed as a channel, a stream line that got truncated). It is
  now nullable with an `isPlayable` rule that also refuses a scheme-less url, which a black screen and no
  error otherwise disguises as a dead station.
- **Fixed**: `visible()` returned the internal list, so a caller could reorder the lineup the viewer is
  watching through a getter. Both `channels` and `visible()` are unmodifiable now.
- **Fixed**: narrowing the group filter moved the cursor to the first channel of the new scope, so switching
  groups on a remote changed the station. `withGroup` keeps the current channel whenever the new scope still
  contains it, and clearing the filter never moves at all.
- Zapping skips entries with no playable stream (a decision recorded in the ledger as reversible), but
  `select(number)` still reaches them, because a typed number is a deliberate choice. A scope where nothing
  is playable says so instead of wrapping the viewer around a black screen.
- `toString` drops the headers: an IPTV stream header routinely carries a cookie, and platform-models §16
  forbids that reaching diagnostics. `headerNames` exposes the names without the values.
- **Fixed**: `EpgWindow.minutesRemaining` documented rounding up while `Duration.inMinutes` truncates, so a
  countdown showed "0 min" for ten seconds still running. It now ceils, clamps a past end to 0, and returns
  null when the guide never gave an end - which is a different statement from "it is over".
- Added `EpgWindow.isOverlappingGuide` and `hasGapBeforeNext` so a surface can show that the guide data
  disagrees with itself instead of hiding it, plus `secondsRemaining` for a ticking countdown that should
  not re-derive the rounding rule.
- Added `windowFrom` over caller-supplied `(title, startsAt, endsAt)` entries, reporting a guide whose every
  entry has already ended as inconsistent data rather than as an empty schedule.
- Declared `pure_live_utils` and the `test` dev dependency.
