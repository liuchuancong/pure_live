# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Implemented the anonymous Douyu slice on the v2 capability contracts: `DouyuSource` serves
  `FeedCapability`, `BrowseCapability`, `SearchCapability` and `ResolveCapability`; the signing lives in
  `DouyuSigner`/`douyuSignedForm`. Provenance is the v1-maintained line
  (`origin/master lib/shared/platforms/douyu/douyu_site.dart` and `lib/core/network/douyu_utils.dart`) — a
  fresh implementation against the contracts, not a merge (UPSTREAM_REVIEW_POLICY.md).
- The resolved ticket carries a real deadline: `expiresAt = createdAt + expire`, with the refresh lead at a
  quarter of the lease or 45s, whichever is shorter. A signed url without a stated deadline is what made the
  platform's prefetch unable to schedule a replacement.
- `refresh` returns a rejected `Future` rather than throwing synchronously for a ticket from another source.
- Not included in this slice, deliberately: login cookie and passport renewal, danmaku, quality and CDN line
  picking, super chat. See the README.
- Added 49 tests (`test/douyu_sign_test.dart`, `test/douyu_row_test.dart`, `test/douyu_source_test.dart`).
  The transport is replaced with a canned dio adapter rather than faking the client, so the decoding path the
  tests exercise is the real one.
- Skeleton created for layer providers as `pure_live_douyu`: no dependencies and no implementation yet.
