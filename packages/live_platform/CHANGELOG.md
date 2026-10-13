# Changelog

## Unreleased

### Fixed

- `AtomicFileWriter` derived its temp file name from the target's directory plus
  `DateTime.now().microsecondsSinceEpoch`. Two writes started in the same
  microsecond in one directory claimed the **same temp path**: the loser's rename
  then failed outright, and the interleaved case would have promoted a file holding
  bytes from two different payloads under one of the two names. Temp names are now
  built from the pid, a per-process counter and the target's own name.
- A raw `PathExistsException` escaped the package's error contract. The parent
  directory creation sat outside the `try` that translates `FileSystemException`
  into `StorageOperationException`, so a target whose parent segment was already
  occupied by a file produced an untranslatable error — precisely the case callers
  are told not to catch, since `platform_exception.dart` asks them to match on
  `PlatformException`.
- `DistributionDetector.detect` compared the segment before `Packages` against
  `localappdata`, but in the real container path (`…\AppData\Local\Packages\<id>\…`)
  that segment is `Local`; `LocalAppData` is the shell name of the root and never
  appears as a path segment. MSIX builds therefore always came back `unknown` and
  lost their container storage rules. The rule now requires the documented
  `AppData` → `Local` → `Packages` → package-id sequence.
- The same detector split the path only on `Platform.pathSeparator`, so a Windows
  path arriving with `/` separators (a hand-written default, a plugin value, a
  config file) collapsed into a single opaque segment and the container keyword was
  never found. It now splits through `package:path`.

### Added

- Tests for atomic writes and distribution detection: content round-trip, parent
  directory creation, no leftover tail after a shorter replacement, no surviving
  temp file, the typed error on a blocked write, concurrent writes into one
  directory, and both directions of the conservative detection rule (the MSIX
  container is recognized; a directory that merely looks portable is not).

### Known gaps

- `ShutdownCoordinator` declares phases, ordering and per-task results but has no
  implementation anywhere in this workspace; the app does not yet drain resources in
  order.

### Breaking Changes

- Initial development release; no stability commitment yet.
