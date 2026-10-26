import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveSite;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/settings/local_interaction_settings.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;

/// The local-interaction settings page (the reference's 设置 → 本机互动):
/// the master switch, the local identity and economy, what local messages
/// show, the preview platform, the six danmaku looks with every style field
/// and its live preview, and the history with its two clears.
final class LocalInteractionPane extends ConsumerWidget {
  /// The pane.
  const LocalInteractionPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final local = ref.watch(localInteractionProvider);
    final controller = ref.read(localInteractionProvider.notifier);
    final style = local.style;
    final sites = ref.watch(sitesProvider).all;
    final previewSite = sites.where((site) => site.manifest.id == local.previewPlatform).firstOrNull;
    final previewPlatformName = previewSite == null ? local.previewPlatform : localizedSiteName(previewSite);

    LocalDanmakuStyle edit({
      int? color,
      double? fontSize,
      double? speed,
      int? fontWeight,
      bool? showStroke,
      double? strokeWidth,
      String? placement,
      String? fontFamily,
      bool? italic,
      double? opacity,
      double? letterSpacing,
      int? strokeColor,
      bool? showShadow,
      int? shadowColor,
      double? shadowBlur,
      double? shadowOffset,
      int? fixedDurationMs,
    }) => (
      preset: style.preset,
      color: color ?? style.color,
      fontSize: fontSize ?? style.fontSize,
      speed: speed ?? style.speed,
      fontWeight: fontWeight ?? style.fontWeight,
      showStroke: showStroke ?? style.showStroke,
      strokeWidth: strokeWidth ?? style.strokeWidth,
      placement: placement ?? style.placement,
      fontFamily: fontFamily ?? style.fontFamily,
      italic: italic ?? style.italic,
      opacity: opacity ?? style.opacity,
      letterSpacing: letterSpacing ?? style.letterSpacing,
      strokeColor: strokeColor ?? style.strokeColor,
      showShadow: showShadow ?? style.showShadow,
      shadowColor: shadowColor ?? style.shadowColor,
      shadowBlur: shadowBlur ?? style.shadowBlur,
      shadowOffset: shadowOffset ?? style.shadowOffset,
      fixedDurationMs: fixedDurationMs ?? style.fixedDurationMs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.localInteractionTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.messageCircle),
              title: t.settings.localEnabled,
              description: t.settings.localEnabledDesc,
              control: DsSwitch(
                value: local.enabled,
                onChanged: (value) => unawaited(controller.setEnabled(value: value)),
              ),
            ),
            if (local.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
                child: Text(
                  t.settings.localStatusValue(
                    coins: '${local.coins}',
                    experience: '${local.experience}',
                    level: '${controller.level}',
                  ),
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              ),
          ],
        ),
        if (local.enabled) ...[
          DsListSection(
            header: Text(t.settings.localIdentity),
            children: [
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.userRound),
                title: t.settings.localUserName,
                description: t.settings.localUserNameDesc,
                controlWidth: 260,
                control: DsTextField(
                  initialValue: local.userName,
                  clearable: true,
                  placeholder: t.settings.localUserName,
                  onChanged: (value) => unawaited(controller.setUserName(value)),
                  semanticLabel: t.settings.localUserName,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.tag),
                title: t.settings.localTitle,
                description: t.settings.localTitleDesc,
                controlWidth: 260,
                control: DsTextField(
                  initialValue: local.title,
                  clearable: true,
                  placeholder: t.settings.localTitle,
                  onChanged: (value) => unawaited(controller.setTitle(value)),
                  semanticLabel: t.settings.localTitle,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.coins),
                title: t.settings.localCoins,
                description: t.settings.localCoinsDesc,
                controlWidth: 160,
                control: DsNumberField(
                  value: local.coins,
                  min: 0,
                  max: 9999999,
                  semanticLabel: t.settings.localCoins,
                  onChanged: (value) {
                    if (value != null) unawaited(controller.setCoins(value.round()));
                  },
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.activity),
                title: t.settings.localExperience,
                description: t.settings.localExperienceDesc,
                controlWidth: 160,
                control: DsNumberField(
                  value: local.experience,
                  min: 0,
                  max: 9999999,
                  semanticLabel: t.settings.localExperience,
                  onChanged: (value) {
                    if (value != null) unawaited(controller.setExperience(value.round()));
                  },
                ),
              ),
            ],
          ),
          DsListSection(
            header: Text(t.settings.localInteractionTitle),
            children: [
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.captions),
                title: t.settings.localShowAsDanmaku,
                description: t.settings.localShowAsDanmakuDesc,
                control: DsSwitch(
                  value: local.showAsDanmaku,
                  onChanged: (value) => unawaited(controller.setFlag('showAsDanmaku', value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.badgeCheck),
                title: t.settings.localShowPlatformBadge,
                description: t.settings.localShowPlatformBadgeDesc,
                control: DsSwitch(
                  value: local.showPlatformBadge,
                  onChanged: (value) => unawaited(controller.setFlag('showPlatformBadge', value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.layers),
                title: t.settings.localShowLevelBadge,
                description: t.settings.localShowLevelBadgeDesc,
                control: DsSwitch(
                  value: local.showLevelBadge,
                  onChanged: (value) => unawaited(controller.setFlag('showLevelBadge', value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.sparkles),
                title: t.settings.localGiftEffects,
                description: t.settings.localGiftEffectsDesc,
                control: DsSwitch(
                  value: local.enableGiftEffects,
                  onChanged: (value) => unawaited(controller.setFlag('enableGiftEffects', value: value)),
                ),
              ),
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.antenna),
                title: t.settings.localPreviewPlatform,
                description: t.settings.localPreviewPlatformDesc,
                value: local.previewPlatform,
                options: [
                  for (final LiveSite site in sites)
                    DsSelectOption(value: site.manifest.id, label: localizedSiteName(site)),
                ],
                onChanged: (value) => unawaited(controller.setPreviewPlatform(value)),
              ),
            ],
          ),
          DsListSection(
            header: Text(t.settings.localStyle),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s8,
                  children: [
                    DsChoiceChips<String?>(
                      value: kLocalDanmakuPresets.any((preset) => preset.id == style.preset) ? style.preset : null,
                      semanticLabel: t.settings.localStyle,
                      onChanged: (id) {
                        if (id == null) return;
                        final preset = kLocalDanmakuPresets.firstWhere((value) => value.id == id);
                        unawaited(controller.applyPreset(preset));
                      },
                      options: [
                        DsChipOption(value: 'clean', label: Text(t.settings.localPresetClean)),
                        DsChipOption(value: 'highlight', label: Text(t.settings.localPresetHighlight)),
                        DsChipOption(value: 'neon', label: Text(t.settings.localPresetNeon)),
                        DsChipOption(value: 'minimal', label: Text(t.settings.localPresetMinimal)),
                        DsChipOption(value: 'caption', label: Text(t.settings.localPresetCaption)),
                        DsChipOption(value: 'cyber', label: Text(t.settings.localPresetCyber)),
                      ],
                    ),
                    if (!kLocalDanmakuPresets.any((preset) => preset.id == style.preset))
                      Text(
                        t.settings.localPresetCustom,
                        style: theme.typography.small.copyWith(color: colors.textMuted),
                      ),
                    Text(t.settings.localStyleDesc, style: theme.typography.small.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              _StyleSlider(
                icon: DsIcons.type,
                title: t.settings.localFontSize,
                value: style.fontSize,
                min: 10,
                max: 40,
                display: '${style.fontSize.toStringAsFixed(0)} px',
                onChanged: (value) => unawaited(controller.setStyle(edit(fontSize: value))),
              ),
              _StyleSlider(
                icon: DsIcons.wind,
                title: t.settings.localSpeed,
                value: style.speed,
                min: 40,
                max: 300,
                display: '${style.speed.round()} px/s',
                onChanged: (value) => unawaited(controller.setStyle(edit(speed: value))),
              ),
              _StyleSlider(
                icon: DsIcons.bold,
                title: t.settings.localWeight,
                value: style.fontWeight.toDouble(),
                min: 100,
                max: 900,
                divisions: 8,
                display: '${style.fontWeight}',
                onChanged: (value) => unawaited(controller.setStyle(edit(fontWeight: value.round()))),
              ),
              _StyleSlider(
                icon: DsIcons.circle,
                title: t.settings.localOpacity,
                value: style.opacity,
                display: '${(style.opacity * 100).round()}%',
                onChanged: (value) => unawaited(controller.setStyle(edit(opacity: value))),
              ),
              _StyleSlider(
                icon: DsIcons.letterSpacing,
                title: t.settings.localLetterSpacing,
                value: style.letterSpacing,
                min: -2,
                max: 8,
                display: '${style.letterSpacing.toStringAsFixed(1)} px',
                onChanged: (value) => unawaited(controller.setStyle(edit(letterSpacing: value))),
              ),
              _StyleSlider(
                icon: DsIcons.square,
                title: t.settings.localStrokeWidth,
                value: style.strokeWidth,
                max: 4,
                display: '${style.strokeWidth.toStringAsFixed(1)} px',
                onChanged: style.showStroke
                    ? (value) => unawaited(controller.setStyle(edit(strokeWidth: value)))
                    : null,
              ),
              _StyleSlider(
                icon: DsIcons.timer,
                title: t.settings.localFixedDuration,
                value: style.fixedDurationMs.toDouble(),
                min: 1000,
                max: 10000,
                divisions: 18,
                display: '${(style.fixedDurationMs / 1000).toStringAsFixed(1)} s',
                onChanged: (value) => unawaited(controller.setStyle(edit(fixedDurationMs: value.round()))),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.baseline),
                title: t.settings.localShowStroke,
                control: DsSwitch(
                  value: style.showStroke,
                  onChanged: (value) => unawaited(controller.setStyle(edit(showStroke: value))),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.italic),
                title: t.settings.localItalic,
                control: DsSwitch(
                  value: style.italic,
                  onChanged: (value) => unawaited(controller.setStyle(edit(italic: value))),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.layers),
                title: t.settings.localShowShadow,
                control: DsSwitch(
                  value: style.showShadow,
                  onChanged: (value) => unawaited(controller.setStyle(edit(showShadow: value))),
                ),
              ),
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.moveVertical),
                title: t.settings.localPlacement,
                value: style.placement,
                options: [
                  DsSelectOption(value: LocalDanmakuPlacement.scroll, label: t.settings.localPlacementScroll),
                  DsSelectOption(value: LocalDanmakuPlacement.top, label: t.settings.localPlacementTop),
                  DsSelectOption(value: LocalDanmakuPlacement.bottom, label: t.settings.localPlacementBottom),
                ],
                onChanged: (value) => unawaited(controller.setStyle(edit(placement: value))),
              ),
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.type),
                title: t.settings.localFontFamily,
                value: style.fontFamily,
                options: [
                  DsSelectOption(value: 'system', label: t.settings.localFontSystem),
                  DsSelectOption(value: 'mono', label: t.settings.localFontMono),
                ],
                onChanged: (value) => unawaited(controller.setStyle(edit(fontFamily: value))),
              ),
              _ColorRow(
                title: t.settings.localTextColor,
                value: style.color,
                onChanged: (value) => unawaited(controller.setStyle(edit(color: value))),
              ),
              _ColorRow(
                title: t.settings.localStrokeColor,
                value: style.strokeColor,
                onChanged: (value) => unawaited(controller.setStyle(edit(strokeColor: value))),
              ),
              _ColorRow(
                title: t.settings.localShadowColor,
                value: style.shadowColor,
                onChanged: (value) => unawaited(controller.setStyle(edit(shadowColor: value))),
              ),
              _StyleSlider(
                icon: DsIcons.sparkles,
                title: t.settings.localShadowBlur,
                value: style.shadowBlur,
                max: 12,
                display: style.shadowBlur.toStringAsFixed(1),
                onChanged: style.showShadow
                    ? (value) => unawaited(controller.setStyle(edit(shadowBlur: value)))
                    : null,
              ),
              _StyleSlider(
                icon: DsIcons.move,
                title: t.settings.localShadowOffset,
                value: style.shadowOffset,
                max: 8,
                display: style.shadowOffset.toStringAsFixed(1),
                onChanged: style.showShadow
                    ? (value) => unawaited(controller.setStyle(edit(shadowOffset: value)))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpace.s16),
                child: _LocalPreview(
                  local: local,
                  level: controller.level,
                  platformName: previewPlatformName,
                ),
              ),
            ],
          ),
          DsListSection(
            header: Text(t.settings.localHistory),
            children: [
              if (local.history.isEmpty)
                DsListRow(leading: const DsIcon(DsIcons.history), title: Text(t.settings.localHistoryEmpty))
              else
                for (final line in local.history.reversed.take(5))
                  DsListRow(leading: const DsIcon(DsIcons.history), title: Text(line)),
              DsListRow(
                leading: const DsIcon(DsIcons.trash2),
                title: Text(t.settings.localClearHistory),
                description: Text(t.settings.localClearHistoryDesc),
                onPressed: () => unawaited(controller.clearHistory()),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.rotateCcw),
                title: Text(t.settings.localClearAll),
                description: Text(t.settings.localClearAllDesc),
                destructive: true,
                onPressed: () async {
                  final confirmed = await showDsConfirm(
                    context: context,
                    title: t.settings.localClearAllConfirm,
                    description: t.settings.localClearAllConfirmDesc,
                    confirmLabel: t.settings.localClearAll,
                    cancelLabel: t.common.cancel,
                    destructive: true,
                    icon: const DsIcon(DsIcons.trash2),
                  );
                  if (!confirmed) return;
                  await controller.clearHistoryAndEconomy();
                  if (!context.mounted) return;
                  showDsToast(context: context, title: t.settings.localCleared);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One style row: slider, current value and semantics.
final class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.icon,
    required this.title,
    required this.value,
    required this.display,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final DsIconData icon;
  final String title;
  final double value;
  final String display;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SettingsConfigRow(
      leading: DsIcon(icon),
      title: title,
      detail: Text(display),
      controlWidth: 220,
      control: DsSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        semanticLabel: title,
        semanticFormatter: (value) => display,
      ),
    );
  }
}

/// One colour row over the shared palette.
final class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.title, required this.value, required this.onChanged});

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          Text(title, style: DsTheme.of(context).typography.body.copyWith(color: colors.text)),
          DsChoiceChips<int?>(
            value: kLocalDanmakuColors.contains(value) ? value : null,
            semanticLabel: title,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
            options: [
              for (final color in kLocalDanmakuColors)
                DsChipOption(
                  value: color,
                  label: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The styled local message: every style key (size, weight, italic, spacing,
/// colours, outline, shadow, opacity, placement and typeface) has a visible
/// effect here.
final class _LocalPreview extends StatelessWidget {
  const _LocalPreview({required this.local, required this.level, required this.platformName});

  final LocalInteractionState local;
  final int level;
  final String platformName;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = local.style;
    final badges = [
      if (local.showLevelBadge) 'Lv.$level',
      if (local.showPlatformBadge) platformName,
    ];
    final text = [
      if (badges.isNotEmpty) '[${badges.join(' · ')}]',
      '${local.title} · ${local.userName}',
      context.t.settings.localPreviewText,
    ].join(' ');
    final base = TextStyle(
      fontSize: style.fontSize,
      fontWeight: FontWeight(style.fontWeight.clamp(100, 900)),
      fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: style.letterSpacing,
      fontFamily: style.fontFamily == 'mono' ? 'monospace' : null,
      color: Color(style.color),
      shadows: style.showShadow
          ? [
              Shadow(
                color: Color(style.shadowColor),
                blurRadius: style.shadowBlur,
                offset: Offset(style.shadowOffset, style.shadowOffset),
              ),
            ]
          : null,
    );
    final stroke = base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth
        ..color = Color(style.strokeColor),
    );
    return Container(
      height: 104,
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: DsBoxDecoration(
        color: colors.channel,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: [DsShadow.innerRing(colors.border)],
      ),
      child: Stack(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('${style.speed}-${style.placement}-${style.fixedDurationMs}'),
            tween: Tween(begin: 0, end: 1),
            duration: style.placement == LocalDanmakuPlacement.scroll
                ? Duration(milliseconds: (2400 * 130 / style.speed).round())
                : Duration(milliseconds: style.fixedDurationMs),
            builder: (context, progress, child) => Align(
              alignment: style.placement == LocalDanmakuPlacement.scroll
                  ? Alignment(-1 + 2 * progress, 0)
                  : switch (style.placement) {
                      LocalDanmakuPlacement.top => Alignment.topCenter,
                      LocalDanmakuPlacement.bottom => Alignment.bottomCenter,
                      _ => Alignment.centerLeft,
                    },
              child: Opacity(opacity: style.opacity.clamp(0, 1), child: child),
            ),
            child: Stack(
              children: [
                if (style.showStroke && style.strokeWidth > 0) Text(text, style: stroke, maxLines: 2),
                Text(text, style: base, maxLines: 2),
              ],
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Text(
              '${(style.fixedDurationMs / 1000).toStringAsFixed(1)} s',
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      ),
    );
  }
}
