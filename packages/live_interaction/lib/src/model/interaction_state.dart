import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_state.freezed.dart';

/// Where an interaction session currently stands.
enum InteractionPhase {
  /// Nothing connected yet.
  idle,

  /// At least one source is connected and listening.
  connected,

  /// A source broke and the session is reconnecting.
  reconnecting,

  /// Every source gave up.
  ended,
}

/// The immutable state of one interaction session.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class InteractionState with _$InteractionState {
  /// A state snapshot.
  const factory InteractionState({
    @Default(InteractionPhase.idle) InteractionPhase phase,

    /// The ids of the sources currently connected.
    @Default(<String>[]) List<String> activeSources,

    /// How many reconnects have been spent.
    @Default(0) int reconnectAttempts,

    /// The error that led to the current reconnect, if any.
    Object? lastError,
  }) = _InteractionState;

  const InteractionState._();

  /// Whether the session is listening.
  bool get isConnected => phase == InteractionPhase.connected;

  /// Whether the session stopped for good.
  bool get isEnded => phase == InteractionPhase.ended;
}
