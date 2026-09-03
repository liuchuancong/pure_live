import 'player_error_type.dart';

class PlayerException implements Exception {
  final String message;

  /// Stable machine-readable diagnostic used by recovery policy. The UI keeps
  /// [message] user-facing and must not parse localized/native text.
  final String? code;

  final Object? error;

  final StackTrace? stackTrace;

  final PlayerErrorType type;

  PlayerException({
    required this.message,
    required this.type,
    this.code,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return '[${type.name}] $message';
  }
}
