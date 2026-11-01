# live_platform_path_provider

Path and storage layer for Pure Live. Resolves a directory for every storage
area from the platform runtime's deployment facts — a portable build keeps its
data next to its executable and never writes user data into AppData — probes
writability for real, flags app-private paths before a download lands in one,
and detects config conflicts between data directories.

## Purpose

"Where do I write this file?" is answered wrong in quiet ways: a portable
build silently growing a profile in `%APPDATA%`, a video download landing in
a gallery folder the media scanner then colonises, two installs fighting over
one config, a path that looked writable until the first byte was written.
This package owns that answer once, from deployment facts, and hands out
`Directory` objects whose guarantees (portable, app-private, writable,
conflict-free) were checked rather than assumed.

## Responsibilities

- `path_provider_bootstrap` (`bootstrap/`) — the startup step that resolves
  every storage area from the platform runtime before anything else reads or
  writes.
- Storage contracts (`contracts/`) — `StorageLocation`, `StorageArea`,
  `StorageManager` and `FileAccessService`: the vocabulary the rest of the
  workspace uses for "a place to put data", plus the platform-exception
  contract callers recover from.
- The default manager and its policy (`storage/`) — atomic file writes, the
  rules that decide portable vs. per-user layout, and where each area lives.
- Conflict detection (`conflicts/`) — recognising when a chosen data
  directory collides with another install's or another profile's config.
- Insights (`insights/`) — path facts surfaced for the settings and
  diagnostics pages, with privacy rules for what may be shown or logged.
- Migration (`migration/`) — storage adoption: moving an existing install's
  data when the resolved layout changes.
- Diagnostics (`diagnostics/`) — writability probes and the report the log
  and the settings page show.

## What lives where

- `lib/live_platform_path_provider.dart` — the public surface.
- `lib/src/contracts/` — the seams; every other package codes against these.
- `lib/src/storage/` — the production implementation.
- `lib/src/bootstrap/`, `conflicts/`, `insights/`, `migration/`,
  `diagnostics/` — the lifecycle around it.
