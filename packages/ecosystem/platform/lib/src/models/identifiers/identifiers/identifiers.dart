// Module: lib/src/models/identifiers.dart
// Purpose: The identifier typedefs every platform model uses, so an id is a named concept rather than a bare String.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 3. Ids must be stable, as deterministic as the
// protocol allows, unique inside their namespace and serializable. They are strings on purpose: a
// value that can be stored, logged and compared across isolates without a codec of its own.

typedef ExtensionId = String;
typedef RuntimeId = String;
typedef SourceId = String;
typedef RepositoryId = String;
typedef ProviderId = String;
typedef ResolverId = String;
typedef ContentId = String;
typedef IdentityId = String;
typedef TaskId = String;
typedef TraceId = String;
typedef DiagnosticId = String;
typedef AccountId = String;
typedef PermissionId = String;

/// Metadata keys owned by the platform itself.
///
/// docs/contracts/platform-models.md section 16 requires every other writer to namespace its own
/// metadata keys, so `tvbox.quality` can never collide with a platform key.
abstract final class PlatformMetadataKeys {
  static const String sourceKind = 'platform.source_kind';
  static const String repositoryKind = 'platform.repository_kind';
  static const String extensionProtocol = 'platform.extension_protocol';
  static const String cachedAt = 'platform.cached_at';
  static const String dataFreshness = 'platform.data_freshness';
}
