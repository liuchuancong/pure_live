import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_caption_button.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders the token-based title bar for Material, Fluent, and ForUI.
///
/// This presentation uses Flutter's theme tokens for colors and typography.
/// Window operations are injected by the parent title bar component.
class PureTokenTitleBar extends StatelessWidget {
  /// Creates a token-based title bar.
  const new({
    required this.labels,
    required this.actions,
    required this.isMaximized,
    required this.onToggleMaximize,
    this.metrics = const PureCaptionMetrics.desktop(),
    super.key,
  });

  /// The title and localized window-control labels.
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

    return Material(
      color: colors.surface,
      child: SizedBox(
        height: metrics.titleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: PureTitleBarDragRegion(
                title: labels.title,
                startDragging: actions.startDragging,
                titleStyle: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface),
                onDoubleTap: onToggleMaximize,
                padding: const EdgeInsetsDirectional.only(start: 12),
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
              hoverColor: colors.onSurface.withValues(alpha: 0.08),
              onPressed: actions.minimize,
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-maximize'),
              icon: isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: isMaximized ? labels.restore : labels.maximize,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.onSurface,
              hoverColor: colors.onSurface.withValues(alpha: 0.08),
              onPressed: onToggleMaximize,
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-close'),
              icon: Icons.close,
              tooltip: labels.close,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.onSurface,
              hoverColor: colors.error,
              onPressed: actions.close,
            ),
          ],
        ),
      ),
    );
  }
}
