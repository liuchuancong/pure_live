# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Added the location vocabulary and the resolver behind it: `StorageKind` (ten purposes, each with the
  evictable / user-visible / backup-excluded properties that decide who may clean it), `HostPlatform`, and
  `AppPaths`, which turns a purpose into a directory for Android (internal private first, shared storage only
  where it is actually granted), iOS and macOS containers, Windows installed builds (roaming for settings and
  databases, local for caches and logs), Windows MSIX builds (`Packages\<family>\LocalState|LocalCache|TempState`,
  because writing to `%LOCALAPPDATA%` from inside the sandbox lands in a virtualised copy the next launch does
  not see), Linux XDG (settings in configHome so resetting an app does not take its history), portable desktop
  builds (data beside the executable, temp still on the system volume) and web (every location unavailable, so
  a caller degrades to memory instead of throwing).
- Added `StorageGuard`: create-and-prove-writable (a resolved path is not a writable one - a card can be
  unmounted, a roaming profile read-only, a USB stick write-protected), session-cached probe results with
  `invalidate()` for the moment a permission changes, byte accounting, budgeted eviction oldest-first with an
  absolute `keep` predicate and a `skipped` count for files another process holds open, and a free-space check
  that answers "unknown" rather than refusing when the host has no probe.
- Added `StorageCapacity`, the `DiskCapacityProbe` port Dart's io library cannot fill, `EvictionReport`,
  `StorageGuardFailure` and `ResolvedPath`.
- Dependencies: `path` (host separator style) and `xdg_directories` (the specification's own fallbacks) rather
  than hand-rolled joining, plus the `pure_live_utils` leaf for `DomainFailure`, `ByteSize` and `Clock`.

- Skeleton created for layer foundation as `pure_live_files`: no dependencies and no implementation yet.
