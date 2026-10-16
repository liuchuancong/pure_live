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
Future<T?> showLiveDialog<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget> actions = const [],
  double maxWidth = 420,
  bool dismissible = true,
}) {
  final theme = LiveTheme.of(context);
  final spec = LanguageDialogSpec(title: title, content: child, actions: actions, dismissible: dismissible);
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
          child: theme.adapter.dialog(dialogContext, spec),
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

/// The token-driven dialog surface: an elevated card, the title in the heading
/// role, the actions right-aligned.
///
/// It is the surface only — [showLiveDialog] centres, insets and caps it, and
/// owns the barrier and the transition — which is why a language that wants a
/// different presentation overrides [LanguageAdapter.dialog] rather than that
/// call.
class TokenDialog extends StatelessWidget {
  /// A token dialog built from [spec].
  const new({required this.spec, super.key});

  /// The dialog configuration.
  final LanguageDialogSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final card = theme.card;
    final gap = theme.token.scale.sizes.md;

    return Container(
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
          if (spec.icon case final glyph?) ...[Icon(glyph, color: theme.colors.primary), SizedBox(height: gap)],
          if (spec.title case final t?) ...[
            Text(t, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: gap),
          ],
          ?spec.content,
          if (spec.actions.isNotEmpty) ...[
            SizedBox(height: gap),
            // A wrap, not a row: Material's own dialog bars use an overflow bar
            // for exactly this reason — two long labels in a narrow dialog have
            // to stack rather than run off the edge.
            Wrap(alignment: WrapAlignment.end, spacing: theme.token.scale.sizes.sm, children: spec.actions),
          ],
        ],
      ),
    );
  }
}
