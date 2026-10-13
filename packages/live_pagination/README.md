# live_pagination

One pagination engine behind two interaction models: desktop numbered pages and
mobile infinite scroll. Pure Dart, no dependencies but `meta`.

## Purpose

Every list in this app that can outgrow one request needs the same three answers,
and every feature that grows one tends to answer them differently: what follows
this page, what happens when the dataset shrinks under the page you are on, and
what a failed page costs the user. The package owns those answers so loaders and
views do not each invent their own.

## Responsibilities

- `PageLoader` / `PageRequest` / `PageResult` — the contract. A loader turns a
  logical page request into exactly that page's content; batch aggregation, cursor
  handling and slicing stay inside the loader, and **the engine never issues
  follow-up requests to fill a gap it did not ask for**.
- `PageMath` — the only place that relates pages, counts and sizes: `totalPages`,
  `clampPage`, `isValidPage`, `pageForIndex`, `slice`, and `hasMoreAfter`.
- `PagedController` — exactly one visible page, with jump/next/previous, page-size
  change that keeps the first visible row roughly in place, and a refresh policy.
- `InfiniteController` — accumulates pages, rebuilds from page 1 on refresh, and
  resumes an append at the page it failed on rather than skipping a batch.
- `PaginationSession` — the generation counter that drops stale answers (an append
  landing after a refresh started, a refresh landing after a query changed).

## Explicitly not owned

Network, persistence, Riverpod, widgets, scroll-position restoration. `example/`
shows the engine driven by a fake loader only.

## The rules that decide "is there more"

`PageResult` may state three things, and they are consulted in this order — this
is the whole contract in one place, because getting it wrong does not throw, it
produces a "next" button that walks through empty pages, or a list that stops at
page one:

1. the loader's explicit `hasMore` answer wins outright;
2. else a known `totalCount` decides it (`page < totalPages`);
3. else — a forward-only or cursor source that says neither — whether the page
   brought back anything at all. A **short** page does not end the walk here, only
   an empty one does: nothing has proven the end, and cutting it off early hides
   data instead of wasting one request.

Two more invariants worth knowing before writing a loader:

- **Pages are 1-based and stay that way.** `PageRequest` guards it with an `assert`,
  which is compiled out in release, so `clampPage` and `pageForIndex` are the real
  protection: an empty dataset (`totalPages == 0`) is still page one, and an index
  outside the list maps to page one rather than page zero.
- **A page number never lies about its content.** If a jump to page 9 turns out to
  exceed the total, the clamped page is re-requested rather than emitting page 9's
  rows under the label "page 2". Likewise an advance that finds nothing keeps the
  rows already on screen and marks the walk ended, instead of replacing a full page
  with an empty one.

## Who may depend on it

Feature packages and the app. It depends on nothing, so it can sit at the bottom of
any stack.

## Public entry point

`package:live_pagination/live_pagination.dart`.

## Testing

```powershell
dart test
```

`test/end_of_data_test.dart` pins the rules above against fakes that behave badly on
purpose — a loader that answers an out-of-range page with rows of its own, a cursor
source that states no total, an empty library. Loader misbehaviour is the case worth
covering, since a well-behaved loader needs no engine.

## Known limitations

- `PagedController.retry()` re-issues the last failed page; it does not back off or
  bound the attempts — that is the caller's policy.
- Refresh and append races are resolved by generation only within one controller;
  two controllers over the same source know nothing of each other.
- `changePageSize` keeps the *first* row of the old page roughly in place; it does
  not try to keep a selected row anchored.
