# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking** `UpdateChecker` takes a required `UpdateFeedTransport` instead of an optional
  `NetworkClient`, and `dispose()` is gone. The package no longer reaches `pure_live_network`: an L0 package
  depending on another L0 is forbidden by its own README, and the reference was carried in `dev_dependencies`,
  which is not a declaration `lib/` may use — a consumer resolving this package would not have seen the name at
  all. The app binds the seam (apps/pure_live/lib/app/update_transport.dart).
- **Fixed** every `UpdateChecker` leaked an `HttpClient`: the default client was created per check and closed
  only by a `dispose()` no caller invoked. The transport is borrowed now and the runtime owns its lifecycle.
- **Fixed** a check with a silent host hung for as long as the transport's own timeout allowed; `check` now
  imposes `kDefaultUpdateFeedTimeout` (15s) and reports the deadline as `UpdateCheckResult.error`.
- Added `test/update_feed_test.dart`: status, malformed body, unparsable head row, transport failure, deadline
  and the per-platform asset pick. `update_feed.dart` had no test at all before.
- Skeleton created for layer foundation as `pure_live_release`: no dependencies and no implementation yet.
