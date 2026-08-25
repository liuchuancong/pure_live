# v2.9.5 Android stability update

Version: `2.9.5+4084`  
Maintained repository: `wzgrx/pure_live`
Upstream baseline: `liuchuancong/pure_live@a161a324`
Release date: 2026-08-24

## Scope

- Merge the latest upstream master with real Git ancestry and preserve the repository's serial, local-first build policy.
- Fix Douyu H5 stream acquisition and downstream media requests reported by upstream issue #785.
- Audit every supported public platform interface and extend the gate from 29 checks to 36 checks.
- Harden the newly synchronized YY adapter without adding a native JavaScript runtime.
- Complete the follow-up for issue #784 by replacing the search platform `TabBar` with a bounded selector and hardening native/web search behavior.
- Build and publish only the Android arm64-v8a target requested for this release.
- Repair the shared quality-selection contract and verify every supported adapter instead of applying another platform-specific UI-only patch.
- Replace the fixed fullscreen quality/line allocation with a content-sized panel whose buttons remain the main visual area.
- Separate CC heat from concurrent viewers and make cross-platform audience ranking compare metric tiers before raw values.

## Douyu root cause and repair

The earlier gate verified the encryption descriptor but never executed the complete path from H5 metadata to CDN bytes. The adapter also relied on one shared sample DID, a long-lived descriptor cache, a single API attempt, strict optional-field indexing, and no Douyu headers on the player's media request. Those gaps produced the same generic stream-read failure for different upstream response and CDN-policy changes.

v2.9.5 uses one random DID per process, sends matching browser headers and cookies, caps descriptor cache age at five minutes, and performs one forced-refresh retry. It validates API status before parsing, falls back when quality/CDN lists are partial, deduplicates lines, decodes escaped URLs, and passes Referer/Origin/User-Agent/Cookie to every playback backend.

The interface probe now selects an active room, reproduces the Dart signing path, obtains H5 playback metadata, validates quality and CDN fields, downloads a byte range with the real player headers, and checks the `FLV` file signature.

## All-platform quality switching

The recurring symptom—tapping a different label while the picture stayed unchanged—had several independent root causes behind one generic UI:

1. The controller committed the selected index before the new media source had opened, so a parser/CDN/decoder failure still looked successful.
2. Bilibili advertised qualities through `accept_qn` but could silently return a lower `current_qn` for a guest request.
3. Huya reused a captured anti-leech query containing an old `ratio`; the earlier code only appended `ratio` when absent, so most taps kept the captured quality. It also invented a 2000-kbps option when the platform returned no rate list.
4. Douyin paired quality names and legacy URLs by Map position even though the contract is the stable `sdk_key`.
5. Douyu's `rate` value was treated as sortable bitrate even though source commonly uses code `0`; Twitch paired independent BANDWIDTH and URL arrays and stored the temporary result in one mutable site-level list.
6. The model had no dedicated stable identifier, so mutable URL lists or adapter maps could accidentally become selection identity.

The repair adds a stable `selectionId`, an optional server-acknowledged resolution result, ordered URL normalization and one transactional switch path. The old source stays active while resolving; only the newest request may apply; indices are clamped against the new line list; duplicate IDs and blank entries are removed; duplicate labels are numbered; identical resulting source sets are rejected; and UI state commits only after the player accepts the new source. Failures roll back atomically, and a toast-host lifecycle race no longer escapes as a second exception.

Adapter-specific regression fixtures now cover Bilibili qn acknowledgement, Douyu opaque rate order, Huya ratio replacement/removal, Douyin key-based joins, Kuaishou representation/CDN merging, CC resolution/CDN binding, Twitch's stateless master-playlist pairing, SOOP preset IDs, YY gear IDs/CDN validation, and IPTV's single-source boundary.

## Fullscreen selector and audience metrics

The screenshot's large empty cards came from a fixed half-screen dialog plus a fixed split between quality and line panes. The new policy calculates rows from real option counts, sizes the complete dialog to its content, balances four items as `2×2`, reserves minimum usable space only when overflow exists and scrolls just the affected grid. Redundant selected-value chips and excess chrome were removed; 42-pixel choice buttons and their labels occupy most of each pane.

CC's large `webcc_visitor` value is retained as heat while `vision_visitor/online_num` supplies concurrent viewers. In concurrent mode, explicit viewer counts rank first, supported-but-pending rooms second and heat/cumulative-only rooms last, preventing a multi-million heat score from outranking a real audience of a few thousand. Equal values use stable platform/room identity so cards do not reshuffle between refreshes.

## YY and upstream integration

- Keep upstream YY categories, recommendations, playback, danmaku, account route, assets and translations.
- Parse the three category query literals directly in Dart and remove `flutter_js` from runtime dependencies and generated plugin registrants.
- Normalize HTTP and protocol-relative URLs to HTTPS.
- Query `/api/liveInfoDetail/{sid}/{sid}/0` directly so live/offline refresh no longer depends on brittle room-page HTML or reports every room as live.
- Correct room search and anchor search response types, identifiers, avatar fields and `liveOn` values.
- Fix the account page to observe `yyCookie` rather than the Huya Cookie.
- Parse localized audience values before sorting multiview room choices.
- Preserve deterministic dependency resolution after the criss-cross upstream merge, remove the duplicate YY search-capability entry, and restore an injectable player creator so native-independent playback regressions continue to exercise the real manager state machine.
- Accept both supported release-history JSON envelopes and use the current upstream request headers from `a161a324`.

## Search follow-up and root cause

The v2.9.4 patch gave the scrollable `TabBar` clamping physics, but the widget still combined its own tab-selection animation with an internal horizontal position even though this page has no matching `TabBarView`. That left the visible strip and the controller index coupled to two independent movement paths. Rebuilding `Sites.availableSites()` also created fresh adapter instances for labels, searching, pagination and web navigation; this could lose cursor state or map an index to a different snapshot.

v2.9.5 uses a dedicated clipped horizontal platform selector with an owned controller and clamped first/last boundaries. The search controller retains one immutable platform/adapter snapshot for its lifetime and changes platform through one bounded index method.

Cross-platform requests still run concurrently, but completed platforms are now rendered progressively and every individual request has a 12-second UI deadline. A stalled endpoint therefore no longer holds all results for the global 20-second HTTP timeout. Results remain generation-guarded, deduplicated and independently paginated. YY joins native search; requested page sizes now reach the Bilibili, Douyu, Huya, CC and SOOP endpoints.

The web-search room parser is now a pure tested component. It covers all nine applicable websites, rejects search/category pages and lookalike hosts, and returns both room ID and platform so a cross-site link cannot be opened by the wrong adapter. Invalid certificate challenges are cancelled rather than silently accepted.

## Verification

- Focused player-creation and search synchronization regression tests: 27/27 passed.
- Flutter Analyze: 0 issue (one final invocation after source freeze).
- Full unit/Widget suite: 358/358 passed.
- Public interface probes: 36/36 passed in the final gate.
- Full gate record: `20260824T142502430Z-quality-full.json`; 812.839 seconds, peak monitored working set 14.52 GiB, no active heavy process left after completion.
- Android package verification: pending final arm64-v8a release build and official repository signing.

## Artifact

| Platform | Target artifact | Notes |
| --- | --- | --- |
| Android | `PureLive-2.9.5-4084-android-arm64-v8a-release.apk` | arm64-v8a, official repository certificate |

Windows, Linux, macOS and iOS continue to use v2.9.4 artifacts because they were outside this turn's requested build scope.

## Evidence boundary

This update uses source review, deterministic tests, live public API/CDN probes, build metadata, APK manifest/ABI inspection, checksum verification and certificate verification. It does not run ADB or automate a phone; device acceptance remains an independent post-release layer.

Return to the [documentation index](README.md).
