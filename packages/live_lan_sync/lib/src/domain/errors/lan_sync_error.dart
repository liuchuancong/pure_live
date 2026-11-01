import 'dart:convert' show jsonEncode;

/// The engine's error model.
///
/// Every failure the engine reports is a [LanSyncError] with a stable
/// [code], one of the stable [LanSyncErrorCategory] values, and the facts a
/// host needs to decide what to do: whether retrying can help, which device
/// and task it belongs to, and which stage failed. Messages are written to
/// be shown to a user; secrets, tokens, full payloads and sensitive paths
/// never enter an error (spec §18).
final class LanSyncError implements Exception {
  /// A classified engine failure.
  const new({
    required this.category,
    required this.code,
    required this.message,
    this.retryable = false,
    this.deviceId,
    this.taskId,
    this.stage,
    this.debugContext,
  });

  /// The stable category the host switches on.
  final LanSyncErrorCategory category;

  /// The stable machine-readable code, e.g. `pairing_code_expired`.
  final String code;

  /// A safe, user-presentable description.
  final String message;

  /// Whether retrying the operation can plausibly succeed. Authentication
  /// failures, permission denials and protocol incompatibilities are never
  /// retryable.
  final bool retryable;

  /// The peer the failure concerns, when known.
  final String? deviceId;

  /// The task the failure occurred in, when known.
  final String? taskId;

  /// The task stage the failure occurred in, when known.
  final String? stage;

  /// Engineer-facing context. Excluded from [toString] so a log line of the
  /// error itself can never leak it; callers choose where it goes.
  final String? debugContext;

  /// A copy annotated with the task it occurred in.
  LanSyncError withTask({required String taskId, String? stage}) => LanSyncError(
    category: category,
    code: code,
    message: message,
    retryable: retryable,
    deviceId: deviceId,
    taskId: taskId,
    stage: stage ?? this.stage,
    debugContext: debugContext,
  );

  @override
  String toString() => 'LanSyncError($code, ${category.name}, retryable: $retryable): $message';

  /// The JSON form for the host's error log or task record.
  Map<String, Object?> toJson() => <String, Object?>{
    'category': category.name,
    'code': code,
    'message': message,
    'retryable': retryable,
    'deviceId': deviceId,
    'taskId': taskId,
    'stage': stage,
  };

  /// A compact JSON line for structured log sinks. Deliberately excludes
  /// [debugContext].
  String encode() => jsonEncode(toJson());
}

/// The stable failure categories, the vocabulary hosts switch on.
enum LanSyncErrorCategory {
  /// The configuration failed validation or is internally contradictory.
  configuration,

  /// Discovery itself failed (mDNS unavailable, permission denied).
  discovery,

  /// The peer could not be reached at any known address.
  deviceUnavailable,

  /// The peer's identity does not match the paired fingerprint.
  identityMismatch,

  /// The pairing ceremony failed.
  pairing,

  /// An established session failed authentication.
  authentication,

  /// The operation was refused for missing scope or file permission.
  permissionDenied,

  /// The peers speak incompatible protocol versions.
  protocolIncompatible,

  /// The peer's payload schema version is not supported.
  schemaIncompatible,

  /// The transport broke down mid-operation.
  transport,

  /// An operation outlived its timeout.
  timeout,

  /// The peer or this device rate-limited the request.
  rateLimited,

  /// Received data failed validation.
  dataValidation,

  /// The host's store failed to read or write.
  storage,

  /// A conflict needs a decision that no policy could make alone.
  conflict,

  /// A file transfer failed for reasons beyond integrity.
  fileTransfer,

  /// A chunk or whole-file checksum did not match.
  integrityCheck,

  /// The target has no room for the transfer.
  insufficientStorage,

  /// The operation was cancelled.
  cancelled,

  /// Anything the engine could not classify.
  unknown,
}
