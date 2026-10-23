import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/shell/navigation/app_navigation.dart' show kTvNavigation;
import 'package:pure_live/app/shell/tv/tv_navigation.dart' show TvNavigationPill;

/// The TV shell: the branches across the top as focusable pills, the branch
/// beneath.
///
/// Focus travel is the interaction — the pill row is the first focus stop,
/// and a dpad's left and right walk it — which is why the pills are plain
/// focusable buttons rather than a navigation bar.
final class TvShell extends ConsumerWidget {
  /// A TV shell around [shell].
  const new({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                for (final (index, item) in kTvNavigation.indexed)
                  TvNavigationPill(
                    item: item,
                    selected: index == shell.currentIndex,
                    autofocus: index == 0,
                    onSelected: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
                  ),
              ],
            ),
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
