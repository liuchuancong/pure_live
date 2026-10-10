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
- **Fixed**: the internal `_channels` still aliased the caller's list even though the `channels` getter
  returned an unmodifiable view, so `add` / `removeAt` on the list that was passed in reordered - or emptied -
  the station being watched. The constructor copies now, and the test that mutates the source list after
  building proves the lineup does not move.
- **Fixed**: the visible scope was resolved by **value** (`indexOf(scope[number-1])`), so a playlist that
  repeats a row verbatim - how a source lists a second CDN for the same station - put both rows on the first
  copy: the second one could not be zapped or typed into, and `visibleNumber` reported the wrong row. The
  scope is now a list of positions, `select` / `atIndex` / `visibleNumber` walk positions, and `positionsOf`
  shows how many copies exist. `selectChannel` keeps its value semantics and says so in its doc comment.
- **Breaking**: `ZapMoved` carries the `ChannelZapper` it landed on. Without it every caller re-derived the
  move with `selectChannel(step.channel)`, which on a repeated row moved to the *other* copy, so the key
  press ended somewhere the viewer had not aimed at.
- `visible()` is a getter (`visible`). It refiltered and reallocated on every call, and a TV surface reads it
  per key-press and per rebuild; the scope is computed once in the constructor instead.
- Added `withSkipUnplayable` (a settings toggle for walking greyed-out rows must not change the station),
  `atIndex`, `positionsOf`, `count` and `visibleCount`.
- **Fixed**: `windowFrom` picked "now" as the first entry that had not **ended**, which is a programme that has
  not started yet whenever the guide has a hole - the surface counted down a show that was not on screen. An
  entry now has to have started, several covering rows resolve to the latest start (a filler listed under the
  real programme loses), and the builder sorts its own input instead of assuming the caller's guide arrived in
  order.
- **Fixed**: `isOverlappingGuide` could not be true for any window `windowFrom` produced, because "next" was
  searched only after the current row's end, so an early-starting neighbour was dropped. A report flag that
  nothing in the program can set is decoration, not reporting; the search now starts after the current row's
  *start*, and `onInconsistentData` names the row that ends before it starts (which is skipped) and a gap
  ("nothing airs at …"), returning a window with only `next` so the surface can tell "this guide has a hole
  here" apart from "this channel has no guide".
- Added `EpgProgramme.covers` and `EpgWindow.nowDuration` (null for a row that ends before it starts, rather
  than a negative duration a widget has to invent a rule for), and `minutesRemaining` now derives from
  `secondsRemaining` so the two countdowns cannot drift apart.
- Declared `pure_live_utils` and the `test` dev dependency.
