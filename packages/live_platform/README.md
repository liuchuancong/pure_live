# live_platform

The platform layer: what OS and deployment style the app is running in, where its
files are allowed to live, how they are written without corrupting, and how the app
tears itself down.

## Purpose

Everything above this package would otherwise discover the platform by hand:
`Platform.isWindows` sprinkled through features, system paths spliced with string
concatenation, `File.writeAsString` on a user's library with no crash safety, and a
`try/catch` that swallows the difference between "disk full", "no permission" and
"the user cancelled". Each of those is a decision, and each decision belongs here,
made once, with tests.

## Responsibilities

- `PlatformBootstrap` — the one-time initialization the app calls before anything
  else reads platform facts.
- `PlatformEnvironment` / `PlatformRuntimeInfo` — the facts: `PlatformKind`,
  `FormFactor`, and `PlatformCapabilities` for optional features.
- `DesktopDistribution` + `DistributionDetector` — deployment style, kept separate
  from OS because Windows alone has three (installed, MSIX, portable). Detection is
  deliberately conservative: it recognizes the MSIX per-user package container and
  otherwise answers `unknown`; **portable mode is never guessed from a directory or
  file name**, because a wrong guess makes an installed build write beside its own
  executable.
- `StorageManager` / `StorageArea` / `StorageLocation` / `StoragePolicy` — resolve a
  storage area to a usable directory by probing candidates and falling back, instead
  of assuming the first path works.
- `AtomicFileWriter` — crash-safe file replacement: write a unique temp file in the
  target's own directory, flush, rename into place.
- `PlatformException` hierarchy — the error vocabulary every adapter translates into
  (`StorageUnavailable`, `StoragePermission`, `StorageCapacity`, `StorageOperation`,
  `UnsupportedCapability`, and `UserCancelled`, which is flow control, not a failure).
- `FileAccessService` — the file-picker seam, so features never import a plugin.
- `StorageDiagnostics` — what was resolved, what failed, and why.

## Explicitly not owned

What the files mean. A box schema, a playlist format, an app-data record shape —
all business concerns. This package answers "where may I write, and how do I write it
without losing it", never "what goes in there".

## Public entry point

`package:live_platform/live_platform.dart`.

## Dependencies

`path`. Pure Dart, no Flutter and no plugin: the app shell injects the storage
directory and the file-access implementation, which is what keeps this layer testable
and keeps plugins out of business modules.

## Workspace usage

```yaml
dependencies:
  live_platform:
    path: ../live_platform
```

`live_shell` takes `PlatformKind` from here so platform identity has one owner; prefer
these types over raw `Platform` checks in your own package.

## Testing

```powershell
dart test
```

`test/atomic_file_writer_test.dart` covers the promises that matter for user data:
a shorter replacement leaves no tail of the previous bytes, no temp file survives a
successful write, a blocked write reports `StorageOperationException` rather than a
raw file-system error, and concurrent writes to one directory cannot claim the same
temp file. `test/distribution_detector_test.dart` pins both directions of the
conservative rule — the container is recognized, and a directory that merely looks
portable is not.

## Known limitations

- **`ShutdownCoordinator` is a contract with no implementation in this repository.**
  Phases, ordering and per-task results are declared and documented, but nothing
  provides them yet; the app does not currently drain resources in order.
- MSIX recognition is a Windows path-shape test only; a container relocation outside
  the documented layout reads as `unknown`, which behaves like `installed`.
- `AtomicFileWriter`'s remove-then-rename is not one atomic step on Windows; the temp
  copy guards against truncated writes, not against a power loss in that window.
- Temp paths are unique per process (pid plus a counter), so two app instances writing
  the same file concurrently still race each other.
