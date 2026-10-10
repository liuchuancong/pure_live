# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `RecordingTask` is immutable. `start()` / `stop()` / `fail()` returned bools and left the
  caller to guess what went wrong; the transitions are now `begin()` / `stop(reason)` / `fail(reason)`
  returning the next task and throwing `RecordingFailure` with the state that was refused. `RecordingState
  .idle` became `queued`, which is what it always meant.
- **Fixed**: `state` and `endReason` were public writable fields, so the promise that "a late encoder
  callback cannot resurrect a finished task" could be broken by one assignment from any caller. There is no
  longer a way to reach a state except through the transitions.
- **Fixed**: a queued task reported an `elapsed` that grew with the wall clock, so the list screen showed a
  recording that had never started as having run for an hour. Elapsed now measures from `beganAt` and is zero
  while queued.
- **Fixed**: `endReason` defaulted to a `none` member, making "stopped for no reason" writable. The reason is
  now required on every terminal transition and null only while not terminal, and `fail(userStopped)` is
  refused outright - the two states drive different UI.
- **Security**: `fileName` is validated (non-blank, no separators, no `..`, no interior control characters),
  because the host joins it onto its recording directory. Exported as `requireSafeFileName` for the import
  path that meets the same rule.
- **Fixed**: the id joined `sourceId` and `contentId` with a slash, so a content id containing a separator
  could collide with a different room. It now uses a length-prefixed key and stays stable across
  transitions, so a task list keeps its keys when a recording starts.
- The clock is injected (`Clock`, defaulting to `systemClock`) instead of reading `DateTime.now()` in three
  places, which is what makes the duration and terminal-stamp rules testable at all.
- Declared `pure_live_utils` and the `test` dev dependency.
