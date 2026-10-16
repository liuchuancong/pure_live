import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// `macos_ui` composes a window as `MacosScaffold` + one `ContentArea`, and the
/// bar sits above it — so [LanguageScaffoldSpec.appBar] and
/// [LanguageScaffoldSpec.bottomBar] are stacked around the scaffold rather than
/// handed to it: `MacosScaffold.toolBar` takes a `ToolBar` specifically, and the
/// dispatched bar is whatever the active language renders, which the frame may
/// not assume.
abstract final class MacosScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final body = macos.MacosScaffold(
      backgroundColor: spec.background,
      children: [
        // `ContentArea` hands its builder a scroll controller; the spec's body
        // owns its own scrolling, so the controller is not taken.
        macos.ContentArea(builder: (context, controller) => spec.body),
      ],
    );

    final frame = Column(
      children: [
        ?spec.appBar,
        Expanded(child: body),
        ?spec.bottomBar,
      ],
    );

    // Two fields have no macOS slot at this level: the floating action (the
    // library has no FAB, so the core's overlay geometry places it) and
    // [LanguageScaffoldSpec.extendBodyBehindAppBar] /
    // [LanguageScaffoldSpec.avoidKeyboard] — a macOS window's content area
    // already sits inside its own safe area and does not resize for a keyboard.
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
