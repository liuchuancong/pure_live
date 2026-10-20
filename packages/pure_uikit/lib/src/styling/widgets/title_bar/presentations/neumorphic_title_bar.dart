import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_caption_button.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders a Neumorphic-inspired desktop title bar.
///
/// The surface and shadow colors adapt to the current Material theme.
/// Platform-specific window operations remain injected by the application
/// Shell.
class PureNeumorphicTitleBar extends StatelessWidget {
  /// Creates a Neumorphic-inspired title bar.
  const new({
    required this.labels,
    required this.actions,
    required this.isMaximized,
    required this.onToggleMaximize,
    this.metrics = const PureCaptionMetrics(titleBarHeight: 38, buttonWidth: 40, buttonHeight: 38),
    super.key,
  });

  /// The title and localized control labels.
  final PureTitleBarLabels labels;

  /// The window operations provided by the application Shell.
  final WindowChromeActions actions;

  /// Whether the current window is maximized.
  final bool isMaximized;

  /// Toggles the window between maximized and restored states.
  final VoidCallback onToggleMaximize;

  /// The dimensions used by this presentation.
  final PureCaptionMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final surface = colors.surface;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.35) : colors.shadow.withValues(alpha: 0.14);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(color: shadowColor, offset: const Offset(0, 2), blurRadius: 5),
          BoxShadow(color: highlightColor, offset: const Offset(0, -1), blurRadius: 2),
        ],
      ),
      child: SizedBox(
        height: metrics.titleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: PureTitleBarDragRegion(
                title: labels.title,
                startDragging: actions.startDragging,
                titleStyle: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
                onDoubleTap: onToggleMaximize,
                padding: const EdgeInsetsDirectional.only(start: 14),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-minimize'),
              icon: Icons.remove,
              tooltip: labels.minimize,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.onSurface,
              backgroundColor: surface,
              hoverColor: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              onPressed: actions.minimize,
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-maximize'),
              icon: isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: isMaximized ? labels.restore : labels.maximize,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.onSurface,
              backgroundColor: surface,
              hoverColor: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              onPressed: onToggleMaximize,
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-close'),
              icon: Icons.close,
              tooltip: labels.close,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.onSurface,
              backgroundColor: surface,
              hoverColor: colors.error,
              borderRadius: BorderRadius.circular(8),
              onPressed: actions.close,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
