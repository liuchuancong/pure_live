import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart'
    show
        DanmakuStyleRange,
        SettingsConfigRow,
        danmakuStyleProvider,
        kDanmakuMassModeMaxVisibleCount,
        playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';

/// The preview's danmaku panel: the same stored style every player draws
/// with, reduced to the knobs a viewer moves while watching — whether the
/// layer shows, how it looks and how busy it is — with the way into the
/// shield rules below them.
///
/// It writes through [danmakuStyleProvider] and the shared danmaku switch, so
/// a change here bites on this page at once and everywhere else the layer
/// draws; the panel adds no preference of its own.
final class MediaPreviewDanmakuPanel extends ConsumerWidget {
  /// The panel for an entry that has ([hasDanmaku]) or lacks a danmaku file.
  const MediaPreviewDanmakuPanel({
    required this.hasDanmaku,
    required this.onClose,
    required this.onOpenRules,
    super.key,
  });

  /// Whether the entry on the stage has a readable danmaku timeline; without
  /// one the switch stays visible but out of reach, and says why.
  final bool hasDanmaku;

  /// Leaves the panel for whatever it covered.
  final VoidCallback onClose;

  /// Leaves the preview for the shield rules, which live in Settings.
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final visible = ref.watch(playbackSettingsProvider.select((settings) => settings.danmakuVisible));
    final playback = ref.read(playbackSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.common.back,
                onPressed: onClose,
                icon: const DsIcon(DsIcons.chevronLeft),
              ),
              Expanded(
                child: Text(
                  t.common.previewDanmakuSettings,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, 0, DsSpace.s16, DsSpace.s24),
            children: [
              DsListSection(
                children: [
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.captions),
                    title: t.common.previewDanmakuVisible,
                    description: hasDanmaku ? t.common.previewDanmakuVisibleDescription : t.common.previewDanmakuOff,
                    control: DsSwitch(
                      value: visible,
                      onChanged: hasDanmaku ? (value) => unawaited(playback.setDanmakuVisible(value: value)) : null,
                    ),
                  ),
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.caseSensitive),
                    title: t.settings.styleFontSize,
                    detail: Text('${style.fontSize.toStringAsFixed(1)} px'),
                    controlWidth: 180,
                    control: DsSlider(
                      value: style.fontSize,
                      min: DanmakuStyleRange.fontSizeMin,
                      max: DanmakuStyleRange.fontSizeMax,
                      onChanged: (value) => unawaited(controller.setFontSize(value)),
                      semanticLabel: t.settings.styleFontSize,
                      semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
                    ),
                  ),
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.blend),
                    title: t.settings.styleOpacity,
                    detail: Text('${(style.opacity * 100).round()}%'),
                    controlWidth: 180,
                    control: DsSlider(
                      value: style.opacity,
                      onChanged: (value) => unawaited(controller.setOpacity(value)),
                      semanticLabel: t.settings.styleOpacity,
                    ),
                  ),
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.wind),
                    title: t.settings.styleSpeed,
                    detail: Text('${style.baseSpeed.round()} px/s'),
                    controlWidth: 180,
                    control: DsSlider(
                      value: style.baseSpeed,
                      min: DanmakuStyleRange.speedMin,
                      max: DanmakuStyleRange.speedMax,
                      onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
                      semanticLabel: t.settings.styleSpeed,
                      semanticFormatter: (value) => '${value.round()} px/s',
                    ),
                  ),
                  // Mass mode takes the same-screen count over; the row stays
                  // in place so its absence never reads as a bug.
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.list),
                    title: t.settings.styleMaxVisible,
                    description: style.massMode ? t.settings.styleMassModeDesc : null,
                    detail: Text(
                      t.settings.styleMaxVisibleValue(
                        count: '${style.massMode ? kDanmakuMassModeMaxVisibleCount : style.maxVisibleCount}',
                      ),
                    ),
                    controlWidth: 180,
                    control: DsSlider(
                      value: style.maxVisibleCount.toDouble(),
                      min: DanmakuStyleRange.maxVisibleMin.toDouble(),
                      max: DanmakuStyleRange.maxVisibleMax.toDouble(),
                      divisions: DanmakuStyleRange.maxVisibleDivisions,
                      onChanged: style.massMode
                          ? null
                          : (value) => unawaited(controller.setMaxVisibleCount(value.round())),
                      semanticLabel: t.settings.styleMaxVisible,
                      semanticFormatter: (value) => t.settings.styleMaxVisibleValue(count: '${value.round()}'),
                    ),
                  ),
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.moveVertical),
                    title: t.settings.styleArea,
                    detail: Text('${(style.area * 100).round()}%'),
                    controlWidth: 180,
                    control: DsSlider(
                      value: style.area,
                      divisions: DanmakuStyleRange.areaDivisions,
                      onChanged: (value) => unawaited(controller.setArea(value)),
                      semanticLabel: t.settings.styleArea,
                    ),
                  ),
                  SettingsConfigRow(
                    leading: const DsIcon(DsIcons.typeOutline),
                    title: t.settings.styleStroke,
                    control: DsSwitch(
                      value: style.showStroke,
                      onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.s16),
              DsListSection(
                children: [
                  DsListRow(
                    leading: const DsIcon(DsIcons.shield),
                    title: Text(t.shield.title),
                    description: Text(t.settings.shieldDescription),
                    showChevron: true,
                    onPressed: onOpenRules,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
