import 'dart:async' show Completer, unawaited;
import 'dart:io' show exit;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart'
    show DesktopShell, ShellSettings, TrayAction, TrayDivider, TrayEntry, TrayIconState, WindowHost, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart' show MultiViewWindowHost, TrayManagerHost;
import 'package:live_storage/live_storage.dart' show StorageStores;
import 'package:multiview_desktop/multiview_desktop.dart' show MultiViewDesktop;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/windows/chrome/window_close_dialog.dart' show showCloseWindowDialog;
import 'package:pure_live/app/windows/shell/tray_screenshot.dart' show captureRoomScreenshot;
import 'package:pure_live/features/settings/settings.dart' show playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart' show t;

/// Starts the primary window's shell exactly once.
///
/// The window already exists when this runs (the app root calls it after the
/// first frame), so there is no registration gap to wait through and no
/// identity oracle: the view id is the identity.
Future<DesktopShell> startDesktopShell(WidgetRef ref) async {
  final log = appLog.forCategory('shell');
  final host = ref.read(windowHostProvider);
  if (host == null) {
    throw StateError('the desktop shell needs the primary window host');
  }
  final windows = ref.read(secondaryWindowsProvider);
  final platform = ref.read(platformRuntimeProvider).environment.runtime.kind;
  final tray = TrayManagerHost(iconAssets: const {TrayIconState.idle: 'assets/tray/pure_live_22.png'});
  // Sound is one of the tray's own verbs: keep the menu's label honest by
  // rebuilding the tray whenever the global mute moves, from anywhere. The
  // subscription lives as long as the primary window — the tray with it.
  final shellCompleter = Completer<DesktopShell>();
  ref.listenManual(playbackSettingsProvider.select((settings) => settings.globalMute), (_, _) async {
    final shell = await shellCompleter.future;
    await shell.refreshTray();
  });

  // The plugin's window list includes this view; a peer is any other id.
  final selfViewId = host is MultiViewWindowHost ? host.viewId : null;
  bool hasPeer(List<int> ids) => selfViewId == null ? ids.isNotEmpty : ids.any((id) => id != selfViewId);

  // If closing the primary was turned into a hide because another window
  // existed, bring it back once the last peer goes away.
  var hiddenForPeers = false;
  final windowSet = MultiViewDesktop.allWindowIdsNotifier;
  void onWindowSetChanged() {
    if (!hiddenForPeers || hasPeer(windowSet.value)) return;
    hiddenForPeers = false;
    unawaited(_reveal(host));
  }

  windowSet.addListener(onWindowSetChanged);
  final shell = DesktopShell(
    platform: platform,
    window: host,
    settings: () => ShellSettings(closeAction: storedCloseAction(), dontAskExit: storedDontAskExit()),
    confirmClose: platform == PlatformKind.macos
        ? null
        : ({required tray}) async {
            final context = rootNavigatorKey.currentContext;
            if (context == null) return (action: storedCloseAction(), remember: storedDontAskExit());
            return await showCloseWindowDialog(context, tray: tray);
          },
    exit: () async {
      try {
        // The tray is already gone by now, so a window that refuses to finish
        // its close would leave a process with no icon and no window: quit
        // must end the process even when the last close hangs.
        await host.destroy().timeout(const Duration(seconds: 2));
      } on Object {
        // Fall through to the exit below.
      }
      exit(0);
    },
    tray: tray,
    windows: windows,
    hasOtherWindows: () async {
      final others = hasPeer(MultiViewDesktop.allWindowViewIds);
      if (others) hiddenForPeers = true;
      return others;
    },
    onMenuAction: (id) async {
      switch (id) {
        case 'newWindow':
          try {
            await windows?.open(role: WindowRole.panel);
          } on Object catch (error, stackTrace) {
            log.warning(
              'a new window could not be opened from the tray',
              fields: {'error': '$error', 'stack': '$stackTrace'},
            );
          }
        case 'screenshot':
          await captureRoomScreenshot(ref);
        case 'toggleSound':
          await ref
              .read(playbackSettingsProvider.notifier)
              .setGlobalMute(value: !ref.read(playbackSettingsProvider).globalMute);
      }
    },
    beforeQuit: () async {
      // The room windows go first: their kernels and subscriptions must stop
      // before the one store behind them is closed. The shell's own dismiss
      // pass afterwards finds an already-empty set.
      await windows?.dismissAll();
      try {
        await StorageStores.closeInstance();
      } on Object catch (error, stackTrace) {
        log.warning('storage could not close on quit', fields: {'error': '$error', 'stack': '$stackTrace'});
      }
    },
    menuEntries: () {
      // Read at menu-build time, so the sound verb carries the current
      // mute state (QQ's 打开所有声音/关闭声音 pair, one line either way).
      final muted = ref.read(playbackSettingsProvider).globalMute;
      return <TrayEntry>[
        TrayAction(id: 'show', label: t.settings.trayShow),
        TrayAction(id: 'hide', label: t.settings.trayHide),
        TrayAction(id: 'newWindow', label: t.common.newWindow),
        const TrayDivider(),
        TrayAction(id: 'screenshot', label: t.settings.trayScreenshot),
        TrayAction(id: 'toggleSound', label: muted ? t.settings.traySoundOn : t.settings.traySoundOff),
        const TrayDivider(),
        TrayAction(id: 'quit', label: t.settings.closeQuit),
      ];
    },
    tooltip: () => 'Pure Live',
  );
  await shell.start();
  shellCompleter.complete(shell);
  if (!shell.hasTray) {
    log.warning('tray icon unavailable', fields: {'error': '${tray.createError}'});
  }
  return shell;
}

Future<void> _reveal(WindowHost host) async {
  try {
    await host.show();
  } on Object {
    // The tray remains the way back.
  }
}
