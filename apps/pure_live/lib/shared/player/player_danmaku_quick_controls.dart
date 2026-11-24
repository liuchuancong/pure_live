import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart'
    show DanmakuStyleRange, danmakuStyleProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/player/on_video_colors.dart';

/// The players' compact danmaku settings: display area, font size, opacity
/// and speed. Everything else waits behind [onAdvanced].
///
/// The live room's bar hangs the same four sliders over its own gear; this
/// is the shared form every other player's gear opens, so the pair reads as
/// one control across the app — the sliders speak in the accent ink over
/// the picture's dark plate, the way the room's do.
final class PlayerDanmakuQuickControls extends ConsumerWidget {
  /// The controls; [onAdvanced] opens the full danmaku settings.
  const PlayerDanmakuQuickControls({required this.onWake, required this.onAdvanced, super.key});

  /// Runs as the viewer touches a slider: the host's own wake, so the
  /// chrome stays up while the sliders move.
  final VoidCallback onWake;

  /// Leaves the player for the full danmaku settings.
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final labelStyle = theme.typography.caption.copyWith(color: OnVideoColors.inkMuted);
    final valueStyle = theme.typography.caption.copyWith(color: OnVideoColors.foreground);
    final sliderStyle = DsSliderStyle(
      trackColor: OnVideoColors.inkHover,
      fillColor: colors.accent,
      thumbColor: colors.accent,
      tickColor: OnVideoColors.inkMuted,
      tickFilledColor: colors.accent,
    );
    Widget sliderRow({
      required String label,
      required String value,
      required double current,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      int? divisions,
      String Function(double)? formatter,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s4,
      children: [
        Row(
          children: [
            Text(label, style: labelStyle),
            const Spacer(),
            Text(value, style: valueStyle),
          ],
        ),
        DsSlider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          semanticFormatter: formatter,
          style: sliderStyle,
          onChanged: (next) {
            onWake();
            onChanged(next);
          },
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        sliderRow(
          label: t.settings.styleArea,
          value: '${(style.area * 100).round()}%',
          current: style.area,
          min: DanmakuStyleRange.areaMin,
          max: DanmakuStyleRange.areaMax,
          divisions: DanmakuStyleRange.areaDivisions,
          onChanged: (value) => unawaited(controller.setArea(value)),
        ),
        sliderRow(
          label: t.settings.styleFontSize,
          value: '${style.fontSize.toStringAsFixed(0)} px',
          current: style.fontSize,
          min: DanmakuStyleRange.fontSizeMin,
          max: DanmakuStyleRange.fontSizeMax,
          onChanged: (value) => unawaited(controller.setFontSize(value)),
        ),
        sliderRow(
          label: t.settings.styleOpacity,
          value: '${(style.opacity * 100).round()}%',
          current: style.opacity,
          min: DanmakuStyleRange.opacityMin,
          max: DanmakuStyleRange.opacityMax,
          onChanged: (value) => unawaited(controller.setOpacity(value)),
        ),
        sliderRow(
          label: t.settings.styleSpeed,
          value: '${style.baseSpeed.round()} px/s',
          current: style.baseSpeed,
          min: DanmakuStyleRange.speedMin,
          max: DanmakuStyleRange.speedMax,
          onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
        ),
        Container(height: 1, color: OnVideoColors.inkHover),
        DsPressable(
          semanticLabel: t.settings.styleAdvanced,
          onPressed: onAdvanced,
          builder: (context, states, _) => Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
            decoration: DsBoxDecoration(
              color: states.contains(WidgetState.hovered) ? OnVideoColors.inkHover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                const DsIcon(DsIcons.settings2, size: 15, color: OnVideoColors.inkMuted),
                Text(t.settings.styleAdvanced, style: theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
                const Spacer(),
                const DsIcon(DsIcons.chevronRight, size: 14, color: OnVideoColors.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
