import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/environment/layout_profile.dart' show LayoutProfile;
import 'package:pure_live/app/shell/desktop/pure_title_bar.dart' show PureTitleBar;
import 'package:pure_live/app/shell/navigation/app_navigation.dart' show kDesktopNavigation;
import 'package:pure_live/i18n/translations.g.dart';

/// The desktop shell: the self-drawn title bar above, the sidebar on the
/// left, the branches to the right.
///
/// The caption is drawn here and every window verb is forwarded to the
/// window host — the layout is the app's, the window behaviour is
/// `live_shell_desktop`'s.
final class DesktopShell extends ConsumerWidget {
  /// A desktop shell around [shell].
  const new({required this.shell, required this.profile, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  /// How much room the window currently gives.
  final LayoutProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final expanded = profile == LayoutProfile.expanded;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          const PureTitleBar(),
          Expanded(
            child: Row(
              children: [
                DsSidebar(
                  collapsed: !expanded,
                  value: shell.currentIndex,
                  onChanged: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
                  children: [
                    for (final (index, item) in kDesktopNavigation.indexed)
                      DsSidebarItem(
                        label: Text(item.label(t)),
                        value: index,
                        leading: DsIcon(item.icon),
                        selected: index == shell.currentIndex,
                        onPressed: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
                      ),
                  ],
                ),
                ColoredBox(color: colors.border, child: const SizedBox(width: 1)),
                Expanded(child: shell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
