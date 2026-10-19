import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:live_shell/live_shell.dart';

/// Opens real secondary windows through `desktop_multi_window`.
///
/// What a secondary window is, in this plugin: a second Flutter engine with its
/// own isolate and its own Dart heap. Not a widget in another frame. Three
/// consequences that shape this class:
///
/// * **The new window cannot read anything the primary holds in memory.** Only
///   what is on disk and what is sent through [DesktopSecondaryWindow.send]
///   crosses. A float window that wants the current room therefore gets the room
///   passed in as its launch arguments and opens what storage it needs itself —
///   which is also why two engines must not both hold a write lock on the same
///   file.
/// * **Its geometry is its own business.** The plugin's controller offers
///   `show`, `hide` and messaging only: there is no `setFrame`, no `setTitle` and
///   no `close` for a remote caller. Sizing and titling happen inside that
///   window, where `window_frame_kit` addresses *its* engine's window. This is not
///   a limitation to route around; it is the shape of the thing.
/// * **Its role must arrive in the launch arguments**, because a window cannot
///   ask what it is, and `live_shell` decides lifetime, taskbar presence and
///   focus-stealing from the role. A window that never learns its role defaults
///   to believing it owns the application.
final class DesktopWindowLauncher implements WindowLauncher {
  /// A launcher.
  new();

  @override
  Future<SecondaryWindow> open({required WindowRole role, String? route}) async {
    final controller = await WindowController.create(
      WindowConfiguration(
        // The default: hidden until the new engine has drawn its first frame.
        // Showing at creation would flash a blank surface, which reads as a
        // crash; `hiddenAtLaunch` is about that beat, not about staying away.
        arguments: WindowArguments(role: role, route: route).encode(),
      ),
    );
    final window = DesktopSecondaryWindow(controller: controller, role: role);
    await window.show();
    return window;
  }
}

/// A window in another engine, as this process can reach it.
final class DesktopSecondaryWindow implements SecondaryWindow {
  /// A handle over a created window.
  const new({required this.controller, required this.role});

  /// The plugin's controller.
  final WindowController controller;

  @override
  final WindowRole role;

  @override
  String get id => controller.windowId;

  @override
  Future<void> show() => controller.show();

  @override
  Future<void> hide() => controller.hide();

  @override
  Future<T?> send<T>(String method, [Object? arguments]) => controller.invokeMethod<T>(method, arguments);
}

/// What a secondary window needs to know about itself at start-up.
final class WindowArguments {
  /// Arguments for a new window.
  const new({required this.role, this.route, this.entryPoint = 'main'});

  /// Reads what [encode] wrote.
  ///
  /// Falls back to the main window's meaning when the payload is not ours: a
  /// window started by an older build must still come up rather than crash on a
  /// key that did not exist yet.
  // A factory has to repeat the enclosing class name; the lint that asks
  // otherwise is the same one the generated Freezed factories ignore.
  // ignore: unnecessary_type_name_in_constructor
  factory WindowArguments.fromRaw(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const WindowArguments(role: WindowRole.main);
    }
    if (json is! Map) {
      return const WindowArguments(role: WindowRole.main);
    }
    final role = json['role'];
    final route = json['route'];
    final entry = json['entry'];
    return WindowArguments(
      role: WindowRole.values.firstWhere((candidate) => candidate.name == role, orElse: () => WindowRole.main),
      route: route is String ? route : null,
      entryPoint: entry is String ? entry : 'main',
    );
  }

  /// The role the shell assigned this window.
  final WindowRole role;

  /// Where to navigate first, if the role has pages.
  final String? route;

  /// Which of the app's entry points to run.
  final String entryPoint;

  /// Encodes for the plugin's single string channel.
  String encode() => jsonEncode({'entry': entryPoint, 'role': role.name, if (route != null) 'route': route});
}

/// Reads the arguments of the window this isolate is running in.
///
/// Called at the top of the app's entry point: the same `main()` runs in every
/// engine, and this is the only way it learns whether it is the main window, a
/// floating video window or a panel — which then decides what it may do to the
/// process when it closes.
Future<WindowArguments> currentWindowArguments() async {
  final controller = await WindowController.fromCurrentEngine();
  return WindowArguments.fromRaw(controller.arguments);
}
