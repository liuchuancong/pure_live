import 'dart:async' show unawaited;
import 'dart:io' show exit;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart'
    show DesktopShell, ShellSettings, TrayAction, TrayDivider, TrayEntry, TrayIconState, WindowHost, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart' show TrayManagerHost;
import 'package:live_storage/live_storage.dart' show StorageStores;
import 'package:multiview_desktop/multiview_desktop.dart' show MultiViewDesktop;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/windows/chrome/window_close_dialog.dart' show showCloseWindowDialog;
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

  // If closing the primary was turned into a hide because another window
  // existed, bring it back once the last peer goes away.
  var hiddenForPeers = false;
  final windowSet = MultiViewDesktop.allWindowIdsNotifier;
  void onWindowSetChanged() {
    if (!hiddenForPeers || windowSet.value.isNotEmpty) return;
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
      await host.destroy();
      exit(0);
    },
    tray: tray,
    windows: windows,
    hasOtherWindows: () async {
      final others = MultiViewDesktop.allWindowViewIds.isNotEmpty;
      if (others) hiddenForPeers = true;
      return others;
    },
    onMenuAction: (id) async {
      if (id != 'newWindow') return;
      try {
        await windows?.open(role: WindowRole.panel);
      } on Object catch (error, stackTrace) {
        log.warning(
          'a new window could not be opened from the tray',
          fields: {'error': '$error', 'stack': '$stackTrace'},
        );
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
    menuEntries: () => <TrayEntry>[
      TrayAction(id: 'show', label: t.settings.trayShow),
      TrayAction(id: 'hide', label: t.settings.trayHide),
      TrayAction(id: 'newWindow', label: t.common.newWindow),
      const TrayDivider(),
      TrayAction(id: 'quit', label: t.settings.closeQuit),
    ],
    tooltip: () => 'Pure Live',
  );
  await shell.start();
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
