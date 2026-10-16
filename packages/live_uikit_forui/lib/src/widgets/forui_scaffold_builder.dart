import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// `FScaffold` is the library's own frame — header slot, content, footer — so the
/// already-dispatched bar goes into `header` and the destination strip into `footer`,
/// which is also where the library paints its own top border for the bottom bar.
/// [LanguageScaffoldSpec.avoidKeyboard] is the library's `resizeToAvoidBottomInset`
/// under another name and [LanguageScaffoldSpec.background] is a style delta on the
/// frame's background colour, so neither has to be painted over the widget.
///
/// Two fields have no slot and are handled rather than dropped:
/// [LanguageScaffoldSpec.extendBodyBehindAppBar] asks for a body that starts under the
/// bar, which the library's header slot cannot do (it stacks the bar above the content),
/// so the frame gets no header and the bar is overlaid at the top of the content area —
/// the bar keeps its own safe-area inset; [LanguageScaffoldSpec.floatingActionButton] is
/// placed by this adapter's own geometry, because a ForUI page has no floating-action
/// slot at all.
abstract final class ForuiScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final bar = spec.appBar;
    final behindBar = spec.extendBodyBehindAppBar && bar != null;

    final body = behindBar
        ? Stack(
            children: [
              Positioned.fill(child: spec.body),
              Positioned(top: 0, left: 0, right: 0, child: bar),
            ],
          )
        : spec.body;

    final frame = forui.FScaffold(
      header: behindBar ? null : bar,
      footer: spec.bottomBar,
      resizeToAvoidBottomInset: spec.avoidKeyboard,
      scaffoldStyle: switch (spec.background) {
        final color? => forui.FScaffoldStyleDelta.delta(backgroundColor: color),
        null => const forui.FScaffoldStyleDelta.context(),
      },
      child: body,
    );

    final action = spec.floatingActionButton;
    if (action == null) {
      return frame;
    }
    final margin = LiveEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }
}
