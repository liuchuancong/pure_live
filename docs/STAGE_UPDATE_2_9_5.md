# v2.9.5 Android stability update

Version: `2.9.5+4084`  
Maintained repository: `wzgrx/pure_live`  
Upstream baseline: `liuchuancong/pure_live@cc1f4dca`  
Release date: 2026-08-24

## Scope

- Merge the latest upstream master with real Git ancestry and preserve the repository's serial, local-first build policy.
- Fix Douyu H5 stream acquisition and downstream media requests reported by upstream issue #785.
- Audit every supported public platform interface and extend the gate from 29 checks to 36 checks.
- Harden the newly synchronized YY adapter without adding a native JavaScript runtime.
- Build and publish only the Android arm64-v8a target requested for this release.

## Douyu root cause and repair

The earlier gate verified the encryption descriptor but never executed the complete path from H5 metadata to CDN bytes. The adapter also relied on one shared sample DID, a long-lived descriptor cache, a single API attempt, strict optional-field indexing, and no Douyu headers on the player's media request. Those gaps produced the same generic stream-read failure for different upstream response and CDN-policy changes.

v2.9.5 uses one random DID per process, sends matching browser headers and cookies, caps descriptor cache age at five minutes, and performs one forced-refresh retry. It validates API status before parsing, falls back when quality/CDN lists are partial, deduplicates lines, decodes escaped URLs, and passes Referer/Origin/User-Agent/Cookie to every playback backend.

The interface probe now selects an active room, reproduces the Dart signing path, obtains H5 playback metadata, validates quality and CDN fields, downloads a byte range with the real player headers, and checks the `FLV` file signature.

## YY and upstream integration

- Keep upstream YY categories, recommendations, playback, danmaku, account route, assets and translations.
- Parse the three category query literals directly in Dart and remove `flutter_js` from runtime dependencies and generated plugin registrants.
- Normalize HTTP and protocol-relative URLs to HTTPS.
- Query `/api/liveInfoDetail/{sid}/{sid}/0` directly so live/offline refresh no longer depends on brittle room-page HTML or reports every room as live.
- Correct room search and anchor search response types, identifiers, avatar fields and `liveOn` values.
- Fix the account page to observe `yyCookie` rather than the Huya Cookie.
- Parse localized audience values before sorting multiview room choices.

## Verification

- Focused Douyu, YY, signing and multiview tests: passed.
- Flutter Analyze: pending final release gate.
- Full unit/Widget suite: pending final release gate.
- Public interface probes: 36/36 passed before source freeze; the full gate reruns them once.
- Android package verification: pending final arm64-v8a release build and official repository signing.

## Artifact

| Platform | Target artifact | Notes |
| --- | --- | --- |
| Android | `PureLive-2.9.5-4084-android-arm64-v8a-release.apk` | arm64-v8a, official repository certificate |

Windows, Linux, macOS and iOS continue to use v2.9.4 artifacts because they were outside this turn's requested build scope.

## Evidence boundary

This update uses source review, deterministic tests, live public API/CDN probes, build metadata, APK manifest/ABI inspection, checksum verification and certificate verification. It does not run ADB or automate a phone; device acceptance remains an independent post-release layer.

Return to the [documentation index](README.md).
