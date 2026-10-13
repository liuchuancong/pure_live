import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/widgets/live_button.dart' show LiveButton;

/// Shows a themed modal — the Ant `Modal` counterpart. The surface (elevated
/// background, corner radius, padding and shadow) is drawn from the active
/// theme's tokens; the caller supplies the [title], [child] and [actions]
/// (typically [LiveButton]s that pop the route).
Future<T?> showLiveDialog<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget> actions = const [],
  double maxWidth = 420,
  bool dismissible = true,
}) {
  final theme = LiveTheme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: theme.colors.mask,
    transitionDuration: theme.duration,
    pageBuilder: (dialogContext, _, _) =>
        _DialogSurface(title: title, actions: actions, maxWidth: maxWidth, child: child),
    transitionBuilder: (dialogContext, animation, _, dialog) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.96,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: dialog,
      ),
    ),
  );
}

class _DialogSurface extends StatelessWidget {
  const new({required this.title, required this.actions, required this.maxWidth, required this.child});

  final String? title;
  final List<Widget> actions;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final card = theme.card;
    final gap = theme.token.scale.sizes.md;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.token.scale.sizes.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: EdgeInsets.all(card.padding),
            decoration: BoxDecoration(
              color: theme.colors.bgElevated,
              borderRadius: BorderRadius.circular(card.borderRadius),
              boxShadow: theme.token.motion.boxShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title case final t?) ...[
                  Text(t, style: theme.text.title.copyWith(color: theme.colors.text)),
                  SizedBox(height: gap),
                ],
                child,
                if (actions.isNotEmpty) ...[
                  SizedBox(height: gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final action in actions)
                        Padding(
                          padding: EdgeInsets.only(left: theme.token.scale.sizes.sm),
                          child: action,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
