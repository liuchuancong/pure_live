// Module: lib/src/models/error/platform_error_info.dart
// Purpose: Serializable error representation and the standard error codes shared by every platform model.
// Author: liuchuancong
// Created: 2026-10-08
//
import '../../support/json.dart';

// Spec: docs/contracts/platform-models.md section 14. Runtime throwables live with the subsystem that
// raises them; this type is the transportable form used by statuses, diagnostics and persistence.

/// The subsystem an error belongs to. Values serialize as their own name.
enum PlatformErrorCategory {
  extension,
  source,
  repository,
  provider,
  identity,
  resolver,
  network,
  permission,
  auth,
  task,
  media,
  storage,
  configuration,
  timeout,
  cancellation,
  unknown,
}

/// Standard codes from docs/contracts/platform-models.md section 14.
///
/// Plugin and external-runtime codes must carry their own namespace, for example
/// `tvbox.parse_failed`; they are not part of this table.
abstract final class PlatformErrorCodes {
  static const String extensionNotFound = 'extension.not_found';
  static const String extensionIncompatible = 'extension.incompatible';
  static const String extensionLoadFailed = 'extension.load_failed';
  static const String sourceInvalid = 'source.invalid';
  static const String sourceUnreachable = 'source.unreachable';
  static const String sourceParseFailed = 'source.parse_failed';
  static const String sourceRefreshFailed = 'source.refresh_failed';
  static const String repositoryUnavailable = 'repository.unavailable';
  static const String repositoryParseFailed = 'repository.parse_failed';
  static const String providerUnsupported = 'provider.unsupported';
  static const String providerNotFound = 'provider.not_found';
  static const String identityNotFound = 'identity.not_found';
  static const String identityAmbiguous = 'identity.ambiguous';
  static const String resolverUnsupported = 'resolver.unsupported';
  static const String resolverFailed = 'resolver.failed';
  static const String resolverTimeout = 'resolver.timeout';
  static const String networkTimeout = 'network.timeout';
  static const String networkUnreachable = 'network.unreachable';
  static const String networkForbidden = 'network.forbidden';
  static const String networkRateLimited = 'network.rate_limited';
  static const String networkResponseTooLarge = 'network.response_too_large';
  static const String permissionDenied = 'permission.denied';
  static const String permissionRestricted = 'permission.restricted';
  static const String authRequired = 'auth.required';
  static const String authExpired = 'auth.expired';
  static const String authInvalid = 'auth.invalid';
  static const String taskCancelled = 'task.cancelled';
  static const String taskTimeout = 'task.timeout';
  static const String taskFailed = 'task.failed';
  static const String mediaUnsupported = 'media.unsupported';
  static const String mediaExpired = 'media.expired';
  static const String mediaUnavailable = 'media.unavailable';
}

/// A portable description of a failure.
final class PlatformErrorInfo {
  const PlatformErrorInfo({
    required this.code,
    required this.message,
    this.category,
    this.retryable = false,
    this.recoverable = false,
    this.metadata = const <String, Object?>{},
  });

  factory PlatformErrorInfo.fromJson(Map<String, Object?> json) {
    return PlatformErrorInfo(
      code: requireString(json, 'code', 'platform_error_info'),
      message: requireString(json, 'message', 'platform_error_info'),
      // An absent key stays null; a key this reader does not know degrades to `unknown`.
      category: json['category'] == null
          ? null
          : enumByName(PlatformErrorCategory.values, json['category'] as String?) ?? PlatformErrorCategory.unknown,
      retryable: json['retryable'] as bool? ?? false,
      recoverable: json['recoverable'] as bool? ?? false,
      // Unknown keys are tolerated on purpose: an older reader must not break on a newer writer.
      metadata: asObjectMap(json['metadata']),
    );
  }

  /// One of [PlatformErrorCodes], or a namespaced custom code.
  final String code;

  /// A human readable summary. Never embed credentials or request headers here.
  final String message;

  final PlatformErrorCategory? category;

  /// Retrying the same operation may succeed, for example a transient network failure.
  final bool retryable;

  /// The platform can continue after this failure, for example by falling back to another source.
  final bool recoverable;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'code': code,
      'message': message,
      if (category != null) 'category': category!.name,
      if (retryable) 'retryable': true,
      if (recoverable) 'recoverable': true,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Equality covers the described failure, not the attached metadata.
  @override
  bool operator ==(Object other) {
    return other is PlatformErrorInfo &&
        other.code == code &&
        other.message == message &&
        other.category == category &&
        other.retryable == retryable &&
        other.recoverable == recoverable;
  }

  @override
  int get hashCode => Object.hash(code, message, category, retryable, recoverable);
}
