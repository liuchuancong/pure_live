# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `StoredWatchProgress` now keeps each reference's row as a typed preference of `pure_live_storage`
  (`PreferenceKey<WatchProgress>`, codec `watchProgress`) instead of writing a JSON string with a hand-rolled
  `v` field. The envelope, the namespace, the codec gate and the bounded rejection log are the mechanism's;
  what this package keeps is the rule set about watch positions - refusing a row from a newer build, refusing
  a row with no usable `positionMs` or no parseable `updatedAt`, and the argument checks on save.
- The refusals say which of those happened, through `PreferenceDecodeReject`: "a newer build wrote this" is
  fixed by updating the app, "this row has no position" is damage, and a report that cannot tell them apart
  cannot be acted on.
- Key names are unchanged (`progress.` + `identityKey(sourceId, contentId)`), so rows written by the previous
  build are the rows this build reads, and the length-prefixed identity key still keeps `a`+`b/c` apart from
  `a/b`+`c`. Reading a pre-mechanism row does not rewrite it.
- Added `dispose()` for the change stream this repository creates; no app constructs it yet, so nothing owns
  that call today.
- Tests 20 to 22: the saved envelope shape, and a legacy string row read back while still in its old form.

- **Breaking**: `EpisodeNavigator` became an immutable `EpisodeQueue`; `setCurrent` became `commit`, and
  `next()` / `previous()` became `stepNext()` / `stepPrevious()` returning an `EpisodeStep` that names
  whether the queue is at its edge. A cursor of `-1` with a non-null `current` used to be reachable and left
  both directions returning nothing without saying why.
- **Fixed**: episodes were matched with `ContentRef`'s full equality, which also compares `parentId`,
  `providerId` and `metadata`. The reference that comes back from the ticket layer carries those, so it did
  not match the queue's own entry and consecutive playback silently stopped. Matching is now by
  `sourceId + contentId` (`sameContent`).
- **Fixed**: committing an episode the queue does not hold is refused instead of corrupting the cursor.
- **Breaking**: `WatchProgressRepository` became an interface implemented by `StoredWatchProgress`, and
  `WatchProgress.isResumable` gained a second bound. It previously asked only "position > 30s", so
  reopening an episode the viewer had finished seeked to 99% of it - which reads as a broken player. A
  position inside `tailThreshold` of the known end now restarts from zero while remaining saved.
- **Security/correctness**: progress rows are keyed with a length-prefixed identity instead of
  `sourceId/contentId` joined by a slash. Path-like episode ids made two episodes collide on one row, so one
  viewer's position overwrote another's.
- Added the envelope `{v:1,positionMs,durationMs,updatedAt}` with v0 read-through, `onReadFailure`
  accounting, per-app `namespace`, an injected `Clock` instead of `DateTime.now()`, and rejection of negative
  positions and zero-or-negative durations.
- `WatchProgress.progress` exposes the fraction only when a length is known; the unknown case returns null
  rather than inventing one.
- Declared `pure_live_utils` and the `test` dev dependency.
