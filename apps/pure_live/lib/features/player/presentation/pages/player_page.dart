import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/i18n/translations.g.dart';

/// The player screen, pushed above the shell.
///
/// The playback session arrives with the playback phase; until then the
/// screen is a black stage with a way back, so the route and the shell's
/// pushed-screen behaviour are verifiable now.
final class PlayerPage extends ConsumerWidget {
  /// The player page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DsPressable(
              semanticLabel: t.window.close,
              onPressed: () => GoRouter.of(context).go(RouteNames.home),
              builder: (context, states, _) {
                final hovered = states.contains(WidgetState.hovered);
                return DsIcon(DsIcons.x, size: 20, color: hovered ? colors.text : colors.textMuted);
              },
            ),
          ),
        ),
      ),
    );
  }
}
