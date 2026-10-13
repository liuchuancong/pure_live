# Changelog

## Unreleased

### Fixed

- `PagedController` ignored `PageResult.hasMore` entirely, so a source that states
  its own end (or states neither a total nor a continuation) was walked past its
  last page: `next()` kept advancing through empty pages instead of refusing. The
  end-of-data decision now lives in one place, `PageMath.hasMoreAfter`, consulted
  by both controllers.
- `InfiniteController.refresh()` derived "is there more" from a count of zero items
  regardless of what the first page returned, so an unknown-total cursor source was
  marked finished on its own first page and `loadNext()` could never append. The
  items actually received are now passed.
- `PageMath.clampPage(1, 0)` returned `0`: an empty library (`totalCount == 0`,
  hence no pages) was requested as page zero, which makes a loader compute
  `(0 - 1) * pageSize` as a negative offset. `PageRequest`'s guard is an `assert`,
  so nothing protected a release build. An empty dataset is now page one.
- `PageMath.pageForIndex` mapped a negative index to page zero. Reached by
  `changePageSize` before the first load, where the "keep the first visible row"
  anchor is `(0 - 1) * pageSize`: it threw in debug (surfacing as `state.error`) and
  sent page zero in release. Indices outside the list now map to page one.
- A page request whose target was clamped by a total the answer itself revealed
  emitted the fetched rows under the clamped page number — page 9's content titled
  "page 2". The clamped page is now re-requested whenever it differs.
- An advance that returned nothing replaced a full page of rows with an empty one to
  record that the walk had ended. The rows on screen are kept and the end is marked.
- `next()` reported success when its request was refused because one was already in
  flight, which would have a caller disable a control that was still valid.
- The state snapshot before the first load reported the default page size rather than
  the controller's, so a view deriving "page 1 of N" pre-load used the wrong divisor.

### Changed

- `PageMath.isValidPage` is now what `next()` and `previous()` consult, replacing two
  hand-written restatements of the same predicate.
- `dispose()` documentation corrected in both controllers: it drops its listeners
  (the comment claimed they stayed attached).

### Breaking Changes

- Renamed from `pagination_core` to `live_pagination` for the repository naming
  convention; entry point is `lib/live_pagination.dart`. No dependents existed.
