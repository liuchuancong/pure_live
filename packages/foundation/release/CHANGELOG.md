# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `AppVersion` gained the pre-release tag (`4.1.0-beta.1+5100`) and semver 2.0.0 rule 11 ordering: a tag sorts
  **before** the same triple's stable release, dot-separated identifiers compare numerically-then-lexically, and
  the build is the last tie-break. A feed row with a tag used to fail to parse and disappear from the check.
- `channels.dart`: `ReleaseTrack` filtering (`selectRelease` reports how many rows the track refused, because
  "there is a newer release you cannot have" and "you are up to date" look the same to a user otherwise),
  `selectApk` by `ApkAbi` with a `universal` fallback and never an unrelated ABI, and `selectWindowsAsset` by
  `WindowsFlavor` - the MSIX/installer/portable choice is also the choice of where the app's data lives.
- `integrity.dart`: SHA-256 verification with both sides normalised (`SHA256:`, uppercase, spaces), an
  `ArtifactSize` check applied before the bytes are fetched, and a digest-manifest parser that errors on an
  unknown shape instead of returning an empty map that would read as "all fine".
- `snooze.dart`: the record behind a "later" button. A strict encode/decode (an unparseable record asks again
  rather than never), `SnoozeChoice` durations, and `shouldOffer` breaking the silence for any *newer* release.
- `pubspec.yaml`: `crypto` and the `utils` leaf added.

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
