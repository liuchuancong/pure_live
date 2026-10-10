# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `RingBuffer` is a real ring: an overwrite advances a head index instead of `removeAt(0)` on a growable
  list, which copied the whole tail on every add once full - and this buffer is written on every diagnostic
  event for the lifetime of a session.
- **Fixed**: `measure` timed with two `DateTime.now()` readings, so a wall-clock step (NTP correction, a
  manual change, a device wake) could report a negative duration; a dashboard reads that as "instant" and a
  threshold check as "safe to ignore". It uses a `Stopwatch` now.
- **Fixed**: `runGuarded` called its handler unguarded, so a reporter that threw - a locked diagnostics file
  is the usual one - left the caller awaiting a future that could never complete. A handler failure is now
  surfaced after the body finished rather than swallowing the body's reason or hanging.
- Added `isFull`, kept `droppedCount` as the "this view is partial" signal.
