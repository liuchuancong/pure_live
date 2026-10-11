/// Live interaction sessions for Pure Live.
///
/// An `InteractionSession` merges several `InteractionSource`s of one
/// room (danmaku today; the site layer owns the protocols), deduplicates
/// and reconnect-gates messages through `MessageGate`, applies the
/// `MessageFilter` chain over the shared `LiveMessage` models, tracks
/// audience readings with `AudienceTracker` and coordinates source
/// lifecycles with backoff reconnects. The package is pure Dart and
/// never parses a platform protocol.
library;

export 'src/audience/audience_tracker.dart';
export 'src/model/interaction_state.dart';
export 'src/pipeline/message_filter.dart';
export 'src/pipeline/message_gate.dart';
export 'src/session/interaction_session.dart';
export 'src/source/interaction_source.dart';
