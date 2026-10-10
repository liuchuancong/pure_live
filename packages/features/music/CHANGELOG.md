# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking (layer rule)**: this package no longer imports `providers/music`. The port
  `MusicSourceBridge` replaces the concrete `MusicSourceScriptHost`, and the app that loads the lx script
  writes the adapter. Dependency-rules section 3 forbids a feature reaching a provider directly, and the
  import could not be declared in the pubspec without turning that violation into an approved edge.
- **Breaking**: `MusicQueue` is immutable. `enqueue` / `removeAt` / `jumpTo` / `clear` / the public
  `endMode` and `repeatOne` fields became `withEntry` / `withoutAt` / `withCursor` / `cleared` /
  `withEndMode` / `withRepeatOne`, returning the next queue; `commitAdvance` became `commit`.
- **Fixed**: removing an entry before the cursor left the cursor at its number while the list shifted left
  underneath it, silently skipping a song.
- **Fixed**: running off the end with `endMode == stop` reported `queueEmpty`. The queue is not empty, it is
  finished, and a surface that conflates them shows "nothing queued" over a list of songs.
- **Fixed**: a step peeked before the queue changed could still be committed, moving the cursor onto
  whatever now occupied that index. `QueueAdvance` carries the entry it chose and `commit` verifies it is
  still there, or throws `QueueFailure`.
- Out-of-range indices (`jumpTo(-1)`, `removeAt(length)`) used to return false or do nothing silently; they
  now throw `QueueFailure`.
- `availableSources()` returns null while the script has not announced anything, so a loading host is not
  drawn as "no sources"; `isReady` exposes the same fact for a spinner.
- A ref missing `lxSource` now throws `MusicSourceFailure` naming the reference, instead of a bare
  `StateError`; the failure arrives on the returned future rather than as a synchronous throw, so callers
  awaiting it and callers chaining `catchError` behave the same.
- An empty play url is a failure rather than a playable result.
- Declared `pure_live_utils`, and documented the `lxSource` / `quality` metadata contract as constants.
