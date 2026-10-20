import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_caption_button.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders the token-based title bar for Material, Fluent, and ForUI.
///
/// The strip paints nothing: the window's own surface (a backdrop material
/// where the platform offers one, the layout surface otherwise) continues
/// behind it, the way the system shell's strip does. Colors come from the
/// [PureTheme] tokens — the same source the pages under the strip read — so
/// the icons and their hovers hold up in both brightnesses.
///
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
