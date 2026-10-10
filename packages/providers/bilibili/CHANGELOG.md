# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed(签名)**:`sign` returned a map and hashed it with `Uri.encodeQueryComponent`, whose space is `+` and
  whose escaped `!~*'()` are not what the site's own JavaScript client (`encodeURIComponent`) hashes - and then
  dio encoded the map a second time on the way out. Any keyword containing a space produced a signature that
  could not match. The signer now returns the built query string (`wbiSignedQuery`), so the bytes sent are the
  bytes hashed, and `Uri.encodeComponent` is used because it *is* `encodeURIComponent`'s Dart spelling.
- **Fixed**:`browse` never checked the response's `code`, so a risk-control answer (-352) decoded as "this page
  has nothing on it" - an empty list where a refusal belongs, with nothing for the recovery ladder to retry.
  Every entry point now refuses on a non-zero code and carries the site's own `message` into the failure.
- **Fixed**: `BiliWbiSigner` built its own `NetworkClient` whenever the source was constructed without one, and
  `dispose()` could not reach it - every source instance leaked a dio instance and its connection pool. The
  source now creates one client and shares it.
- The episode's `cid` travels in the ticket's own `metadata.extra`, and `refresh` reads it from there. It used
  to live in a process-side `Map<String,int>` that grew without bound for the lifetime of the app and, once
  gone, made re-minting a working ticket impossible.
- `wbiMixinKey` refuses a source key too short to permute into 32 characters instead of substringing whatever
  arrived, which signed with a truncated key and failed as a risk-control code that named nothing.
- The key cache has an expiry (`keyLifetime`, 6 h) and a failure backoff (`failureBackoff`, 2 m): without the
  latter, one nav outage turned every signed request into a fresh nav request plus its own timeout.
- `randomBuvid3` draws from `Random.secure()` in the shape the site issues (`8-4-4-4-12` + `infoc`). The first
  version split `microsecondsSinceEpoch` into hex fields, yielding a 16-character first segment and one value
  per microsecond.
- Search titles are unescaped after the `<em>` wrapper is stripped (`&quot;` reached the list as literal text),
  and a duration that does not parse is null rather than a zero-length video (`"--:--"`, `""`).
- `browse` refuses a category it does not serve instead of quietly returning the popular table; `resolve`
  refuses a named `line` (one guest stream per page) and records a requested `quality` it could not honour,
  because a guest bitrate cap silently dropped is how "I chose 1080p" becomes "it played 480p".
- Covers upgrade `http://` to `https://` on the same host; response `code`/`data` shapes are read through helpers
  that tolerate a missing or wrongly-typed field instead of casting straight.
- Declared `pure_live_utils` (the injected `Clock`) and `dio` as a dev dependency for the transport fake.
- Added `test/bili_wbi_test.dart` (11 cases) and `test/bilibili_vod_source_test.dart` (17 cases). The package
  had no tests before. `dart test`: 28 passing.
- Earlier: skeleton created for layer providers as `pure_live_bilibili`, then the first endpoint slice.
