import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/shell/navigation/app_navigation.dart' show kMobileNavigation;
import 'package:pure_live/i18n/translations.g.dart';

/// The mobile shell: the branches above a bottom navigation bar.
///
/// Five destinations, icons plus labels — the bar the thumb reaches, not a
/// folded desktop rail.
final class MobileShell extends ConsumerWidget {
  /// A mobile shell around [shell].
  const new({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(child: shell),
        DsBottomNav(
          value: shell.currentIndex,
          onChanged: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          items: [
            for (final (index, item) in kMobileNavigation.indexed)
              DsBottomNavItem(value: index, icon: DsIcon(item.icon), label: Text(item.label(t))),
          ],
        ),
      ],
    );
  }
}
