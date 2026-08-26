# v2.9.6 Android platform-interface update

Version: `2.9.6+4085`

Maintained repository: `liuchuancong/pure_live`

Upstream baseline: `liuchuancong/pure_live@974f4c32`

Release date: 2026-08-25

## Scope

- Merge the latest upstream `master` with real Git ancestry while retaining the maintained repository's local-first, serial build and release policy.
- Re-audit every supported public platform adapter: Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP Live and YY Live.
- Repair the current Douyin feed-envelope parser and Bilibili popularity ordering delivered immediately before this release.
- Add playback-level live probes for Bilibili, Huya and CC, and require Douyin recommendations to contain an actual playable stream descriptor.
- Harden Bilibili signed room metadata retrieval against an expired WBI key and rejected or incomplete response envelopes.
- Build and publish only the Android arm64-v8a target requested for this release.

## Upstream synchronization

The maintained branch now contains the upstream history through `liuchuancong/pure_live@974f4c32`. The merge incorporates the latest download-confirmation, version-history and fullscreen viewing-record changes. Repository-specific launch refresh, background playback continuity, source-quality fixes and build/release safeguards remain intact.

## Platform-interface findings and repairs

### Douyin

The recommendation endpoint currently returns the room collection through more than one envelope shape. Code that assumed `data.data` could index a string or list as if it were a map and report `type 'String' is not a subtype of type 'int' of 'index'`. The parser now accepts the current list envelope, the older nested map, embedded JSON room payloads and absent optional metadata without dynamic blind indexing.

The public gate no longer accepts a card merely because it has a title and cover. It requires a usable `live_core_sdk_data`, FLV map or HLS map so a contract change cannot pass while playback is already broken.

### Bilibili

The popularity screen previously consumed a recommendation feed whose order is personalized rather than a strict popularity ranking. The maintained adapter uses the public `sort=online` source and applies a stable descending client-side comparison, so equal values remain deterministic without disturbing the server's high-to-low result.

Anonymous `getInfoByRoom` calls require a valid WBI signature and may return code `-352` after key rotation. Room metadata acquisition now validates the response before indexing, refreshes WBI keys and retries once with a short bound. Deterministic tests cover a complete response, a rejected signature and an incomplete envelope.

### Other platforms

- Douyu retains the full signing, H5 metadata, quality/CDN selection and real FLV-header read established in v2.9.5.
- Huya is checked from recommendation `profileRoom` through room detail, live metadata, bitrate descriptors and at least one usable FLV/HLS line.
- CC is checked through its recommendation-to-anchor-to-channel mapping and a live playback descriptor.
- Kuaishou continues to validate both live and recorded playback structures; Twitch, SOOP and YY retain room/search/token/line probes appropriate to their public contracts.
- Danmaku discovery remains covered for Bilibili and Huya. Authenticated playback, WebSocket sessions and device playback remain separate acceptance layers from public HTTP probes.

## Verification

- Flutter Analyze: 0 issue in the final release gate.
- Full unit/Widget suite: all tests passed in the final release gate.
- Public interface probes: 40/40 passed against the release source.
- Android package: arm64-v8a manifest/ABI/version checks, SHA-256 checksum and repository-certificate verification passed.

## Artifact

| Platform | Target artifact | Notes |
| --- | --- | --- |
| Android | `PureLive-2.9.6-4085-android-arm64-v8a-release.apk` | arm64-v8a, official repository certificate |

Windows, Linux, macOS and iOS continue to use their v2.9.4 artifacts because they are outside this turn's requested build scope.

## Evidence boundary

This update uses source review, deterministic parser tests, live public API/CDN probes, build metadata, APK manifest/ABI inspection, checksum verification and certificate verification. No phone or ADB operation is part of this release task.

Return to the [documentation index](README.md).
