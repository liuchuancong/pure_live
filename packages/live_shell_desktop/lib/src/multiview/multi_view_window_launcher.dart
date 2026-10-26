import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/multiview/desktop_message_bus.dart';
import 'package:live_shell_desktop/src/multiview/desktop_window_registry.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

/// Builds the widget tree for one opened window. The app provides this so the
/// shell package never learns about routes, providers or pages.
typedef DesktopWindowPageBuilder = Widget Function(BuildContext context, DesktopWindowRecord record);

/// Opens windows as extra Flutter views in the same engine.
///
/// This is the replacement for `DesktopWindowLauncher`: no second isolate, no
/// launch arguments and no per-engine plugin registration. The page builder
/// receives the plugin's view id and the record the registry keeps.
final class MultiViewWindowLauncher implements WindowLauncher {
  /// A launcher over [registry], building each page with [pageBuilder].
  new({required this.registry, required this.pageBuilder});

  /// The process's live window table.
  final DesktopWindowRegistry registry;

  /// Where a window's content comes from.
  final DesktopWindowPageBuilder pageBuilder;

  @override
  Future<SecondaryWindow> open({required WindowRole role, String? route, String? businessKey}) async {
    final before = MultiViewDesktop.allWindowViewIds.toSet();
    try {
      final viewId = await openWindow((context, id) {
        final record = DesktopWindowRecord(
          viewId: id,
          role: role,
          businessKey: businessKey,
          route: route,
          openedAt: DateTime.now(),
        );
        registry.add(record);
        return pageBuilder(context, record);
      }, options: _optionsFor(role, route));
      if (!role.showsInTaskbar) {
        MultiViewDesktop.fromId(viewId).hideCurrentAppTabFromTaskbar(true);
      }
      return MultiViewSecondaryWindow(viewId: viewId, role: role, route: route, businessKey: businessKey);
    } on Object {
      // The native window exists as soon as the view is created, so a page
      // that never built leaves a dead frame on screen. Take back whatever
      // this attempt added before reporting the failure.
      for (final id in MultiViewDesktop.allWindowViewIds) {
        if (before.contains(id)) continue;
        registry.remove(id);
        final window = MultiViewDesktop.fromId(id)..setPreventClose(false);
        unawaited(window.closeWindow());
      }
      rethrow;
    }
  }

  WindowOptions _optionsFor(WindowRole role, String? route) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final (size, minSize) = switch (role) {
      WindowRole.videoFloat => (const Size(480, 320), const Size(320, 200)),
      WindowRole.popup => (const Size(380, 120), const Size(280, 80)),
      _ => (const Size(900, 620), const Size(520, 380)),
    };
    return WindowOptions(
      size: size,
      minimumSize: minSize,
      titleBarStyle: TitleBarStyle.hidden,
      // Windows and Linux get the app's own caption buttons; macOS keeps the
      // traffic lights inset in the app's strip.
      windowButtonVisibility: mac,
      title: route == null ? 'Pure Live' : 'Pure Live · ${role.name}',
      alwaysOnTop: role == WindowRole.videoFloat || role == WindowRole.popup,
      showOnInit: true,
      // The plugin wraps every secondary view in a shell copied from the main
      // window (theme, locale, and a navigator for `home`). A widgets-level
      // shell cannot build its default route without this factory: Flutter's
      // `WidgetsApp` asserts when `home` is given with neither a builder nor
      // an `onGenerateRoute`. The page is the window itself, so there is no
      // transition to add on top of the native open/close animation.
      //
      // The appearance is pinned rather than inherited: before the primary has
      // published its snapshot the plugin falls back to a bare `MaterialApp`
      // (a different app widget, with the debug banner on), which remounts the
      // page inside a second app. The app root is a `WidgetsApp`, so the
      // widgets kind is the one that matches it.
      shellOverrides: const ViewShellOverrides(
        pageRouteBuilder: _windowPageRoute,
        appearance: AppShellPatch(kind: AppEntryKind.widgets, debugShowCheckedModeBanner: false),
      ),
    );
  }

  static PageRoute<T> _windowPageRoute<T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}

/// A window handle addressed by view id.
///
/// [send] is kept for the shell's generic verbs. On this backend it maps to
/// typed messages or direct plugin calls; nothing is serialised.
final class MultiViewSecondaryWindow implements SecondaryWindow {
  /// A handle over [viewId].
  const new({required this.viewId, required this.role, this.route, this.businessKey});

  /// The plugin's public view id.
  final int viewId;

  @override
  final WindowRole role;

  /// The route the window was opened at.
  final String? route;

  /// The business identity the window shows.
  final String? businessKey;

  MultiViewDesktop get _window => MultiViewDesktop.fromId(viewId);

  @override
  String get id => viewId.toString();

  @override
  Future<void> show() async {
    _window.show();
    if (role.takesFocusOnShow) _window.focus();
  }

  @override
  Future<void> hide() async => _window.hide();

  @override
  Future<T?> send<T>(String method, [Object? arguments]) async {
    switch (method) {
      case 'shell_navigate':
        final route = switch (arguments) {
          final Map<Object?, Object?> map => map['route'],
          _ => null,
        };
        if (route is String && route.isNotEmpty) {
          DesktopMessageBus.instance.send(viewId, DesktopNavigate(route));
        }
        return T == bool ? true as T : null;
      case 'shell_dismiss':
        // The quit path runs this after its own cleanup; it must not wait on
        // a confirmation the viewer can no longer see.
        _window.setPreventClose(false);
        await _window.closeWindow();
        return T == bool ? true as T : null;
      default:
        return null;
    }
  }
}
