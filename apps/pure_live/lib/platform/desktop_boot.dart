import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:live_platform/live_platform.dart' show PlatformKind, PlatformRuntimeInfo;
import 'package:live_preferences/live_preferences.dart' show DesktopPreferencesAsShell, PreferencesService;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/platform/desktop_tray_icons.dart' show trayIconAssets;
import 'package:pure_live/storage/services.dart' show AppServices;

/// The window surface colour for the beat before Flutter paints its first frame.
///
/// Deliberately not the app theme: resolving a `LiveTheme` needs a BuildContext,
/// and this colour is only ever visible for one frame.
const Color _surfaceColor = Color(0xFF101418);

/// What the process ended up being, after the single-instance lock was claimed.
final class InstanceClaim {
  /// A claim decided by [hasShell] and [isPrimary], carrying [channel] when this
  /// process is the one that keeps running.
  const new({required this.hasShell, required this.isPrimary, this.channel});

  /// Whether this platform has a shell and a lock at all (phones have neither).
  final bool hasShell;

  /// Whether this process holds the lock.
  final bool isPrimary;

  /// The channel to hand to [DesktopBootstrap.start].
  ///
  /// The same object must be used for both jobs: a second channel would bind a
  /// second port, and the new one would find the first already listening and
  /// conclude that *another* instance owns the app — a process handing its launch
  /// intent to itself, then quitting.
  final SocketInstanceChannel? channel;

  /// Whether this start should end without ever showing a window.
  bool get shouldExit => hasShell && !isPrimary;
}

/// The desktop shell for this process, assembled from what the app already boots.
///
/// This is the only file in the app that names a plugin: `live_shell` holds the
/// decisions, `live_shell_desktop` implements the seams, and between them they
/// know nothing about storage, the site registry or the widget tree. Everything
/// that knows both lives here.
///
/// It is also the only place that answers "is there a desktop to shell at all".
/// Android, Android TV and iOS have a player and no tray, no caption and no second
/// instance, so those builds get [DesktopBootstrap.none] and never touch a window
/// API — instead of every screen guessing about the platform.
final class DesktopBootstrap {
  /// A bootstrap over a shell that is already configured and started.
  new _(this.shell, this.instance) : _subscriptions = [];

  /// The handle for a platform with no shell.
  new none() : this._(null, null);

  /// The shell driving the main window, null where there is no desktop.
  final DesktopShell? shell;

  /// The lock this process holds, null on a phone or when it was never taken.
  final SocketInstanceChannel? instance;

  final List<StreamSubscription<Object?>> _subscriptions;

  /// Takes the single-instance lock, forwarding this command line if somebody
  /// else already holds it.
  ///
  /// Must be asked **before anything is shown**: [SocketInstanceChannel.acquire]
  /// hands the arguments to the running instance, and a process that opens a
  /// window first has shown the viewer two copies of an app that claims to be one.
  ///
  /// [arguments] are the ones the entry point was called with — not
  /// `Platform.executableArguments`, which under an AOT build is not the same
  /// list and would silently drop the intent being forwarded.
  static Future<InstanceClaim> claimInstance(List<String> arguments) async {
    final platform = PlatformRuntimeInfo.inferKind();
    if (!_hasShell(platform)) return const InstanceClaim(hasShell: false, isPrimary: true);

    final channel = SocketInstanceChannel(
      appId: 'pure-live',
      nonceFile: File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}instance.nonce'),
    );
    final role = await channel.acquire(arguments: arguments);
    if (role != InstanceRole.primary) {
      await channel.dispose();
      return const InstanceClaim(hasShell: true, isPrimary: false);
    }
    return InstanceClaim(hasShell: true, isPrimary: true, channel: channel);
  }

  /// Configures the window, builds the shell and starts it.
  ///
  /// The returned handle exists only to keep the subscriptions reachable; the
  /// shell drives itself from window and tray events from here on.
  static Future<DesktopBootstrap> start({
    required AppServices services,
    required List<String> arguments,
    required InstanceClaim claim,
  }) async {
    final platform = PlatformRuntimeInfo.inferKind();
    if (!_hasShell(platform)) return DesktopBootstrap.none();

    final settings = services.preferences.value.desktop;
    final directory = await getApplicationSupportDirectory();
    final geometryFile = File('${directory.path}${Platform.pathSeparator}window-geometry.json');
    final displays = const ScreenRetrieverDisplays().read;

    final window = WindowManagerHost(role: WindowRole.main, readDisplays: displays)..attach();
    await configureMainWindow(
      role: WindowRole.main,
      plan: primaryChromePlan(platform),
      fallbacks: settings.renderFallbacks,
      title: 'Pure Live',
      background: _surfaceColor,
    );

    final shell = DesktopShell(
      platform: platform,
      window: window,
      // Read fresh on every question: the viewer can change the close action
      // between two presses of the same button, and a snapshot taken here would
      // quietly stop the settings screen from doing anything at all.
      settings: () => services.preferences.value.desktop.shellSettings,
      exit: SystemNavigator.pop,
      tray: supportsTray(platform) ? TrayManagerHost(iconAssets: trayIconAssets(platform)) : null,
      stateStore: WindowStateStore(
        save: (record) => geometryFile.writeAsString(_encodeGeometry(record)),
        load: () async => geometryFile.existsSync() ? _decodeGeometry(geometryFile.readAsStringSync()) : null,
      ),
      // Null on macOS and Linux, where nothing here reads the machine's idle
      // span: the shell then declines the reclaim rather than guessing at it.
      idle: systemIdleReader,
      readDisplays: displays,
      menuEntries: () => _menu,
      tooltip: () => 'Pure Live',
      iconState: () => TrayIconState.idle,
    );

    await shell.start(
      // Two ways a start comes up without a window: the viewer set "start
      // hidden", or whatever launched this process asked for a hidden open. They
      // mean the same thing here; an incoming intent overrides both by way of
      // [DesktopShell.reveal].
      openedHiddenBySystem: wasRequestedHidden(arguments: arguments, openedAsHiddenBySystem: settings.startHidden),
    );

    final bootstrap = DesktopBootstrap._(shell, claim.channel).._follow(shell, services.preferences);
    return bootstrap;
  }

  /// Stops watching, runs the exit sequence and releases the lock.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await shell?.prepareToQuit();
    await instance?.dispose();
  }

  void _follow(DesktopShell shell, PreferencesService preferences) {
    // Provisional by design: a room link, a playlist file and a deep route all
    // need a navigator this app does not expose yet. What must not be lost in the
    // meantime is the one thing every intent agrees on — somebody asked for the
    // app, so the window comes back.
    final channel = instance;
    if (channel != null) {
      _subscriptions.add(channel.forwarded.listen((_) => unawaited(shell.reveal())));
    }
    // The reclaim threshold and the close action are both read live, but the
    // idle timer is armed at start, so a change has to be pushed.
    _subscriptions.add(preferences.changes.listen((_) => unawaited(shell.applySettingsChanged())));
  }
}

bool _hasShell(PlatformKind platform) =>
    platform == PlatformKind.windows || platform == PlatformKind.macos || platform == PlatformKind.linux;

List<TrayEntry> get _menu => const [
  TrayHeading(id: 'title', label: 'Pure Live'),
  TrayDivider(),
  TrayAction(id: 'show', label: 'Show window'),
  TrayAction(id: 'hide', label: 'Hide window'),
  TrayDivider(),
  // Offered even when the close button is set to hide: without it the only way
  // out of a hidden app is Task Manager, and that is an accident, not a menu.
  TrayAction(id: 'quit', label: 'Quit'),
];

String _encodeGeometry(WindowGeometry geometry) => jsonEncode({
  'left': geometry.frame.left,
  'top': geometry.frame.top,
  'width': geometry.frame.width,
  'height': geometry.frame.height,
  'maximized': geometry.maximized,
  'displayId': geometry.displayId,
});

/// Reads back what [_encodeGeometry] wrote, or nothing when it cannot be trusted.
///
/// The same rule the preferences group follows: a file a viewer hand-edited, or
/// one a newer build left behind, must not be able to stop the window from
/// opening. So every field is checked rather than cast, and a bad record simply
/// means "no memory of one" — which is what a first start already is.
WindowGeometry? _decodeGeometry(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final left = decoded['left'];
  final top = decoded['top'];
  final width = decoded['width'];
  final height = decoded['height'];
  if (left is! int || top is! int || width is! int || height is! int) {
    return null;
  }
  final displayId = decoded['displayId'];
  return WindowGeometry(
    frame: PixelRect(left, top, width, height),
    maximized: decoded['maximized'] == true,
    displayId: displayId is String ? displayId : null,
  );
}
