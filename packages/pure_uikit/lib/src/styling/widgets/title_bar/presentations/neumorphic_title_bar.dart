import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_actions.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_caption_button.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_drag_region.dart';
import 'package:pure_uikit/src/styling/widgets/title_bar/pure_title_bar_types.dart';

/// Renders a Neumorphic-inspired desktop title bar.
///
/// The strip paints nothing — only the style's two edge shadows fall on the
/// window's own surface — and every colour comes from the [PureTheme] tokens,
/// so the strip reads correctly in both brightnesses. Window operations are
/// injected by the application Shell.
class PureNeumorphicTitleBar extends StatelessWidget {
  /// Creates a Neumorphic-inspired title bar.
  const new({
    required this.labels,
    required this.actions,
    required this.isMaximized,
    required this.onToggleMaximize,
    this.metrics = const PureCaptionMetrics(titleBarHeight: 38, buttonWidth: 40, buttonHeight: 38),
    this.leading,
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

  /// The mark drawn before the title — the app's own brand.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = PureTheme.of(context).colors;
    final shadowColor = colors.shadowBase.withValues(alpha: 0.35);
    final highlightColor = colors.white.withValues(alpha: colors.bgLayout.computeLuminance() < 0.5 ? 0.06 : 0.85);

    return DecoratedBox(
      decoration: BoxDecoration(
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
                leading: leading,
                startDragging: actions.startDragging,
                titleStyle: theme.textTheme.titleSmall?.copyWith(color: colors.text, fontWeight: FontWeight.w600),
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
              foregroundColor: colors.text,
              hoverColor: colors.fillTertiary,
              borderRadius: BorderRadius.circular(8),
              onPressed: actions.minimize,
            ),
            PureTitleBarCaptionButton(
              buttonKey: const ValueKey('title-maximize'),
              icon: isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: isMaximized ? labels.restore : labels.maximize,
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              foregroundColor: colors.text,
              hoverColor: colors.fillTertiary,
              borderRadius: BorderRadius.circular(8),
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
