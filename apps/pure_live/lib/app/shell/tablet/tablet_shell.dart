import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/shell/navigation/app_navigation.dart' show kTabletNavigation;
import 'package:pure_live/i18n/translations.g.dart';

/// The tablet shell: the branches beside a sidebar.
///
/// The middle device: touch like the phone, room like the desktop, so it
/// takes the sidebar without the caption.
final class TabletShell extends ConsumerWidget {
  /// A tablet shell around [shell].
  const new({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Row(
        children: [
          DsSidebar(
            value: shell.currentIndex,
            onChanged: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
            children: [
              for (final (index, item) in kTabletNavigation.indexed)
                DsSidebarItem(
                  label: Text(item.label(t)),
                  value: index,
                  leading: DsIcon(item.icon),
                  selected: index == shell.currentIndex,
                  onPressed: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
                ),
            ],
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
