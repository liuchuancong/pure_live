import 'package:flutter/widgets.dart' show BuildContext;
import 'package:multiview_desktop/multiview_desktop.dart';

/// The small, typed vocabulary windows use to ask each other to do something.
///
/// Single-engine windows share memory, so these are plain Dart objects with no
/// serialisation. The message layer remains typed so pages never pass ad-hoc
/// maps and so the transport can be replaced without touching call sites.
sealed class DesktopMessage {
  /// A message.
  const new();
}

/// "Show [location] in this window."
final class DesktopNavigate extends DesktopMessage {
  /// A navigation request.
  const new(this.location);

  /// The router location to open.
  final String location;
}

/// "Bring this window forward."
final class DesktopFocus extends DesktopMessage {
  /// A focus request.
  const new();
}

/// "Refresh what you are showing; the shared data changed."
final class DesktopInvalidated extends DesktopMessage {
  /// An invalidation notice.
  const new(this.reason);

  /// What changed, for logging and page-specific handling.
  final String reason;
}

/// Typed routing over the plugin's in-process communicator.
///
/// This is intentionally thin: shared repositories and Riverpod state remain
/// the source of truth; messages only carry commands or invalidation notices.
final class DesktopMessageBus {
  /// Private so the process-wide [instance] is the only bus.
  // ignore: unnecessary_type_name_in_constructor
  DesktopMessageBus._();

  /// The process-wide bus.
  static final DesktopMessageBus instance = DesktopMessageBus._();

  /// Messages addressed to the window that owns [context].
  Stream<DesktopMessage> onDirect(BuildContext context) => MultiViewDesktop.communicator
      .onDirect(context)
      .where((message) => message is DesktopMessage)
      .cast<DesktopMessage>();

  /// Messages broadcast to every subscribed window.
  Stream<DesktopMessage> get onBroadcast =>
      MultiViewDesktop.communicator.onBroadcast.where((message) => message is DesktopMessage).cast<DesktopMessage>();

  /// Sends [message] to [viewId].
  void send(int viewId, DesktopMessage message) => MultiViewDesktop.communicator.send(viewId, message);

  /// Sends [message] to every subscribed window.
  void broadcast(DesktopMessage message) => MultiViewDesktop.communicator.broadcast(message);
}
