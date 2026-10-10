# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- The history row is now a typed preference of `pure_live_storage` (`PreferenceKey<List<SearchHistoryEntry>>`,
  codec `searchHistory`) instead of a JSON string this file wrapped in its own envelope. Envelope, namespace,
  codec gating and rejection accounting come from the mechanism that `features/home` adopted in the same pass;
  what stays here is what is about histories: the bound, the folded-term dedup, the comparator, and reading
  the two older shapes - the bare keyword list of version 0 and the pre-mechanism `{v, items}` string - through
  `PreferenceKey.upgrade`. A read never rewrites a legacy row.
- The key is unchanged (`<namespace>.history`), so rows written by the previous build are the rows this build
  reads; a corrupt row is still reported and then replaced by the next write.
- Added `dispose()` for the change stream of the store this repository creates. Nothing constructs these two
  repositories in an app yet, so no caller is currently responsible for it.
- Test updated rather than deleted where it pinned the old raw shape (`corruptRow_isReportedAndHealed` now
  asserts the shared envelope plus the document version inside it). 22 tests passing.

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
