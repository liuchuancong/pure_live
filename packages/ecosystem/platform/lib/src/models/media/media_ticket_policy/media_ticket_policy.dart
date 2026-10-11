// Module: lib/src/models/media/media_ticket_policy/media_ticket_policy.dart
// Purpose: MediaTicketPolicy, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';

/// What the platform is allowed to do with a ticket. Defaults follow section 11.
final class MediaTicketPolicy {
  const MediaTicketPolicy({
    this.allowRedirect = true,
    this.allowRefresh = true,
    this.allowRetry = true,
    this.allowLineFallback = true,
    this.allowEngineFallback = false,
    this.seamlessRefresh = false,
    this.retryDelay = const Duration(seconds: 2),
  });

  factory MediaTicketPolicy.fromJson(Map<String, Object?> json) {
    return MediaTicketPolicy(
      allowRedirect: json['allowRedirect'] as bool? ?? true,
      allowRefresh: json['allowRefresh'] as bool? ?? true,
      allowRetry: json['allowRetry'] as bool? ?? true,
      allowLineFallback: json['allowLineFallback'] as bool? ?? true,
      allowEngineFallback: json['allowEngineFallback'] as bool? ?? false,
      seamlessRefresh: json['seamlessRefresh'] as bool? ?? false,
      retryDelay: parseDurationMs(json['retryDelayMs']) ?? const Duration(seconds: 2),
    );
  }

  final bool allowRedirect;

  /// Whether the platform may re-resolve the same content to obtain a fresh resource.
  final bool allowRefresh;
  final bool allowRetry;

  /// Whether another line of the same source may be used.
  final bool allowLineFallback;

  /// Whether a different player engine may be tried. Sources that only work in one engine set this false.
  final bool allowEngineFallback;

  /// Refresh without interrupting playback.
  final bool seamlessRefresh;
  final Duration retryDelay;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'allowRedirect': allowRedirect,
      'allowRefresh': allowRefresh,
      'allowRetry': allowRetry,
      'allowLineFallback': allowLineFallback,
      'allowEngineFallback': allowEngineFallback,
      'seamlessRefresh': seamlessRefresh,
      'retryDelayMs': durationMs(retryDelay),
    };
  }
}
