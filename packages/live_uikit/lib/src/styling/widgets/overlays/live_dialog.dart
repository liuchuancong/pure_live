import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// Shows a modal — the Ant `Modal` counterpart.
///
/// The route, the barrier colour, the fade-and-scale and the dismissal are the
/// core's and stay the same in every language; the surface inside them is asked
/// of the active adapter, so a Fluent dialog arrives as a `ContentDialog` and a
/// Cupertino one as an action sheet without the caller knowing either. [actions]
/// should be dispatched controls, which is what makes them match the language,
/// and [maxWidth] is the shared frame's constraint — a language that sizes its
/// surface by its own layout ignores it.
///
/// The actions are built from the **dialog's** context, not the caller's: a
/// button that pops the nearest route has to pop the dialog, and handing the
/// caller's context to it would close the page instead.
Future<T?> showLiveDialog<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget> Function(BuildContext dialogContext)? actions,
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
    pageBuilder: (dialogContext, _, _) => Center(
      // The core frames the surface — centred, inset, capped in width — and the
      // language decides what the surface itself looks like.
      child: Padding(
        padding: EdgeInsets.all(theme.token.scale.sizes.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: theme.adapter.dialog(
            dialogContext,
            LanguageDialogSpec(
              title: title,
              content: child,
              actions: actions?.call(dialogContext) ?? const [],
              dismissible: dismissible,
            ),
          ),
        ),
      ),
    ),
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
