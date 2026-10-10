# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `SearchHistory` became `StoredSearchHistory` implementing the new
  `SearchHistoryRepository` interface, and moved from `data/search_history.dart` to
  `data/stored_search_history.dart`. Entries are `SearchHistoryEntry` (term + UTC instant), not bare strings.
- **Breaking**: the stored row is now an envelope `{"v":1,"items":[{"q","at"}]}` under `<namespace>.history`.
  A version-0 bare string list is still read and migrated on the next write; a row newer than this build is
  left untouched rather than rewritten.
- Added `SearchTerm`: the keyword as typed plus its folded comparison key, with the blank refusal in one
  place. History dedup and ranking both go through it, so "the same query" means the same thing in all four
  apps.
- Added `rankSearchResults`, `relevanceOf` and `RankedResult` — a content-based total order over an
  aggregate, so the list does not depend on which source answered first.
- Added `SearchController` with the generation fence (`SearchAnswer` / `SearchRejected` / `SearchSuperseded`)
  and an abandonment-only `CancellationToken`.
- Added `maxLength` validation and `onReadFailure` accounting; an unreadable row no longer looks like "never
  searched".
- Declared the dependencies this package actually imports (`platform`, `services/search`, `storage`, `utils`).
  Pub workspace resolution had been hiding them: the package compiled with an empty `dependencies:` block.
