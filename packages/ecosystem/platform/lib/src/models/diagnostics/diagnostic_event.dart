// Module: lib/src/models/diagnostics/diagnostic_event.dart
// Purpose: The record shape for platform diagnostics: an event, the trace it belongs to and a timed span.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 14 and docs/diagnostics/tracing.md. Events carry ids
// and a content reference, never live objects, so a diagnostic can be stored, streamed across an
// isolate or shipped to a crash reporter unchanged. Sensitive headers must be redacted before they
// enter metadata (section 16).

import '../../support/json.dart';
import '../content/content_ref.dart';
import '../error/platform_error_info.dart';
import '../identifiers.dart';

enum DiagnosticLevel { debug, info, warning, error, fatal }

/// Whether a span finished, and how.
enum DiagnosticSpanStatus { running, success, failed, cancelled }

/// One diagnostic record.
final class DiagnosticEvent {
  const DiagnosticEvent({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.name,
    this.traceId,
    this.extensionId,
    this.sourceId,
    this.repositoryId,
    this.providerId,
    this.resolverId,
    this.taskId,
    this.content,
    this.error,
    this.metadata = const <String, Object?>{},
  });

  factory DiagnosticEvent.fromJson(Map<String, Object?> json) {
    return DiagnosticEvent(
      id: requireString(json, 'id', 'diagnostic_event'),
      timestamp: parseUtc(json['timestamp']) ?? DateTime.utc(1970),
      level: enumByName(DiagnosticLevel.values, json['level'] as String?) ?? DiagnosticLevel.info,
      name: requireString(json, 'name', 'diagnostic_event'),
      traceId: json['traceId'] as String?,
      extensionId: json['extensionId'] as String?,
      sourceId: json['sourceId'] as String?,
      repositoryId: json['repositoryId'] as String?,
      providerId: json['providerId'] as String?,
      resolverId: json['resolverId'] as String?,
      taskId: json['taskId'] as String?,
      content: json['content'] == null ? null : ContentRef.fromJson(asObjectMap(json['content'])),
      error: json['error'] == null ? null : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final DiagnosticId id;

  /// Always UTC; a local timestamp cannot be compared across devices.
  final DateTime timestamp;
  final DiagnosticLevel level;

  /// A stable dotted name such as `source.refresh` so counts aggregate across versions.
  final String name;
  final TraceId? traceId;
  final ExtensionId? extensionId;
  final SourceId? sourceId;
  final RepositoryId? repositoryId;
  final ProviderId? providerId;
  final ResolverId? resolverId;
  final TaskId? taskId;
  final ContentRef? content;
  final PlatformErrorInfo? error;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'timestamp': formatUtc(timestamp),
      'level': level.name,
      'name': name,
      if (traceId != null) 'traceId': traceId,
      if (extensionId != null) 'extensionId': extensionId,
      if (sourceId != null) 'sourceId': sourceId,
      if (repositoryId != null) 'repositoryId': repositoryId,
      if (providerId != null) 'providerId': providerId,
      if (resolverId != null) 'resolverId': resolverId,
      if (taskId != null) 'taskId': taskId,
      if (content != null) 'content': content!.toJson(),
      if (error != null) 'error': error!.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

/// A user-perceived operation that several events and spans belong to.
final class DiagnosticTrace {
  const DiagnosticTrace({
    required this.id,
    required this.operation,
    required this.startedAt,
    this.completedAt,
    this.metadata = const <String, Object?>{},
  });

  factory DiagnosticTrace.fromJson(Map<String, Object?> json) {
    return DiagnosticTrace(
      id: requireString(json, 'id', 'diagnostic_event'),
      operation: requireString(json, 'operation', 'diagnostic_event'),
      startedAt: parseUtc(json['startedAt']) ?? DateTime.utc(1970),
      completedAt: parseUtc(json['completedAt']),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final TraceId id;
  final String operation;
  final DateTime startedAt;

  /// Null while the trace is still open.
  final DateTime? completedAt;
  final Map<String, Object?> metadata;

  Duration? get elapsed => completedAt == null ? null : completedAt!.difference(startedAt);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'operation': operation,
      'startedAt': formatUtc(startedAt),
      if (completedAt != null) 'completedAt': formatUtc(completedAt),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

/// A timed segment inside a trace.
final class DiagnosticSpan {
  const DiagnosticSpan({
    required this.id,
    required this.traceId,
    required this.operation,
    required this.startedAt,
    this.completedAt,
    this.status = DiagnosticSpanStatus.running,
    this.metadata = const <String, Object?>{},
  });

  factory DiagnosticSpan.fromJson(Map<String, Object?> json) {
    return DiagnosticSpan(
      id: requireString(json, 'id', 'diagnostic_event'),
      traceId: requireString(json, 'traceId', 'diagnostic_event'),
      operation: requireString(json, 'operation', 'diagnostic_event'),
      startedAt: parseUtc(json['startedAt']) ?? DateTime.utc(1970),
      completedAt: parseUtc(json['completedAt']),
      status: enumByName(DiagnosticSpanStatus.values, json['status'] as String?) ?? DiagnosticSpanStatus.running,
      metadata: asObjectMap(json['metadata']),
    );
  }

  final String id;
  final TraceId traceId;
  final String operation;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DiagnosticSpanStatus status;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'traceId': traceId,
      'operation': operation,
      'startedAt': formatUtc(startedAt),
      if (completedAt != null) 'completedAt': formatUtc(completedAt),
      'status': status.name,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
