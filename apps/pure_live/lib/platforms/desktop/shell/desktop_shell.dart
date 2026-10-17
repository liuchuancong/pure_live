import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The desktop chrome: the app's own caption strip, when this start took over the
/// window frame, over the dispatched navigation rail.
///
/// The rail used to be Material's, and the width-dependent label toggle was
/// written here because only Material's rail had such a knob. Both belong to the
/// language now: the shell reports destinations and the active library draws the
/// column — `NavigationView`'s pane under Fluent, the token rail under a language
/// that owns no shell — including whether a narrow pane drops the labels.
final class DesktopShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the desktop chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = PureAppShell(
      destinations: shellDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
      selectedId: ShellBranch.at(navigationShell.currentIndex).name,
      onSelected: (id) => goShellBranch(ref, navigationShell, id),
      placement: PureShellPlacement.rail,
      trailing: const Padding(padding: EdgeInsets.only(bottom: 16), child: SettingsEntryButton()),
      child: navigationShell,
    );

    // The strip exists only when this start was set up for it: the frame
    // takeover is configured before the window exists, so a mid-session flip
    // would leave a Flutter strip over an OS caption.
    if (ref.watch(windowChromeProvider) != ShellWindowChrome.app) {
      return shell;
    }
    return Column(
      children: [
        PureTitleBar(
          labels: PureTitleBarLabels(
            title: context.t.app.title,
            minimize: context.t.window.minimize,
            maximize: context.t.window.maximize,
            restore: context.t.window.restore,
            close: context.t.window.close,
          ),
          actions: const WindowManagerChromeActions(),
        ),
        Expanded(child: shell),
      ],
    );
  }
}
