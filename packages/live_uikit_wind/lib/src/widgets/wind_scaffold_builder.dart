import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// Composed, not mapped: the fork ships no frame — no `Scaffold`, no page, no
/// inset policy — because it is a styling library, so the frame is the library's
/// own container doing the job a frame does: a `WDiv` of `flex flex-col w-full
/// h-full` whose background is the library's own canvas pair (`bg-gray-50
/// dark:bg-gray-900`, which follows `WindTheme`'s brightness, and that comes from
/// the token §8.1). The dispatched [LanguageScaffoldSpec.appBar] and
/// [LanguageScaffoldSpec.bottomBar] are its first and last children and the body
/// takes the remaining height through `Expanded`, which is the flex share the
/// fork's own column composer gives a `flex-1` child.
///
/// Three fields have no fork slot and are handled rather than dropped:
/// [LanguageScaffoldSpec.background] is a runtime colour, so it arrives through
/// the container's own inline `backgroundColor` hook — the channel the library
/// documents for a colour that is not a static class token;
/// [LanguageScaffoldSpec.avoidKeyboard] is answered with the view insets the same
/// way a full-height column answers it, because the fork has no resize policy of its
/// own; and [LanguageScaffoldSpec.floatingActionButton] is placed by the core's
/// own page padding, since a Wind page has no FAB corner to put it in.
abstract final class WindScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = spec.avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = spec.appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        // The top inset belongs to the bar once the page has one that the content
        // does not run under; the bottom one belongs to the frame unless a bar
        // already sits there — the split a full-height column makes, kept so both paths agree.
        top: bar == null && !spec.extendBodyBehindAppBar,
        bottom: spec.bottomBar == null,
        child: spec.body,
      ),
    );

    final Widget body;
    if (bar == null) {
      body = content;
    } else if (spec.extendBodyBehindAppBar) {
      body = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(child: content),
        ],
      );
    }

    final frame = wind.WDiv(
      className: 'flex flex-col w-full h-full bg-gray-50 dark:bg-gray-900',
      backgroundColor: spec.background,
      children: [
        Expanded(child: body),
        ?spec.bottomBar,
      ],
    );

    final action = spec.floatingActionButton;
    if (action == null) {
      return frame;
    }
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }
}
