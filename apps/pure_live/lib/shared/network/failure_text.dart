/// The one user-facing line a network-layer failure shows: the shared
/// transport's breakdown kinds and the sites' rate limit have words of their
/// own, and everything else keeps the wording the layer that raised it
/// already wrote for a viewer.
library;

import 'package:live_net/live_net.dart' show ConnectFailure, ProtocolFailure, TimeoutFailure, TlsFailure;
import 'package:live_sites/live_sites.dart' show LiveSiteRateLimitError;
import 'package:pure_live/l10n/translations.dart';

/// The line [error] shows a viewer: a typed kind reads as its word, an
/// expected failure keeps its own message, anything else falls through as
/// text (a cancellation surfacing here is a bug worth its diagnostic line).
String networkFailureText(Object error) => switch (error) {
  TimeoutFailure() => t.common.networkTimeout,
  ConnectFailure() => t.common.networkUnreachable,
  TlsFailure() => t.common.networkSecure,
  ProtocolFailure() => t.common.networkFailed,
  LiveSiteRateLimitError() => t.common.networkRateLimited,
  _ => '$error',
};
