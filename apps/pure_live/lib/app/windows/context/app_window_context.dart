import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart' show MultiViewWindowHost;

/// What one OS view knows about itself.
///
/// The root container is shared; this value is the one thing every window
/// overrides. Providers that hold playback, room or navigation state are
/// overridden in the same per-window scope, so two windows never share a
/// player or a route stack.
final class AppWindowContext {
  const AppWindowContext({
    required this.viewId,
    required this.role,
    required this.host,
    required this.initialRoute,
    this.businessKey,
  });

  /// The plugin's public view id.
  final int viewId;

  /// What the window is for.
  final WindowRole role;

  /// The window's native operations.
  final MultiViewWindowHost host;

  /// The business identity (`siteId/roomId`) when the window shows one.
  final String? businessKey;

  /// Where the window's router starts.
  final String initialRoute;

  /// Whether this is the application's primary window.
  bool get isMain => role == WindowRole.main;
}

/// The current view's context; overridden by every `AppWindowRoot`.
final appWindowContextProvider = Provider<AppWindowContext>(
  (ref) => throw StateError('appWindowContextProvider must be overridden per window'),
);
