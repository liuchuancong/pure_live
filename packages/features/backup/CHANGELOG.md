# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `WebDavBackupService` now takes a `SnapshotRemote` port plus the `BackupEngine` /
  `RestoreEngine` instead of a raw store and two host closures. `WebDavBackupStore` is a final class in
  foundation/backup, so the transport could not be substituted and the promise in the old header comment
  ("tests use a fake store") was not achievable; `WebDavSnapshotRemote` is the adapter.
- **Breaking**: `push()` returns `ArchiveContents` (names, counts, bytes, creation time) instead of a
  `BackupOutcome` carrying a Chinese sentence, and `pull()` became `restore` / `restoreNewest` returning
  `BackupRestoreReport`.
- **Fixed**: the summary was built *after* a successful upload by casting `document['manifest']['domains']`,
  so any manifest shape change made an archive that had already landed report as a failure. It is now read
  from the typed bundle before the transfer.
- **Fixed**: `listRemote()` claimed newest-first and returned server order.
- Added the snapshot-name guard: a name containing `/`, `\`, `..` or a control character is refused, because
  it becomes a path component on someone's WebDAV server and could move the backup out of its directory.
- Added the archive codec (`encodeBackupBundle` / `decodeBackupDocument` / `encodeBackupText` /
  `decodeBackupText`) that `apps/pure_live/lib/app/user_backup.dart` had been re-deriving: a missing
  `payload` is now a named `BackupFormatFailure` instead of a raw null cast, an archive that claims to
  contain credentials is refused rather than trusted, a domain listed without values cannot restore as
  "empty", and the accepted schema versions are an explicit parameter rather than an accident.
- Transfer failures surface as `BackupServiceFailure` with the original cause attached; `retry()` applies
  only the failed domains and returns the same report untouched when nothing failed.
- Declared `pure_live_backup`, `pure_live_utils` and the `test` dev dependency.
