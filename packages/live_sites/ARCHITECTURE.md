# Live Sites Architecture Specification

> **Package:** `live_sites`  
> **Type:** Internal Dart/Flutter workspace package  
> **Status:** Architecture Specification  
> **Purpose:** Provide a unified, maintainable integration layer for live-streaming platforms.

## 1. Design Goals

The `live_sites` package integrates multiple live-streaming platforms behind a consistent API.

All platform implementations MUST reside inside this package.

The architecture MUST satisfy the following requirements:

1. All live-streaming platforms share one package and one public contract.
2. Each platform implementation is isolated within its own directory.
3. Platform capabilities are optional and MUST reflect actual platform support.
4. Shared models and interfaces MUST NOT depend on specific platform implementations.
5. Platform-specific APIs, parsers, signing algorithms, and protocol implementations MUST remain isolated.
6. UI, routing, application state management, and playback engine selection MUST remain outside this package.
7. The architecture MUST support Android, iOS, Android TV, Windows, macOS, and Linux where platform capabilities permit.
8. Unsupported operations MUST be distinguishable from empty results.
9. Public interfaces MUST remain stable as individual platform implementations evolve.
10. All source comments and API documentation MUST be written in English.

## 2. Package Boundaries

### 2.1 Responsibilities

`live_sites` is responsible for:

- Platform metadata and identity.
- Platform initialization and lifecycle.
- Room and anchor information.
- Hot lists, discovery feeds, and categories when supported.
- Room and anchor search when supported.
- Playback URL resolution.
- Danmaku protocol adaptation.
- Platform-specific HTTP requests, parsing, and signing.
- Platform-specific WebView search descriptions.
- Shared live-streaming models, errors, pagination, and capability contracts.

### 2.2 Non-responsibilities

The package MUST NOT implement:

- Application pages or navigation.
- UI theme or layout systems.
- Player engine implementations.
- Playback session recovery policies.
- Application-level favorites and viewing history.
- Global application state management.
- Dynamic plugin loading or installation.
- Plugin sandboxing or third-party plugin permissions.
- Application startup or dependency injection composition.

### 2.3 Dependency Direction

```text
apps/pure_live
    |
    +---- live_sites
    |       |
    |       +---- Shared platform contracts
    |       +---- Built-in platform implementations
    |       +---- Shared platform utilities
    |
    +---- live_playback
    |
    +---- live_interaction
    |
    +---- live_ui_kit
```

The `live_sites` package MUST NOT depend on `apps/pure_live`.

Dependencies on `live_playback`, `live_interaction`, or `live_ui_kit` MUST NOT be introduced merely to reuse a model or utility. Shared contracts SHOULD remain in the lowest appropriate package.

If a cross-package contract is required, place it in the package that owns that contract rather than introducing a circular dependency.

## 3. Directory Structure

```text
packages/live_sites/
├── ARCHITECTURE.md
├── README.md
├── CHANGELOG.md
├── analysis_options.yaml
├── pubspec.yaml
├── lib/
│   ├── live_sites.dart
│   └── src/
│       ├── core/
│       │   ├── live_site.dart
│       │   ├── live_site_manifest.dart
│       │   ├── live_site_context.dart
│       │   ├── live_site_runtime_info.dart
│       │   ├── live_site_registry.dart
│       │   └── live_site_exception.dart
│       │
│       ├── models/
│       │   ├── live_room.dart
│       │   ├── live_anchor.dart
│       │   ├── live_category.dart
│       │   ├── live_stream.dart
│       │   ├── live_search_result.dart
│       │   ├── live_page.dart
│       │   └── live_asset_ref.dart
│       │
│       ├── capabilities/
│       │   ├── live_site_capability.dart
│       │   ├── live_room_provider.dart
│       │   ├── live_anchor_provider.dart
│       │   ├── live_hot_provider.dart
│       │   ├── live_discovery_provider.dart
│       │   ├── live_category_provider.dart
│       │   ├── live_search_provider.dart
│       │   ├── live_web_search_provider.dart
│       │   ├── live_playback_provider.dart
│       │   ├── live_danmaku_provider.dart
│       │   └── live_link_resolver.dart
│       │
│       ├── shared/
│       │   ├── http/
│       │   ├── parsers/
│       │   ├── crypto/
│       │   ├── converters/
│       │   └── utils/
│       │
│       ├── platforms/
│       │   ├── bilibili/
│       │   │   ├── bilibili_site.dart
│       │   │   ├── bilibili_manifest.dart
│       │   │   ├── api/
│       │   │   ├── models/
│       │   │   ├── parsers/
│       │   │   ├── crypto/
│       │   │   └── capabilities/
│       │   │
│       │   ├── douyin/
│       │   ├── douyu/
│       │   ├── huya/
│       │   ├── cc/
│       │   └── other/
│       │
│       └── internal/
│           └── built_in_sites.dart
│
└── test/
    ├── core/
    ├── models/
    ├── shared/
    ├── contracts/
    └── platforms/
        ├── bilibili/
        ├── douyin/
        ├── douyu/
        └── cc/
```

This structure is a starting point, not a requirement to create empty files or directories. Add files when there is a concrete implementation need.

### 3.1 Directory Rules

- `core/` contains foundational interfaces, metadata, lifecycle, and registry contracts.
- `models/` contains shared domain models.
- `capabilities/` contains optional capability interfaces.
- `shared/` contains utilities with proven reuse across multiple platforms.
- `platforms/` contains every platform-specific implementation.
- `internal/` contains internal registration and construction helpers.
- `test/` mirrors the architecture and tests both shared contracts and platform implementations.

Platform-specific models MUST remain inside the corresponding platform directory unless they represent a genuinely shared domain concept.

## 4. Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Package | `snake_case` | `live_sites` |
| Directory | `snake_case` | `bilibili` |
| Dart file | `snake_case.dart` | `bilibili_site.dart` |
| Class | `UpperCamelCase` | `BilibiliSite` |
| Abstract interface | `UpperCamelCase` | `LivePlaybackProvider` |
| Enum | `UpperCamelCase` | `LiveSearchTarget` |
| Enum value | `lowerCamelCase` | `anchors` |
| Variable | `lowerCamelCase` | `roomId` |
| Constant | `lowerCamelCase` | `defaultPageSize` |
| Private member | `_lowerCamelCase` | `_client` |
| Test file | `<source>_test.dart` | `bilibili_site_test.dart` |

Use the platform's canonical name consistently. Do not create aliases that differ only in capitalization.

## 5. Core Interface

### 5.1 LiveSite

Every platform MUST expose one primary implementation of `LiveSite`.

```dart
abstract interface class LiveSite {
  LiveSiteManifest get manifest;

  LiveSiteRuntimeInfo get runtimeInfo;

  T? capability<T extends LiveSiteCapability>();

  Future<void> initialize(LiveSiteContext context);

  Future<void> dispose();
}
```

Responsibilities:

- `manifest` provides stable platform metadata.
- `runtimeInfo` provides current runtime status.
- `capability<T>()` retrieves a supported capability.
- `initialize()` initializes required resources.
- `dispose()` releases resources owned by the platform instance.

The platform instance MUST NOT initialize itself as a side effect of being constructed.

Initialization MUST be idempotent or explicitly reject invalid lifecycle transitions.

Disposal MUST be safe according to the documented lifecycle contract.

Do not add convenience methods for every platform feature directly to `LiveSite`. Feature APIs belong to capability interfaces.

### 5.2 LiveSiteCapability

```dart
abstract interface class LiveSiteCapability {}
```

Every optional platform capability MUST implement this marker interface.

A platform MUST expose only capabilities that it genuinely supports.

An unsupported capability MUST return `null`.

An empty result MUST NOT be used to represent an unsupported operation.

## 6. Platform Metadata

### 6.1 LiveSiteManifest

The manifest describes platform identity and relatively stable metadata.

```dart
class LiveSiteManifest {
  const LiveSiteManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.contractVersion,
    this.description = const {},
    this.aliases = const [],
    this.author,
    this.license,
    this.homepage,
    this.icon,
    this.assets = const {},
    this.supportedPlatforms = const {},
  });

  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final String version;
  final String contractVersion;
  final List<String> aliases;
  final String? author;
  final String? license;
  final Uri? homepage;
  final LiveAssetRef? icon;
  final Map<String, LiveAssetRef> assets;
  final Set<LiveTargetPlatform> supportedPlatforms;
}
```

The exact collection types may be changed to the project's preferred immutable model implementation.

Requirements:

- `id` MUST be stable, lowercase ASCII, and unique.
- `id` MUST NOT change because of a display-name change.
- `version` describes the platform implementation version.
- `contractVersion` describes compatibility with the public contract.
- `name` and `description` support localization.
- `aliases` support user input and legacy identifiers.
- `supportedPlatforms` describes declared compatibility, not guaranteed current availability.
- Authentication credentials MUST NOT be stored in the manifest.
- Runtime health, current login status, and temporary failures MUST NOT be treated as immutable metadata.

Suggested IDs include `bilibili`, `douyin`, `douyu`, `huya`, and `cc`.

### 6.2 Localized Text

Use BCP 47 language tags.

Examples:

- `zh-CN`
- `zh-TW`
- `en-US`
- `ja-JP`

The fallback order SHOULD be:

1. Exact locale match.
2. Language match.
3. Application default locale.
4. A documented fallback locale.
5. Stable platform ID.

Localization MUST NOT require each platform to implement its own translation engine.

## 7. Asset References

Platform icons and other assets MUST be represented as references rather than UI widgets.

```dart
enum LiveAssetType {
  bundled,
  remote,
  platformDefault,
}

class LiveAssetRef {
  const LiveAssetRef({
    required this.type,
    this.path,
    this.uri,
    this.fallback,
  });

  final LiveAssetType type;
  final String? path;
  final Uri? uri;
  final LiveAssetRef? fallback;
}
```

Rules:

- Bundled assets MUST use a documented package-relative path convention.
- Remote assets MUST use validated URLs.
- The UI layer decides how an asset is rendered.
- The domain layer MUST NOT depend on Flutter image widgets.
- Missing icons MUST have a deterministic fallback.
- Remote images MUST follow the application's network and cache policies.

Do not add separate asset types until the package has a concrete requirement for them.

## 8. Runtime Information and Lifecycle

Runtime information is distinct from manifest metadata.

```dart
enum LiveSiteStatus {
  uninitialized,
  initializing,
  ready,
  degraded,
  unavailable,
  disposed,
}

class LiveSiteRuntimeInfo {
  const LiveSiteRuntimeInfo({
    required this.status,
    this.message,
    this.lastCheckedAt,
  });

  final LiveSiteStatus status;
  final String? message;
  final DateTime? lastCheckedAt;
}
```

The exact state model may be expanded when required by real platform implementations.

Lifecycle rules:

1. Construction MUST NOT trigger network requests.
2. Initialization MUST establish the resources required by the platform.
3. A transient API failure MUST NOT automatically mark every capability as permanently unavailable.
4. Runtime status MUST NOT replace operation-level error handling.
5. Disposal MUST release owned subscriptions, clients, timers, and other resources.
6. The registry MUST NOT silently initialize the same instance multiple times.
7. The owner of a platform instance MUST be responsible for its lifecycle.

## 9. Optional Capability Interfaces

Different platforms provide different features. The architecture MUST NOT require all platforms to implement every capability.

### 9.1 Room Provider

```dart
abstract interface class LiveRoomProvider
    implements LiveSiteCapability {
  Future<LiveRoom> getRoom(String roomId);
}
```

### 9.2 Anchor Provider

```dart
abstract interface class LiveAnchorProvider
    implements LiveSiteCapability {
  Future<LiveAnchor> getAnchor(String anchorId);
}
```

### 9.3 Hot Provider

```dart
abstract interface class LiveHotProvider
    implements LiveSiteCapability {
  Future<LivePage<LiveRoom>> getHotRooms({
    LivePageRequest request = const LivePageRequest(),
  });
}
```

### 9.4 Discovery Provider

```dart
abstract interface class LiveDiscoveryProvider
    implements LiveSiteCapability {
  Future<LivePage<LiveRoom>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  });
}
```

### 9.5 Category Provider

```dart
abstract interface class LiveCategoryProvider
    implements LiveSiteCapability {
  Future<List<LiveCategory>> getCategories();

  Future<LivePage<LiveRoom>> getCategoryRooms({
    required String categoryId,
    LivePageRequest request = const LivePageRequest(),
  });
}
```

### 9.6 Capability Rules

- Hot lists, discovery feeds, and categories MUST remain separate concepts.
- A platform MAY implement any subset of these capabilities.
- A platform with no public hot-list API MUST NOT fabricate one.
- A platform with no category API MUST NOT return an empty list merely to satisfy an interface.
- If an operation is temporarily unavailable, return an appropriate error rather than claiming the capability does not exist.
- Shared models SHOULD be used where semantics genuinely match across platforms.
- Platform-specific response fields MUST remain available where they are important and cannot be represented safely by shared fields.

## 10. Search Architecture

Search is optional and may target different content types.

A platform MAY support room search, anchor search, both, or neither.

### 10.1 Search Target

```dart
enum LiveSearchTarget {
  rooms,
  anchors,
  categories,
}
```

Do not add `mixed` unless a real platform or UI flow requires mixed results with defined semantics.

### 10.2 Search Request

```dart
class LiveSearchRequest {
  const LiveSearchRequest({
    required this.query,
    required this.target,
    this.page = 1,
    this.pageSize = 20,
  });

  final String query;
  final LiveSearchTarget target;
  final int page;
  final int pageSize;
}
```

Validate blank queries and invalid pagination values at the appropriate API boundary.

### 10.3 Search Provider

```dart
abstract interface class LiveSearchProvider
    implements LiveSiteCapability {
  Set<LiveSearchTarget> get supportedTargets;

  Future<LivePage<LiveSearchResult>> search(
    LiveSearchRequest request,
  );
}
```

Rules:

- `supportedTargets` MUST accurately reflect implemented search types.
- A request for an unsupported target MUST fail with an explicit unsupported-operation error.
- Do not return a successful empty page for an unsupported search target.
- Search results MUST identify their content type.
- API search and HTML parsing MAY be implementation details of the platform.
- Pagination MUST follow the platform's actual API behavior.
- Do not pretend page-based pagination exists when the platform only exposes a cursor.

### 10.4 Search Results

Search results SHOULD use a discriminated model or another type-safe representation.

A result MUST NOT require an anchor object for room-only results or a room object for anchor-only results.

Preserve platform identifiers, canonical URLs, and useful source metadata.

## 11. WebView Search

Some platforms cannot provide every search feature through a public or practical API. Others require opening their native web search page.

WebView integration MUST remain optional and MUST NOT force `live_sites` to depend on a WebView widget.

```dart
abstract interface class LiveWebSearchProvider
    implements LiveSiteCapability {
  LiveWebSearchDescriptor createSearch(String query);
}

class LiveWebSearchDescriptor {
  const LiveWebSearchDescriptor({
    required this.uri,
    this.title,
  });

  final Uri uri;
  final String? title;
}
```

The application or WebView infrastructure package is responsible for opening and displaying the page.

Security requirements:

- Validate schemes and allowed hosts.
- Prefer HTTPS.
- Do not enable JavaScript bridges by default.
- Do not expose application secrets to web content.
- Apply the application's cookie and session isolation policies.
- Do not allow arbitrary URI schemes without explicit validation.

API search and WebView search are separate capabilities. A platform MAY implement either or both.

## 12. Shared Domain Models

### 12.1 LiveRoom

A shared room model SHOULD contain fields such as:

- Platform ID.
- Room ID.
- Title.
- Anchor ([LiveAnchor]), when the source names one — the streamer's identity,
  display name and avatar belong to that type rather than being duplicated as
  loose fields here.
- Cover image reference.
- Room URL.
- Live status, when known.
- Viewer count, when available.
- Category information, when available.
- Optional source-specific metadata.

### 12.2 LiveAnchor

A shared anchor model SHOULD contain:

- Platform ID.
- Anchor ID.
- Display name.
- Avatar reference.
- Profile URL.
- Optional description.
- Optional live status.
- Optional follower count.

### 12.3 LiveCategory

A shared category model SHOULD contain:

- Platform ID.
- Category ID.
- Localized or display name.
- Optional icon.
- Optional parent category ID.
- Optional ordering information.

### 12.4 Model Rules

- Platform IDs and entity IDs MUST remain separate.
- Room and anchor IDs MUST be treated as opaque strings.
- Never assume IDs from different platforms are globally unique.
- Optional fields MUST remain optional when the source does not provide them.
- Do not use fake zero values to represent missing data.
- Counts and status values MUST preserve the distinction between unknown and known zero.
- Platform-specific fields SHOULD remain in platform-specific models unless there is a clear cross-platform need.

## 13. Pagination

Pagination MUST represent the actual behavior of the source API.

A shared request model MAY support page-based, offset-based, cursor-based, and single-page requests.

```dart
class LivePageRequest {
  const LivePageRequest({
    this.page = 1,
    this.pageSize = 20,
    this.cursor,
  });

  final int page;
  final int pageSize;
  final String? cursor;
}
```

A shared result model SHOULD include:

- Items.
- Optional total count.
- Optional next cursor.
- Whether more data is available, when known.

Rules:

- An unknown total MUST remain unknown.
- Empty results and end-of-pagination MUST be distinguishable where the API permits.
- Do not infer an exact total from the current page size.
- Platform adapters MUST translate their source pagination into the shared contract without fabricating information.

## 14. Playback URL Resolution

`live_sites` resolves platform-specific playback information. It does not implement the playback engine or playback recovery policy.

```dart
abstract interface class LivePlaybackProvider
    implements LiveSiteCapability {
  Future<LiveStream> resolveStream({
    required String roomId,
    String? quality,
    String? lineId,
  });
}
```

`LiveStream` SHOULD represent the resolved source URL and relevant metadata, such as:

- Protocol or source type.
- Quality.
- Line identifier.
- Required request headers.
- Expiration time, when known.
- Audio-only availability, when known.
- Source-specific metadata required for playback.

Rules:

- Do not assume every platform uses HTTP Live Streaming.
- Do not assume every URL is permanent.
- Do not store short-lived playback URLs as permanent room metadata.
- Do not select or instantiate a playback engine in this package.
- Do not implement line fallback, retry schedules, or player recovery here.
- Playback engine capabilities belong to `live_playback`.
- Source headers and cookies MUST be handled according to the application's security policy.

## 15. Danmaku and Interaction

The platform adapter is responsible for translating platform-specific danmaku protocols into a shared event contract.

The `live_sites` package MAY define the protocol-facing interface if that contract is owned by this package. If a stable, shared event contract is already owned by `live_interaction`, depend on that contract rather than duplicating it.

A danmaku capability SHOULD define:

- Connection creation.
- Connection lifecycle.
- Authentication requirements.
- Event parsing.
- Heartbeat behavior.
- Reconnection behavior required by the platform protocol.
- Cleanup and cancellation.

The implementation MUST NOT own application widgets or player UI.

Protocol-level reconnect behavior MUST be distinguished from application-level playback recovery.

## 16. HTTP and Shared Utilities

Shared infrastructure MUST be introduced only when it solves a real cross-platform problem.

Possible shared components include:

- HTTP client configuration.
- Request and response helpers.
- Common pagination converters.
- Common timestamp parsers.
- URL validation.
- Reusable crypto primitives.
- Shared error conversion.

Rules:

1. Platform-specific headers MUST remain platform-specific.
2. Signing algorithms MUST NOT be generalized merely because two implementations look similar.
3. Shared utilities MUST have their own tests.
4. Shared utilities MUST NOT import platform implementations.
5. Platform-specific utilities MUST remain in their platform directory until cross-platform reuse is proven.
6. HTTP clients MUST have a clearly defined owner and lifecycle.
7. Cookie, authentication, and request-header behavior MUST be explicit.
8. Network timeouts and cancellation MUST be handled consistently.

Avoid creating a large abstraction for every HTTP operation. Introduce abstractions when they reduce real duplication or establish an important boundary.

## 17. Error Handling

Use a stable error contract.

Suggested error categories:

```dart
enum LiveSiteErrorCode {
  unsupportedOperation,
  invalidArgument,
  authenticationRequired,
  accessDenied,
  rateLimited,
  network,
  timeout,
  parse,
  contentUnavailable,
  platformUnavailable,
  cancelled,
  incompatibleVersion,
  internal,
}
```

A domain exception SHOULD preserve:

- Error code.
- Human-readable message.
- Optional platform identifier.
- Optional operation name.
- Optional underlying cause.
- Whether retry may be appropriate, when known.

Rules:

- Do not expose sensitive tokens, cookies, or signed URLs in error messages.
- Do not collapse every error into a generic network failure.
- Do not treat a successful empty response as an error.
- Do not treat an unsupported operation as an empty response.
- Do not blindly retry authentication, validation, or permission failures.
- Keep user-facing localization in the application layer.

## 18. Built-in Platform Registry

The registry is a simple in-process collection of built-in platform instances.

It is not a plugin manager, dynamic loader, or installer.

```dart
final class LiveSiteRegistry {
  LiveSiteRegistry(Iterable<LiveSite> sites) {
    for (final site in sites) {
      final id = site.manifest.id;

      if (_sites.containsKey(id)) {
        throw ArgumentError.value(
          id,
          'sites',
          'Duplicate live site ID.',
        );
      }

      _sites[id] = site;
    }
  }

  final Map<String, LiveSite> _sites = {};

  LiveSite? getById(String id) => _sites[id];

  List<LiveSite> get all => List.unmodifiable(_sites.values);
}
```

This example shows the basic registry boundary. Production code MUST additionally define how initialization failures, disposal, and ownership are handled.

The application composition root constructs the built-in implementations and supplies them to the registry.

Do not let the registry:

- Discover arbitrary Dart files at runtime.
- Load executable code from a network.
- Install or uninstall platforms.
- Manage plugin permissions.
- Own application navigation.
- Hide initialization errors.

## 19. Built-in Platform Registration

Use a single internal construction entry point.

```dart
List<LiveSite> createBuiltInLiveSites() {
  return [
    // Add implemented platform instances here.
  ];
}
```

Replace the placeholder with actual constructors when the corresponding implementations are available.

Do not add unimplemented platforms to the registry.

The public API MAY expose a factory if the application or tests need it, but implementation constructors and internal registration details SHOULD remain private unless external access is genuinely required.

## 20. Public API Design

The `lib/live_sites.dart` file is the package's public entry point.

```dart
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_exception.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';

export 'src/models/live_anchor.dart';
export 'src/models/live_category.dart';
export 'src/models/live_page.dart';
export 'src/models/live_room.dart';
export 'src/models/live_search_result.dart';
export 'src/models/live_stream.dart';

export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_category_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_web_search_provider.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_danmaku_provider.dart';
```

Only export symbols intended for consumers of the package.

Platform-private API clients, parsers, signing helpers, and internal implementation models MUST NOT be exported through the package entry point unless there is a documented reason.

Do not automatically export every file in `src/`.

## 21. Dart Formatting and Code Style

The package MUST use the workspace's shared formatting and analysis conventions.

### 21.1 Formatting

Use the Dart formatter rather than relying on editor-specific formatting behavior.

```powershell
dart format packages/live_sites
```

To check formatting without changing files:

```powershell
dart format --output=none --set-exit-if-changed packages/live_sites
```

### 21.2 Import Rules

- Use package imports for public package APIs.
- Use relative imports for private files within the same package when consistent with the workspace convention.
- Avoid importing another package's internal `src/` files.
- Remove unused imports.
- Do not reorder imports manually against the configured formatter or analyzer.
- Keep imports deterministic and compatible with the workspace's lint rules.

### 21.3 Type and Immutability Rules

- Declare explicit return types for public APIs.
- Prefer `final` for values that are not reassigned.
- Prefer immutable domain models.
- Avoid unnecessary `dynamic`.
- Avoid `print()` in production code.
- Handle subscriptions, streams, and disposable resources explicitly.
- Use `unawaited()` when intentionally starting a future without awaiting it.
- Do not introduce a new dependency for a trivial utility.
- Do not modify generated files manually.

### 21.4 Formatting Stability

The project MUST commit a consistent `.editorconfig`, analysis configuration, and formatter version policy where practical.

AI-generated changes MUST follow the same rules as handwritten code.

Do not disable a lint merely to silence a warning without documenting the reason.

## 22. English Documentation and Comment Rules

All source comments, API documentation, TODOs, and maintenance notes MUST be written in English.

User-facing display names and localized strings MAY use other languages.

### 22.1 Public API Documentation

Public declarations SHOULD include documentation describing their purpose and behavioral constraints.

```dart
/// Provides playback URL resolution for a live-streaming platform.
abstract interface class LivePlaybackProvider
    implements LiveSiteCapability {
  /// Resolves a playable stream for the specified room.
  ///
  /// Throws [LiveSiteException] when resolution fails.
  Future<LiveStream> resolveStream({
    required String roomId,
    String? quality,
    String? lineId,
  });
}
```

Document actual exceptions and guarantees. Do not claim an operation always succeeds if it depends on a remote service.

### 22.2 Comment Quality

Comments SHOULD explain:

- Why a non-obvious decision exists.
- Protocol-specific behavior.
- Compatibility constraints.
- Known source API limitations.
- Non-obvious lifecycle requirements.
- Workarounds that would otherwise appear unnecessary.

Comments SHOULD NOT merely repeat the code.

Avoid:

```dart
// Set room ID.
final roomId = response['room_id'];
```

Prefer:

```dart
// The source API returns room_id as a numeric value for some rooms.
final roomId = response['room_id'].toString();
```

Only use the latter explanation if the behavior is verified.

### 22.3 TODO Rules

TODO comments MUST identify actionable work and include context.

```dart
// TODO: Add cursor-based pagination when the source API exposes a stable cursor.
```

Do not leave vague comments such as `TODO: Fix this later`.

### 22.4 Preserve Existing Comments

When modifying existing files:

- Preserve accurate comments and documentation.
- Update comments when behavior changes.
- Remove comments only when they are obsolete or misleading.
- Avoid unrelated comment rewrites during targeted fixes.

## 23. Dependency Management

All platforms share the `live_sites` package dependency configuration.

Rules:

- Add a dependency only when the package needs it.
- Prefer workspace-managed versions for shared dependencies.
- Do not introduce separate pubspec files for individual platforms.
- Avoid circular dependencies between packages.
- Do not depend on application-only packages.
- Keep Flutter dependencies out of pure Dart components when they are unnecessary.
- Test platform-specific dependencies against the supported target platforms.
- Verify that crypto, HTTP, and parsing dependencies work on the intended desktop and mobile targets.

## 24. Testing Strategy

### 24.1 Contract Tests

Every platform implementation MUST be tested against applicable shared contracts.

Test:

- Stable manifest ID.
- Capability availability.
- Unsupported operation behavior.
- Initialization and disposal.
- Correct pagination semantics.
- Error mapping.
- Empty results.
- Missing optional fields.
- ID preservation.
- Localization fallback.

### 24.2 Platform Unit Tests

Test:

- Request construction.
- Response parsing.
- Signing and encoding.
- URL resolution.
- Search result conversion.
- Pagination conversion.
- Error response handling.
- Missing or malformed response fields.

Use fixtures for deterministic parsing tests.

### 24.3 Network Tests

Live network tests MUST NOT be required for every normal unit-test run.

Prefer mock HTTP clients and recorded fixtures.

Integration tests MAY contact actual services in a separately controlled environment. They MUST account for authentication, rate limits, network instability, and changes to third-party APIs.

### 24.4 Suggested Commands

Run from the workspace root:

```powershell
dart format --output=none --set-exit-if-changed packages/live_sites
dart analyze packages/live_sites
dart test packages/live_sites
```

Use the workspace's actual test runner. If `live_sites` is a Flutter package or its tests depend on Flutter, use the corresponding Flutter test command.

## 25. Compatibility and Versioning

Public contracts MUST evolve deliberately.

- Add optional capabilities without requiring all existing platforms to implement them.
- Prefer additive changes when possible.
- Treat removal or incompatible changes to public interfaces as breaking changes.
- Update contract tests whenever a public contract changes.
- Keep implementation versioning separate from the shared contract version.
- Document migrations for breaking changes.
- Do not introduce abstractions for hypothetical future requirements without a concrete use case.

## 26. Implementation Plan

### Phase 1: Establish the Foundation

1. Create the package's public entry point.
2. Define the `LiveSite` contract.
3. Define metadata and runtime information.
4. Define common domain models.
5. Define error and pagination contracts.
6. Establish lint, formatting, and testing rules.

### Phase 2: Migrate One Representative Platform

1. Choose a platform with enough real functionality to exercise the architecture.
2. Migrate its HTTP/API layer.
3. Migrate its parsers and platform-specific models.
4. Implement only its supported capabilities.
5. Add fixture-based tests.
6. Validate the contract before migrating additional platforms.

### Phase 3: Migrate Remaining Platforms

1. Move each implementation into `platforms/<platform_id>/`.
2. Preserve verified platform-specific behavior.
3. Extract shared utilities only after confirming reuse.
4. Test each implementation independently.
5. Register only implemented platforms.

### Phase 4: Stabilize

1. Remove obsolete duplicate interfaces.
2. Check package dependency boundaries.
3. Verify platform support.
4. Run formatting, analysis, and tests.
5. Review error handling and resource disposal.
6. Document remaining unsupported capabilities.

## 27. Pull Request Checklist

Before merging a change, verify:

- [ ] All platform code remains inside `live_sites`.
- [ ] No separate package was created for an individual platform.
- [ ] No plugin system or dynamic code loader was introduced.
- [ ] Platform-specific logic remains isolated.
- [ ] Optional capabilities accurately represent supported features.
- [ ] Unsupported operations do not return fabricated empty results.
- [ ] Shared models do not depend on UI or playback engine implementations.
- [ ] IDs and optional fields are handled correctly.
- [ ] Error messages do not expose secrets.
- [ ] Resources are released correctly.
- [ ] Tests cover changed behavior.
- [ ] Formatting and analysis pass.
- [ ] All source comments and API documentation are in English.
- [ ] Public exports contain only intended public APIs.

## 28. Final Architecture Decisions

The following decisions define the package boundary:

1. `live_sites` is one internal workspace package.
2. All built-in live-streaming platform implementations reside in `lib/src/platforms/`.
3. There are no per-platform packages.
4. There is no dynamic plugin system.
5. The public `LiveSite` interface provides stable platform identity and lifecycle.
6. Optional capability interfaces represent real, independently supported features.
7. Shared domain models are platform-neutral.
8. Platform-specific APIs, parsers, signing algorithms, and protocol logic remain isolated.
9. Playback engine management, application UI, and application state remain outside the package.
10. Formatting, linting, testing, and English documentation rules apply uniformly to all implementations.

**Architecture principle:** One package, one public contract, isolated platform implementations, and optional capabilities based on actual support.


```text
packages/live_sites/lib/
├── live_sites.dart
└── src/
    ├── core/
    │   ├── live_site.dart
    │   ├── live_site_context.dart
    │   ├── live_site_exception.dart
    │   ├── live_site_manifest.dart
    │   └── live_site_runtime_info.dart
    ├── models/
    │   ├── live_anchor.dart
    │   ├── live_asset_ref.dart
    │   ├── live_category.dart
    │   ├── live_danmaku_event.dart
    │   ├── live_page.dart
    │   ├── live_room.dart
    │   ├── live_search_result.dart
    │   └── live_stream.dart
    └── capabilities/
        ├── live_site_capability.dart
        ├── live_room_provider.dart
        ├── live_anchor_provider.dart
        ├── live_hot_provider.dart
        ├── live_discovery_provider.dart
        ├── live_category_provider.dart
        ├── live_search_provider.dart
        ├── live_web_search_provider.dart
        ├── live_playback_provider.dart
        ├── live_danmaku_provider.dart
        └── live_link_resolver.dart
```

## 1. Public entry point

**File: `lib/live_sites.dart`**

```dart
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_exception.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_runtime_info.dart';

export 'src/models/live_anchor.dart';
export 'src/models/live_asset_ref.dart';
export 'src/models/live_category.dart';
export 'src/models/live_danmaku_event.dart';
export 'src/models/live_page.dart';
export 'src/models/live_room.dart';
export 'src/models/live_search_result.dart';
export 'src/models/live_stream.dart';

export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_category_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_web_search_provider.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_danmaku_provider.dart';
export 'src/capabilities/live_link_resolver.dart';
```

## 2. Core contracts

**File: `lib/src/core/live_site_context.dart`**

```dart
enum LiveTargetPlatform {
  android,
  ios,
  androidTv,
  windows,
  macos,
  linux,
}

class LiveSiteContext {
  const LiveSiteContext({
    required this.platform,
    required this.locale,
    required this.defaultLocale,
    this.applicationVersion,
    this.configuration = const {},
  });

  final LiveTargetPlatform platform;
  final String locale;
  final String defaultLocale;
  final String? applicationVersion;
  final Map<String, Object?> configuration;
}
```

**File: `lib/src/core/live_site_manifest.dart`**

```dart
import '../models/live_asset_ref.dart';
import 'live_site_context.dart';

class LiveSiteManifest {
  const LiveSiteManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.contractVersion,
    this.description = const {},
    this.aliases = const [],
    this.author,
    this.license,
    this.homepage,
    this.icon,
    this.assets = const {},
    this.supportedPlatforms = const {},
  });

  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final String version;
  final String contractVersion;
  final List<String> aliases;
  final String? author;
  final String? license;
  final Uri? homepage;
  final LiveAssetRef? icon;
  final Map<String, LiveAssetRef> assets;
  final Set<LiveTargetPlatform> supportedPlatforms;

  String localizedName(String locale, String fallbackLocale) {
    return _resolveLocalizedText(name, locale, fallbackLocale) ?? id;
  }

  String? localizedDescription(String locale, String fallbackLocale) {
    return _resolveLocalizedText(description, locale, fallbackLocale);
  }

  String? _resolveLocalizedText(
    Map<String, String> values,
    String locale,
    String fallbackLocale,
  ) {
    final normalizedLocale = locale.replaceAll('_', '-');
    final normalizedFallback = fallbackLocale.replaceAll('_', '-');

    final exact = _findLocale(values, normalizedLocale);
    if (exact != null) return exact;

    final language = normalizedLocale.split('-').first;
    final languageMatch = _findLocale(values, language);
    if (languageMatch != null) return languageMatch;

    final fallbackExact = _findLocale(values, normalizedFallback);
    if (fallbackExact != null) return fallbackExact;

    final fallbackLanguage = normalizedFallback.split('-').first;
    return _findLocale(values, fallbackLanguage);
  }

  String? _findLocale(Map<String, String> values, String locale) {
    for (final entry in values.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() ==
          locale.toLowerCase()) {
        return entry.value;
      }
    }

    return null;
  }
}
```

**File: `lib/src/core/live_site_runtime_info.dart`**

```dart
enum LiveSiteStatus {
  uninitialized,
  initializing,
  ready,
  degraded,
  unavailable,
  disposed,
}

class LiveSiteRuntimeInfo {
  const LiveSiteRuntimeInfo({
    required this.status,
    this.message,
    this.lastCheckedAt,
  });

  final LiveSiteStatus status;
  final String? message;
  final DateTime? lastCheckedAt;
}
```

**File: `lib/src/core/live_site_exception.dart`**

```dart
enum LiveSiteErrorCode {
  unsupportedOperation,
  invalidArgument,
  authenticationRequired,
  accessDenied,
  rateLimited,
  network,
  timeout,
  parse,
  contentUnavailable,
  platformUnavailable,
  cancelled,
  incompatibleVersion,
  internal,
}

class LiveSiteException implements Exception {
  const LiveSiteException({
    required this.code,
    required this.message,
    this.siteId,
    this.operation,
    this.cause,
    this.retryable = false,
  });

  final LiveSiteErrorCode code;
  final String message;
  final String? siteId;
  final String? operation;
  final Object? cause;
  final bool retryable;

  @override
  String toString() {
    final site = siteId == null ? '' : ' [$siteId]';
    final action = operation == null ? '' : ' $operation';

    return 'LiveSiteException$site$action: '
        '${code.name}: $message';
  }
}
```

**File: `lib/src/core/live_site.dart`**

```dart
import '../capabilities/live_site_capability.dart';
import 'live_site_context.dart';
import 'live_site_manifest.dart';
import 'live_site_runtime_info.dart';

abstract interface class LiveSite {
  LiveSiteManifest get manifest;

  LiveSiteRuntimeInfo get runtimeInfo;

  T? capability<T extends LiveSiteCapability>();

  Future<void> initialize(LiveSiteContext context);

  Future<void> dispose();
}
```

## 3. Shared models

**File: `lib/src/models/live_asset_ref.dart`**

```dart
enum LiveAssetType {
  bundled,
  remote,
  platformDefault,
}

class LiveAssetRef {
  const LiveAssetRef({
    required this.type,
    this.path,
    this.uri,
    this.fallback,
  });

  final LiveAssetType type;
  final String? path;
  final Uri? uri;
  final LiveAssetRef? fallback;
}
```

**File: `lib/src/models/live_room.dart`**

```dart
class LiveRoom {
  const LiveRoom({
    required this.siteId,
    required this.id,
    required this.title,
    this.anchorId,
    this.anchorName,
    this.cover,
    this.uri,
    this.isLive,
    this.viewerCount,
    this.categoryId,
    this.categoryName,
    this.metadata = const {},
  });

  final String siteId;
  final String id;
  final String title;

  final String? anchorId;
  final String? anchorName;

  final Uri? cover;
  final Uri? uri;

  final bool? isLive;
  final int? viewerCount;

  final String? categoryId;
  final String? categoryName;

  final Map<String, Object?> metadata;
}
```

**File: `lib/src/models/live_anchor.dart`**

```dart
class LiveAnchor {
  const LiveAnchor({
    required this.siteId,
    required this.id,
    required this.name,
    this.avatar,
    this.uri,
    this.description,
    this.isLive,
    this.followerCount,
    this.metadata = const {},
  });

  final String siteId;
  final String id;
  final String name;

  final Uri? avatar;
  final Uri? uri;
  final String? description;

  final bool? isLive;
  final int? followerCount;

  final Map<String, Object?> metadata;
}
```

**File: `lib/src/models/live_category.dart`**

```dart
class LiveCategory {
  const LiveCategory({
    required this.siteId,
    required this.id,
    required this.name,
    this.icon,
    this.parentId,
    this.sortOrder,
    this.metadata = const {},
  });

  final String siteId;
  final String id;
  final String name;

  final Uri? icon;
  final String? parentId;
  final int? sortOrder;

  final Map<String, Object?> metadata;
}
```

**File: `lib/src/models/live_page.dart`**

```dart
class LivePageRequest {
  const LivePageRequest({
    this.page = 1,
    this.pageSize = 20,
    this.offset,
    this.cursor,
  });

  final int page;
  final int pageSize;
  final int? offset;
  final String? cursor;
}

class LivePage<T> {
  const LivePage({
    required this.items,
    this.totalCount,
    this.nextCursor,
    this.hasMore,
  });

  final List<T> items;
  final int? totalCount;
  final String? nextCursor;
  final bool? hasMore;
}
```

**File: `lib/src/models/live_search_result.dart`**

```dart
import 'live_anchor.dart';
import 'live_category.dart';
import 'live_room.dart';

enum LiveSearchTarget {
  rooms,
  anchors,
  categories,
}

class LiveSearchRequest {
  const LiveSearchRequest({
    required this.query,
    required this.target,
    this.page = 1,
    this.pageSize = 20,
  });

  final String query;
  final LiveSearchTarget target;
  final int page;
  final int pageSize;
}

class LiveSearchResult {
  const LiveSearchResult._({
    required this.target,
    this.room,
    this.anchor,
    this.category,
  });

  factory LiveSearchResult.room(LiveRoom room) {
    return LiveSearchResult._(
      target: LiveSearchTarget.rooms,
      room: room,
    );
  }

  factory LiveSearchResult.anchor(LiveAnchor anchor) {
    return LiveSearchResult._(
      target: LiveSearchTarget.anchors,
      anchor: anchor,
    );
  }

  factory LiveSearchResult.category(LiveCategory category) {
    return LiveSearchResult._(
      target: LiveSearchTarget.categories,
      category: category,
    );
  }

  final LiveSearchTarget target;
  final LiveRoom? room;
  final LiveAnchor? anchor;
  final LiveCategory? category;
}
```

**File: `lib/src/models/live_stream.dart`**

```dart
enum LiveStreamProtocol {
  hls,
  httpFlv,
  dash,
  rtmp,
  webrtc,
  http,
  unknown,
}

class LiveStream {
  const LiveStream({
    required this.uri,
    this.protocol = LiveStreamProtocol.unknown,
    this.quality,
    this.lineId,
    this.headers = const {},
    this.expiresAt,
    this.audioOnlyAvailable,
    this.metadata = const {},
  });

  final Uri uri;
  final LiveStreamProtocol protocol;
  final String? quality;
  final String? lineId;
  final Map<String, String> headers;
  final DateTime? expiresAt;
  final bool? audioOnlyAvailable;
  final Map<String, Object?> metadata;
}
```

**File: `lib/src/models/live_danmaku_event.dart`**

```dart
enum LiveDanmakuEventType {
  message,
  gift,
  like,
  member,
  roomStatus,
  unknown,
}

class LiveDanmakuEvent {
  const LiveDanmakuEvent({
    required this.siteId,
    required this.roomId,
    required this.type,
    required this.receivedAt,
    this.userId,
    this.userName,
    this.text,
    this.value,
    this.metadata = const {},
  });

  final String siteId;
  final String roomId;
  final LiveDanmakuEventType type;
  final DateTime receivedAt;

  final String? userId;
  final String? userName;
  final String? text;
  final num? value;

  final Map<String, Object?> metadata;
}
```

## 4. Capability interfaces

**File: `lib/src/capabilities/live_site_capability.dart`**

```dart
abstract interface class LiveSiteCapability {}
```

**File: `lib/src/capabilities/live_room_provider.dart`**

```dart
import '../models/live_room.dart';
import 'live_site_capability.dart';

abstract interface class LiveRoomProvider
    implements LiveSiteCapability {
  Future<LiveRoom> getRoom(String roomId);
}
```

**File: `lib/src/capabilities/live_anchor_provider.dart`**

```dart
import '../models/live_anchor.dart';
import 'live_site_capability.dart';

abstract interface class LiveAnchorProvider
    implements LiveSiteCapability {
  Future<LiveAnchor> getAnchor(String anchorId);
}
```

**File: `lib/src/capabilities/live_hot_provider.dart`**

```dart
import '../models/live_page.dart';
import '../models/live_room.dart';
import 'live_site_capability.dart';

abstract interface class LiveHotProvider
    implements LiveSiteCapability {
  Future<LivePage<LiveRoom>> getHotRooms({
    LivePageRequest request = const LivePageRequest(),
  });
}
```

**File: `lib/src/capabilities/live_discovery_provider.dart`**

```dart
import '../models/live_page.dart';
import '../models/live_room.dart';
import 'live_site_capability.dart';

abstract interface class LiveDiscoveryProvider
    implements LiveSiteCapability {
  Future<LivePage<LiveRoom>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  });
}
```

**File: `lib/src/capabilities/live_category_provider.dart`**

```dart
import '../models/live_category.dart';
import '../models/live_page.dart';
import '../models/live_room.dart';
import 'live_site_capability.dart';

abstract interface class LiveCategoryProvider
    implements LiveSiteCapability {
  Future<List<LiveCategory>> getCategories();

  Future<LivePage<LiveRoom>> getCategoryRooms({
    required String categoryId,
    LivePageRequest request = const LivePageRequest(),
  });
}
```

**File: `lib/src/capabilities/live_search_provider.dart`**

```dart
import '../models/live_page.dart';
import '../models/live_search_result.dart';
import 'live_site_capability.dart';

abstract interface class LiveSearchProvider
    implements LiveSiteCapability {
  Set<LiveSearchTarget> get supportedTargets;

  Future<LivePage<LiveSearchResult>> search(
    LiveSearchRequest request,
  );
}
```

**File: `lib/src/capabilities/live_web_search_provider.dart`**

```dart
import 'live_site_capability.dart';

abstract interface class LiveWebSearchProvider
    implements LiveSiteCapability {
  LiveWebSearchDescriptor createSearch(String query);
}

class LiveWebSearchDescriptor {
  const LiveWebSearchDescriptor({
    required this.uri,
    this.title,
  });

  final Uri uri;
  final String? title;
}
```

**File: `lib/src/capabilities/live_playback_provider.dart`**

```dart
import '../models/live_stream.dart';
import 'live_site_capability.dart';

abstract interface class LivePlaybackProvider
    implements LiveSiteCapability {
  Future<LiveStream> resolveStream({
    required String roomId,
    String? quality,
    String? lineId,
  });
}
```

**File: `lib/src/capabilities/live_danmaku_provider.dart`**

```dart
import 'dart:async';

import '../models/live_danmaku_event.dart';
import 'live_site_capability.dart';

abstract interface class LiveDanmakuProvider
    implements LiveSiteCapability {
  Future<LiveDanmakuSession> createSession({
    required String roomId,
  });
}

abstract interface class LiveDanmakuSession {
  Stream<LiveDanmakuEvent> get events;

  Future<void> connect();

  Future<void> disconnect();

  Future<void> dispose();
}
```

**File: `lib/src/capabilities/live_link_resolver.dart`**

```dart
import 'live_site_capability.dart';

abstract interface class LiveLinkResolver
    implements LiveSiteCapability {
  Future<Uri> resolve(Uri uri);
}
```

## 5. Validation commands

Run these commands from the workspace root:

```powershell
dart format packages/live_sites
dart analyze packages/live_sites
dart test packages/live_sites
```

Before integrating this contract layer, verify that the package's SDK constraints support the Dart language features in use. Also add tests for manifest ID validation, search-result consistency, pagination arguments, capability lookup, and lifecycle ownership before considering the API production-ready.
我建议在 PureLive 的 live_sites 中引入 fpdart: ^1.2.0，但不要把整个项目改造成纯函数式架构。最合适的做法是：在业务边界使用 Either 显式表达可预期的失败，在内部保留正常的 Dart async/await，并将意外异常与业务错误区分开。
对于直播平台适配，这样可以让调用方明确知道：直播间不存在、解析失败、平台暂时不可用、播放地址获取失败等情况，而不必到处用 try/catch 判断业务错误。
1. 建议采用的错误处理规范
场景	推荐处理方式
房间不存在、源不存在	Either<LiveSiteError, T>
平台不支持某项能力	返回明确的 unsupported 错误，或在能力发现阶段判断是否支持
HTTP 请求失败、限流、登录失效	转换成对应的业务错误
直播地址解析失败	返回 Left，包含平台、阶段及原因
缓存未命中等正常空值	根据语义使用 Option<T> 或 T?
取消、程序缺陷等意外情况	不要一概伪装成业务错误；在明确的边界捕获并记录
关键原则： Either 并不会自动捕获异常。调用 repository、HTTP 客户端或解析器时，如果底层仍然抛异常，就需要显式转换，或者使用 TaskEither 统一封装异步操作。
2. 添加 fpdart 依赖
在 packages/live_sites/pubspec.yaml 中添加：
dependencies:
  fpdart: ^1.2.0


建议只在 live_sites 的公共 API 和实现边界使用 Either，不要让每个内部辅助函数都返回 Either。例如，纯字符串转换、JSON 字段读取等不涉及业务失败的函数，仍然可以返回普通类型。
3. 定义统一的业务错误模型
新增文件：packages/live_sites/lib/src/core/live_site_error.dart

/// Represents an expected or normalized failure in a live site operation.
sealed class LiveSiteError {
  const LiveSiteError({
    required this.siteId,
    required this.message,
    this.cause,
  });

  /// The identifier of the site where the failure occurred.
  final String siteId;

  /// A human-readable diagnostic message.
  final String message;

  /// The original error, when available.
  final Object? cause;
}

/// Indicates that the requested room, anchor, or source does not exist.
final class LiveSiteNotFound extends LiveSiteError {
  const LiveSiteNotFound({
    required super.siteId,
    required super.message,
  });
}

/// Indicates that the requested operation is not supported by the site.
final class LiveSiteUnsupported extends LiveSiteError {
  const LiveSiteUnsupported({
    required super.siteId,
    required super.message,
  });
}

/// Indicates that the operation failed because of a network issue.
final class LiveSiteNetworkError extends LiveSiteError {
  const LiveSiteNetworkError({
    required super.siteId,
    required super.message,
    super.cause,
  });
}

/// Indicates that the response could not be parsed or validated.
final class LiveSiteParseError extends LiveSiteError {
  const LiveSiteParseError({
    required super.siteId,
    required super.message,
    super.cause,
  });
}

/// Indicates that the site requires authentication or authorization.
final class LiveSiteAuthenticationError extends LiveSiteError {
  const LiveSiteAuthenticationError({
    required super.siteId,
    required super.message,
  });
}

/// Indicates that the platform rejected the request due to rate limiting.
final class LiveSiteRateLimitError extends LiveSiteError {
  const LiveSiteRateLimitError({
    required super.siteId,
    required super.message,
  });
}

/// Indicates an unexpected failure that was normalized at an API boundary.
final class LiveSiteUnexpectedError extends LiveSiteError {
  const LiveSiteUnexpectedError({
    required super.siteId,
    required super.message,
    super.cause,
  });
}



这里采用 sealed class，使错误类型在 Dart 3 中具备可枚举的继承层级。调用方可以使用 switch 判断错误类型，也可以在 UI 层统一转换成提示文本。
注意：cause 用于诊断，不建议直接把原始异常内容展示给最终用户。
4. 为异步边界提供统一转换方法
新增文件：packages/live_sites/lib/src/shared/async/live_site_either.dart

import 'package:fpdart/fpdart.dart';

import '../../core/live_site_error.dart';

/// Executes an operation and converts unexpected exceptions into typed errors.
///
/// Expected business failures should be returned explicitly by the operation.
/// This helper is intended for normalizing exceptions from external boundaries.
Future<Either<LiveSiteError, T>> captureLiveSite<T>({
  required String siteId,
  required String operation,
  required Future<T> Function() action,
}) async {
  try {
    final value = await action();
    return right(value);
  } catch (error) {
    return left(
      LiveSiteUnexpectedError(
        siteId: siteId,
        message: 'Unexpected failure during $operation.',
        cause: error,
      ),
    );
  }
}



这个辅助方法是兜底，不是所有错误的统一归类器。比如 HTTP 客户端明确抛出超时异常时，最好在网络层转换成 LiveSiteNetworkError；JSON 格式错误则应该转换成 LiveSiteParseError，而不是全部变成 LiveSiteUnexpectedError。
如果项目已经有 LiveSiteException，可以暂时保留，让 HTTP 层和旧平台适配器逐步迁移，不需要一次性重写所有代码。
5. 修改能力接口：把业务失败写进方法签名
保留原来的 LiveSite、LiveSiteManifest 和能力发现机制，不需要改成插件系统。只需将可能出现业务失败的异步接口逐步改为 Future<Either<LiveSiteError, T>>。
例如，房间能力：

import 'package:fpdart/fpdart.dart';

import '../core/live_site_error.dart';
import '../models/live_room.dart';
import '../models/live_page.dart';
import '../models/live_page_request.dart';

/// Provides room-related operations supported by a live site.
abstract interface class LiveRoomCapability {
  /// Fetches a room by its platform-specific identifier.
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId);

  /// Fetches a page of rooms when the site supports room listing.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(
    LivePageRequest request,
  );
}



主播能力可以采用相同规则：

import 'package:fpdart/fpdart.dart';

import '../core/live_site_error.dart';
import '../models/live_anchor.dart';

/// Provides anchor-related operations supported by a live site.
abstract interface class LiveAnchorCapability {
  /// Fetches an anchor by its platform-specific identifier.
  Future<Either<LiveSiteError, LiveAnchor>> getAnchor(String anchorId);
}



播放地址解析也应该显式返回错误：

import 'package:fpdart/fpdart.dart';

import '../core/live_site_error.dart';
import '../models/live_stream.dart';

/// Resolves playable streams for a live room.
abstract interface class LivePlaybackCapability {
  /// Resolves available streams for the specified room.
  Future<Either<LiveSiteError, List<LiveStream>>> resolveStreams(
    String roomId,
  );
}



如果你已有这些模型，只需要调整导入路径，不要为了套用示例而重复创建模型文件。
哪些方法需要修改？
接口类型	建议返回值
获取房间、主播详情	Future<Either<LiveSiteError, T>>
搜索、热门列表、分类列表	Future<Either<LiveSiteError, LivePage<T>>>
解析播放地址	Future<Either<LiveSiteError, List<LiveStream>>>
连接弹幕服务	可使用 Either 表示启动失败；连接后的事件通过 Stream 传递
查询可选能力	继续使用 capability<T>()，不存在时返回 null
纯数据转换、格式化	保持普通返回值
普通缓存读取	按实际语义使用 Option<T>、T? 或 Either
LivePage<T> 可以正常包含空列表：请求成功但没有结果是 Right，请求失败才是 Left。 不要把网络错误伪装成空列表。
6. 平台适配器中如何使用
以一个直播平台的房间查询为例。不要把 repository.findById() 返回 null 时转换成异常，而是直接返回有类型的业务错误。

import 'package:fpdart/fpdart.dart';

import '../../../core/live_site_error.dart';
import '../../../models/live_room.dart';

final class ExampleRoomRepository {
  Future<LiveRoom?> findById(String roomId) async {
    // Replace this example with the real platform request.
    return null;
  }
}

final class ExampleRoomAdapter {
  ExampleRoomAdapter({
    required this.siteId,
    required this.repository,
  });

  final String siteId;
  final ExampleRoomRepository repository;

  Future<Either<LiveSiteError, LiveRoom>> getRoom(
    String roomId,
  ) async {
    try {
      final room = await repository.findById(roomId);

      if (room == null) {
        return left(
          LiveSiteNotFound(
            siteId: siteId,
            message: 'Room $roomId was not found.',
          ),
        );
      }

      return right(room);
    } catch (error) {
      return left(
        LiveSiteUnexpectedError(
          siteId: siteId,
          message: 'Failed to fetch room $roomId.',
          cause: error,
        ),
      );
    }
  }
}



这里保留 try/catch 是有意的：Either 显式表达结果，但不能阻止仓库或底层 HTTP 客户端抛出异常。真实项目中，可以将重复的异常映射收敛到网络层或 captureLiveSite 一类的辅助方法中。
更进一步，建议让网络层直接返回已分类的错误，平台适配器只负责将平台特有响应转换为统一模型，避免每个平台重复编写相同的异常处理逻辑。
7. 调用方不再依赖 try/catch 判断业务结果
例如，live_playback 调用 live_sites 获取播放地址时：

import 'package:fpdart/fpdart.dart';

Future<void> openRoom(
  LivePlaybackCapability capability,
  String roomId,
) async {
  final result = await capability.resolveStreams(roomId);

  result.match(
    (error) {
      switch (error) {
        case LiveSiteNotFound():
          // The room no longer exists.
          break;
        case LiveSiteNetworkError():
          // Offer retry or try another line.
          break;
        case LiveSiteParseError():
          // Report a source parsing failure.
          break;
        case LiveSiteAuthenticationError():
          // Ask the user to refresh authentication.
          break;
        case LiveSiteRateLimitError():
          // Back off before retrying.
          break;
        case LiveSiteUnsupported():
          // The site does not support this operation.
          break;
        case LiveSiteUnexpectedError():
          // Log the unexpected failure.
          break;
      }
    },
    (streams) {
      if (streams.isEmpty) {
        // The request succeeded, but no playable streams were returned.
        return;
      }

      // Pass streams to the playback layer.
      // Do not initialize a player inside live_sites.
    },
  );
}



这段示例假设所有错误子类都在 LiveSiteError 的 sealed 层级中，并且已导入相应错误类型。实际项目中，播放控制器应该负责重试、切换线路、切换内核等恢复策略，live_sites 只负责报告结果。
8. 统一导出公共错误类型
在 packages/live_sites/lib/live_sites.dart 中增加：
export 'src/core/live_site_error.dart';


fpdart 可以由 live_sites 的公共能力接口间接使用，因此不必为了每个调用方都使用 Either，就把 fpdart 的所有类型重新导出。调用方若需要操作 Either，自行依赖 fpdart 即可。
9. 推荐的最终分层
Platform Adapter
解析平台响应、识别业务错误

Either<LiveSiteError, T>

live_sites · Shared Network / Parser
HTTP、超时、响应校验、错误归一化


live_playback
线路回退、重试、内核切换


应用层
提示、登录引导、错误展示




10. 迁移顺序
1. 添加 fpdart: ^1.2.0，创建统一的 LiveSiteError 错误模型。
2. 优先修改房间详情、播放地址解析、搜索等高失败概率的公共接口。
3. 在网络层统一转换超时、HTTP 状态码、认证失效和限流错误。
4. 逐个平台适配器迁移，不要求一次性重写全部代码。
5. 更新测试，分别覆盖 Right 成功、Left 业务失败、底层异常以及空结果。
运行：
dart format packages/live_sites
dart analyze packages/live_sites
dart test packages/live_sites


我的最终建议： Either 应该成为 live_sites 公共业务操作的标准结果类型，而不是所有 Dart 函数的强制返回类型。配合统一错误模型和网络层错误转换，才能真正减少重复的 try/catch，同时保持 PureLive 各个 package 之间清晰的职责边界。
