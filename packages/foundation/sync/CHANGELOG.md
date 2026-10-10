# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased (2026-10-10, cursor and rejection pass)

- **Breaking**: `RemoteStore.fetchSince` returns a `RemoteBatch` (records **plus the cursor to continue
  from**) instead of a bare list. The engine had no way to learn the new position, so `pull()` echoed the
  cursor it was given: a caller doing the obvious `pull(from: lastReport.cursor)` re-downloaded the entire
  history every pass and the sync looked healthy while doing N+1 times the work.
- **Breaking**: `SyncReport.cursor` became `SyncReport.nextCursor`, nullable, with `cursorAfter(previous)` to
  continue. `null` means "this pass learned nothing" - the old shape had no way to say that, so an idle push
  reported `SyncCursor.start` and a caller that obeyed it restarted full history.
- `push()` takes the cursor the caller holds (`known:`) so an idle pass can hand it back unchanged.
- A remote that answers with the same cursor it was asked for is **not** reported as progress.
- Unusable rows are counted, not hidden: a blank key is `rejected`, a key repeated inside one batch keeps
  the later row and counts the collapse, and credential keys stay a separate count because they are the
  remote violating a rule rather than sending junk.
- `pull()`'s `clock` parameter was removed: it read the clock and discarded the value, which documented a
  determinism guarantee the function did not have.
- `SyncCursor` gained value equality, because "did this pass advance" is a comparison and comparing identity
  would answer "no" to every equal token.

- Skeleton created for layer foundation as `pure_live_sync`: no dependencies and no implementation yet.
