import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders a macOS-style title bar with red, yellow, and green controls.
///
/// The strip paints nothing — the window's own surface continues behind it —
/// and the title colour comes from the [PureTheme] tokens, so the strip reads
/// correctly in both brightnesses. The traffic-light controls use Flutter
/// widgets, keeping this presentation independent of platform-specific window
/// management plugins.
class PureMacOSTitleBar extends StatelessWidget {
  /// Creates a macOS-style title bar.
  const new({
    required this.labels,
    required this.actions,
    required this.isMaximized,
    required this.onToggleMaximize,
    this.metrics = const PureCaptionMetrics.macos(),
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
          const SizedBox(width: 13),
          _TrafficLightButton(
            color: const Color(0xFFFF5F57),
            tooltip: labels.close,
            semanticLabel: labels.close,
            onPressed: actions.close,
            key: const ValueKey('title-close'),
          ),
          const SizedBox(width: 8),
          _TrafficLightButton(
            color: const Color(0xFFFFBD2E),
            tooltip: labels.minimize,
            semanticLabel: labels.minimize,
            onPressed: actions.minimize,
            key: const ValueKey('title-minimize'),
          ),
          const SizedBox(width: 8),
          _TrafficLightButton(
            color: const Color(0xFF28C840),
            tooltip: isMaximized ? labels.restore : labels.maximize,
            semanticLabel: isMaximized ? labels.restore : labels.maximize,
            onPressed: onToggleMaximize,
            key: const ValueKey('title-maximize'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PureTitleBarDragRegion(
              title: labels.title,
              startDragging: actions.startDragging,
              titleStyle: theme.textTheme.titleSmall?.copyWith(color: colors.text),
              onDoubleTap: onToggleMaximize,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Draws a single macOS traffic-light control.
class _TrafficLightButton extends StatelessWidget {
  const new({
    required this.color,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final Color color;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: SizedBox(
          width: 20,
          height: 28,
          child: Center(
            child: Material(
              color: color,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: const SizedBox.square(dimension: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
