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
- **Fixed**: the constructor kept the caller's `entries` list even though the getter returned an unmodifiable
  view, so `removeAt` / `add` on the list that was handed in could change the queue while a song played. It
  copies now, which costs the `const` constructor (internal transitions build their own lists anyway).
- Added the edits a music surface actually performs, each keeping the cursor on the **song** rather than the
  index: `insertAt` (shifts a cursor at or after the insertion point), `move` (a drag; the playing track rides
  along with the row), `withEntries` (replace the queue from a playlist; a cursor whose song is gone becomes
  -1 rather than silently claiming row 0 is playing), `upcoming` (the "next up" window, wrapping only under
  `repeatAll` and never longer than the queue), `peekPrevious` with a distinct `atStart`, `nextFor(skip:)`,
  and `indexOfSong` / `containsSong` / `countOfSong`.
- **Fixed**: one `peekNext` served both "the song ended" and "the viewer pressed next", so a queue with
  repeat-one could not be skipped past its first song. `nextFor(skip: true)` moves on; `peekNext()` still
  repeats.
- **Fixed**: an lx handler that answers a failed lookup with the literal string `null` (what the script
  protocol does) was returned as a play url, and the player accepted it as silence with no failure for the
  recovery path to read. A value with no scheme or host is now a `MusicSourceFailure` naming the source, song
  and quality. A cover in that shape is *not* a failure: it becomes null, so the surface draws a placeholder
  instead of refusing to start a song.
- A quality the announced source does not list is refused **before** the script is asked, with the labels it
  does serve named in the failure; an unannounced source is not evidence, so it still passes. Blank lyrics and
  blank covers read as "none". `defaultQuality` became the host's to declare, because a queue of 320k-only
  sources should not ask for `128k` on every lookup.
- Foreign exceptions from the script host are classified into `MusicSourceFailure` with the original kept as
  `cause`; a `MusicSourceFailure` passes through unchanged.
- Added `qualitiesFor` / `servesQuality` over the same announcement `availableSources` filters.
- Declared `pure_live_utils`, and documented the `lxSource` / `quality` metadata contract as constants.
