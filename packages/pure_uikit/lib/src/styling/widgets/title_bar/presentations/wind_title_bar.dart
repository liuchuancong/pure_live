import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_caption_button.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders a compact Wind-inspired desktop title bar.
///
/// The strip paints nothing — the window's own surface continues behind it —
/// and every colour comes from the [PureTheme] tokens, so the strip reads
/// correctly in both brightnesses. Window operations are injected by the
/// application Shell.
class PureWindTitleBar extends StatelessWidget {
  /// Creates a Wind-inspired title bar.
  const new({
    required this.labels,
    required this.actions,
    required this.isMaximized,
    required this.onToggleMaximize,
    this.metrics = const PureCaptionMetrics(titleBarHeight: 36, buttonWidth: 40, buttonHeight: 36),
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
    final colors = PureTheme.of(context).colors;

    return SizedBox(
      height: metrics.titleBarHeight,
      child: Row(
        children: [
          Expanded(
            child: PureTitleBarDragRegion(
              title: labels.title,
              startDragging: actions.startDragging,
              titleStyle: theme.textTheme.titleSmall?.copyWith(color: colors.text),
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
            foregroundColor: colors.text,
            hoverColor: colors.fillSecondary,
            onPressed: actions.minimize,
          ),
          PureTitleBarCaptionButton(
            buttonKey: const ValueKey('title-maximize'),
            icon: isMaximized ? Icons.filter_none : Icons.crop_square,
            tooltip: isMaximized ? labels.restore : labels.maximize,
            width: metrics.buttonWidth,
            height: metrics.buttonHeight,
            foregroundColor: colors.text,
            hoverColor: colors.fillSecondary,
            onPressed: onToggleMaximize,
          ),
          PureTitleBarCaptionButton(
            buttonKey: const ValueKey('title-close'),
            icon: Icons.close,
            tooltip: labels.close,
            width: metrics.buttonWidth,
            height: metrics.buttonHeight,
            foregroundColor: colors.text,
            hoverColor: colors.error,
            hoverForegroundColor: colors.textLightSolid,
            onPressed: actions.close,
          ),
        ],
      ),
    );
  }
}
