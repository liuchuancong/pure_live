import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart'
    show BarrageItemMapper, DanmakuColor, DanmakuMessage, DanmakuMessageType, DanmakuPlacement, DanmakuStyle;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/danmaku/chat_display_settings.dart'
    show
        chatGiftValueInYuanProvider,
        chatGiftsAboveTierProvider,
        chatListFontSizeProvider,
        chatListLineSpacingProvider,
        chatNamesProvider,
        chatPanelWidthProvider,
        chatShowGiftsProvider,
        kChatPanelWidthMax,
        kChatPanelWidthMin;
import 'package:pure_live/features/settings/danmaku/danmaku_fixed_providers.dart'
    show
        danmakuFixedBottomProvider,
        danmakuFixedDurationProvider,
        danmakuFixedTopProvider,
        kDanmakuFixedDurationMax,
        kDanmakuFixedDurationMin;
import 'package:pure_live/features/settings/danmaku/danmaku_hold_provider.dart' show danmakuHoldProvider;
import 'package:pure_live/features/settings/danmaku/danmaku_show_gifts_provider.dart' show danmakuShowGiftsProvider;
// The app's DanmakuStyle record and media_core's per-message override share a
// name; the engine's one is the one this page builds sample messages with.
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart' hide DanmakuStyle;
import 'package:pure_live/features/settings/danmaku/super_chat_settings.dart' show superChatIncludesMembershipProvider;
import 'package:pure_live/features/settings/pages/font_manager_page.dart' show fontFamilyLabel, showFontManagerPage;
import 'package:pure_live/features/settings/playback/pip_danmaku_scale_provider.dart'
    show kPipDanmakuScaleMax, kPipDanmakuScaleMin, pipDanmakuScaleProvider;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/surface/settings_page.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_preview.dart';
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/player/room_barrage_config.dart' show roomBarrageConfig;
import 'package:pure_live/shared/danmaku/danmaku.dart' show DanmakuFormat, danmakuSaveFormatsProvider;

/// The danmaku settings: this page is the switch and the interaction of the
/// flying layer, the full-window preview holds every knob of how a danmaku
/// looks, and [DanmakuDisplayPane] is the chat list beside the picture. The
/// shield keeps its own page under this one.
final class DanmakuPane extends ConsumerWidget {
  /// The pane.
  const DanmakuPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final playback = ref.watch(playbackSettingsProvider);
    final family = ref.watch(danmakuStyleProvider).fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.captions),
              title: t.settings.showFlyingDanmaku,
              description: t.settings.showFlyingDanmakuDesc,
              control: DsSwitch(
                value: playback.danmakuVisible,
                onChanged: (value) =>
                    unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pause),
              title: t.settings.danmakuPausedBehavior,
              description: t.settings.danmakuPausedBehaviorDesc,
              control: DsSwitch(
                value: ref.watch(danmakuPausedBehaviorProvider) == DanmakuPausedBehavior.fly,
                onChanged: (value) => unawaited(
                  ref
                      .read(danmakuPausedBehaviorProvider.notifier)
                      .set(value ? DanmakuPausedBehavior.fly : DanmakuPausedBehavior.pause),
                ),
              ),
            ),
          ],
        ),
        // The face is chosen in the font manager: the catalogue holds a few
        // thousand families, far more than a dropdown can carry. The row sits
        // on this page rather than the preview's, because the manager opens
        // under the settings surface the preview covers.
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.danmakuFont),
              description: Text(t.settings.danmakuFontDescription),
              detail: Text(fontFamilyLabel(t, family, name: ref.watch(freeFontStoreProvider).nameOf(family))),
              showChevron: true,
              onPressed: () => showFontManagerPage(context, ref, danmaku: true),
            ),
          ],
        ),
        // The master switch above decides whether the layer draws; the
        // sample sits right under it so the answer to "on" is visible.
        const DanmakuPreviewEntry(),
        DsListSection(
          header: Text(t.settings.danmakuInteractionGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pointer),
              title: t.settings.styleTapInteraction,
              description: t.settings.styleTapInteractionDesc,
              control: DsSwitch(
                value: ref.watch(danmakuTapInteractionProvider),
                onChanged: (value) => unawaited(ref.read(danmakuTapInteractionProvider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.hand),
              title: t.settings.styleLongPressInteraction,
              description: t.settings.styleLongPressInteractionDesc,
              control: DsSwitch(
                value: ref.watch(danmakuLongPressInteractionProvider),
                onChanged: (value) =>
                    unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.lock),
              title: t.settings.holdDanmakuOnPress,
              description: t.settings.holdDanmakuOnPressDesc,
              control: DsSwitch(
                value: ref.watch(danmakuHoldProvider),
                onChanged: (value) => unawaited(ref.read(danmakuHoldProvider.notifier).set(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.danmakuSaveGroup),
          children: [
            for (final format in DanmakuFormat.values)
              SettingsConfigRow(
                leading: DsIcon(_saveFormatIcon(format)),
                title: format.label(t),
                control: DsSwitch(
                  value: ref.watch(danmakuSaveFormatsProvider).contains(format),
                  onChanged: (_) => unawaited(ref.read(danmakuSaveFormatsProvider.notifier).toggle(format)),
                ),
              ),
          ],
        ),
        SettingsHint(t.settings.danmakuSaveDescription),
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.danmakuDisplay),
            SettingsChildEntry(child: SettingsSection.shield),
          ],
        ),
      ],
    );
  }
}

/// Every control of the flying layer, in the order the preview page groups
/// them. The preview is the only page that tunes them, so the rows keep only
/// their names: the sidebar is too narrow for the explanations.
final class DanmakuStyleSettings extends ConsumerStatefulWidget {
  /// The controls.
  const DanmakuStyleSettings({super.key});

  @override
  ConsumerState<DanmakuStyleSettings> createState() => _DanmakuStyleSettingsState();
}

final class _DanmakuStyleSettingsState extends ConsumerState<DanmakuStyleSettings> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final playback = ref.watch(playbackSettingsProvider);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final frameRate = ref.watch(danmakuFrameRateProvider);
    final frameRateController = ref.read(danmakuFrameRateProvider.notifier);
    final effectiveFps = ref.watch(danmakuEffectiveFpsProvider);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final pipScaleController = ref.read(pipDanmakuScaleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // The way back out of any wrong turn sits at the very top as a
        // button, not as one more row to scroll past: the viewer who came
        // here to undo a change finds it without looking.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.rotateCw, size: 16),
            onPressed: () {
              unawaited(controller.reset());
              unawaited(frameRateController.reset());
              unawaited(ref.read(danmakuFixedTopProvider.notifier).reset());
              unawaited(ref.read(danmakuFixedBottomProvider.notifier).reset());
              unawaited(ref.read(danmakuFixedDurationProvider.notifier).reset());
              unawaited(ref.read(danmakuTapInteractionProvider.notifier).reset());
              unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).reset());
              unawaited(pipScaleController.reset());
            },
            child: Text(t.settings.styleReset),
          ),
        ),
        DsListSection(
          header: Text(t.settings.danmakuStyleGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.caseSensitive),
              title: t.settings.styleFontSize,
              detail: Text('${style.fontSize.toStringAsFixed(1)} px'),
              controlWidth: 220,
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
              leading: const DsIcon(DsIcons.bold),
              title: t.settings.styleFontWeight,
              detail: Text(danmakuFontWeightLabel(t, style.fontWeight)),
              controlWidth: 220,
              control: DsSlider(
                value: style.fontWeight.toDouble(),
                min: DanmakuStyleRange.fontWeightMin.toDouble(),
                max: DanmakuStyleRange.fontWeightMax.toDouble(),
                divisions: DanmakuStyleRange.fontWeightDivisions,
                onChanged: (value) => unawaited(controller.setFontWeight(value.round())),
                semanticLabel: t.settings.styleFontWeight,
                semanticFormatter: (value) => danmakuFontWeightLabel(t, value.round()),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.italic),
              title: t.settings.styleItalic,
              control: DsSwitch(
                value: style.italic,
                onChanged: (value) => unawaited(controller.setItalic(value: value)),
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.palette),
              title: t.settings.styleTextColor,
              value: style.textColor,
              options: _colorOptions(t),
              onChanged: (value) => unawaited(controller.setTextColor(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.letterSpacing),
              title: t.settings.styleLetterSpacing,
              detail: Text('${style.letterSpacing.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.letterSpacing,
                min: DanmakuStyleRange.letterSpacingMin,
                max: DanmakuStyleRange.letterSpacingMax,
                onChanged: (value) => unawaited(controller.setLetterSpacing(value)),
                semanticLabel: t.settings.styleLetterSpacing,
                semanticFormatter: (value) => '${style.letterSpacing.toStringAsFixed(1)} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wind),
              title: t.settings.styleSpeed,
              detail: Text('${style.baseSpeed.round()} px/s'),
              controlWidth: 220,
              control: DsSlider(
                value: style.baseSpeed,
                min: DanmakuStyleRange.speedMin,
                max: DanmakuStyleRange.speedMax,
                onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
                semanticLabel: t.settings.styleSpeed,
                semanticFormatter: (value) => '${value.round()} px/s',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.styleArea,
              detail: Text('${(style.area * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.area,
                divisions: DanmakuStyleRange.areaDivisions,
                onChanged: (value) => unawaited(controller.setArea(value)),
                semanticLabel: t.settings.styleArea,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpToLine),
              title: t.settings.styleTopMargin,
              detail: Text('${style.topMargin.round()} px'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.topMargin.round(),
                min: DanmakuStyleRange.topMarginMin,
                max: DanmakuStyleRange.topMarginMax,
                semanticLabel: t.settings.styleTopMargin,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setTopMargin(value));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowDownToLine),
              title: t.settings.styleBottomMargin,
              detail: Text('${style.bottomMargin.round()} px'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.bottomMargin.round(),
                min: DanmakuStyleRange.bottomMarginMin,
                max: DanmakuStyleRange.bottomMarginMax,
                semanticLabel: t.settings.styleBottomMargin,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setBottomMargin(value));
                },
              ),
            ),
            // The engine's two pinned lanes, which the area and margins above
            // do not cover: a platform's top- or bottom-pinned message, and
            // how long one stays up.
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpToLine),
              title: t.settings.fixedTopTitle,
              control: DsSwitch(
                value: ref.watch(danmakuFixedTopProvider),
                onChanged: (value) => unawaited(ref.read(danmakuFixedTopProvider.notifier).set(value: value)),
                semanticLabel: t.settings.fixedTopTitle,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowDownToLine),
              title: t.settings.fixedBottomTitle,
              control: DsSwitch(
                value: ref.watch(danmakuFixedBottomProvider),
                onChanged: (value) => unawaited(ref.read(danmakuFixedBottomProvider.notifier).set(value: value)),
                semanticLabel: t.settings.fixedBottomTitle,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.fixedDurationTitle,
              detail: Text('${ref.watch(danmakuFixedDurationProvider).round()} s'),
              controlWidth: 220,
              control: DsSlider(
                value: ref.watch(danmakuFixedDurationProvider),
                min: kDanmakuFixedDurationMin,
                max: kDanmakuFixedDurationMax,
                divisions: (kDanmakuFixedDurationMax - kDanmakuFixedDurationMin).round(),
                onChanged: (value) => unawaited(ref.read(danmakuFixedDurationProvider.notifier).set(value)),
                semanticLabel: t.settings.fixedDurationTitle,
                semanticFormatter: (value) => '${value.round()} s',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.blend),
              title: t.settings.styleOpacity,
              detail: Text('${(style.opacity * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.opacity,
                onChanged: (value) => unawaited(controller.setOpacity(value)),
                semanticLabel: t.settings.styleOpacity,
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.penTool),
              title: t.settings.styleStrokeWidth,
              detail: Text('${style.strokeWidth.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.strokeWidth,
                max: DanmakuStyleRange.strokeWidthMax,
                // Greyed out while the outline is off, as in the reference;
                // the stored width survives for when it is switched back on.
                onChanged: style.showStroke ? (value) => unawaited(controller.setStrokeWidth(value)) : null,
                semanticLabel: t.settings.styleStrokeWidth,
                semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.paintbrush),
              title: t.settings.styleStrokeColor,
              value: style.strokeColor,
              options: _colorOptions(t),
              onChanged: (value) => unawaited(controller.setStrokeColor(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sunDim),
              title: t.settings.styleShadow,
              control: DsSwitch(
                value: style.showShadow,
                onChanged: (value) => unawaited(controller.setShowShadow(value: value)),
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.palette),
              title: t.settings.styleShadowColor,
              value: style.shadowColor,
              options: _colorOptions(t),
              onChanged: (value) => unawaited(controller.setShadowColor(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.waves),
              title: t.settings.styleShadowBlur,
              detail: Text('${style.shadowBlur.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.shadowBlur,
                max: DanmakuStyleRange.shadowBlurMax,
                onChanged: style.showShadow ? (value) => unawaited(controller.setShadowBlur(value)) : null,
                semanticLabel: t.settings.styleShadowBlur,
                semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.moveHorizontal),
              title: t.settings.styleShadowOffsetX,
              detail: Text('${style.shadowOffsetX.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.shadowOffsetX,
                min: DanmakuStyleRange.shadowOffsetMin,
                max: DanmakuStyleRange.shadowOffsetMax,
                divisions: DanmakuStyleRange.shadowOffsetDivisions,
                onChanged: style.showShadow ? (value) => unawaited(controller.setShadowOffsetX(value)) : null,
                semanticLabel: t.settings.styleShadowOffsetX,
                semanticFormatter: (value) => '${value.round()} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.styleShadowOffsetY,
              detail: Text('${style.shadowOffsetY.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.shadowOffsetY,
                min: DanmakuStyleRange.shadowOffsetMin,
                max: DanmakuStyleRange.shadowOffsetMax,
                divisions: DanmakuStyleRange.shadowOffsetDivisions,
                onChanged: style.showShadow ? (value) => unawaited(controller.setShadowOffsetY(value)) : null,
                semanticLabel: t.settings.styleShadowOffsetY,
                semanticFormatter: (value) => '${value.round()} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circleSlash),
              title: t.settings.styleNoEmoji,
              control: DsSwitch(
                value: style.noEmoji,
                onChanged: (value) => unawaited(controller.setNoEmoji(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sparkles),
              title: t.settings.styleFpsFollow,
              control: DsSwitch(
                value: frameRate.autoFps,
                onChanged: (value) => unawaited(frameRateController.setAutoFps(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.styleFps,
              detail: Text(t.settings.styleFpsValue(count: '${frameRate.autoFps ? effectiveFps : frameRate.fps}')),
              controlWidth: 220,
              control: DsSlider(
                value: (frameRate.autoFps ? effectiveFps : frameRate.fps).toDouble(),
                min: DanmakuStyleRange.fpsMin.toDouble(),
                max: DanmakuStyleRange.fpsMax.toDouble(),
                divisions: DanmakuStyleRange.fpsDivisions,
                onChanged: frameRate.autoFps ? null : (value) => unawaited(frameRateController.setFps(value.round())),
                semanticLabel: t.settings.styleFps,
                semanticFormatter: (value) => t.settings.styleFpsValue(count: '${value.round()}'),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.list),
              title: t.settings.styleMaxVisible,
              detail: Text(t.settings.styleMaxVisibleValue(count: '${style.maxVisibleCount}')),
              controlWidth: 220,
              control: DsSlider(
                value: style.maxVisibleCount.toDouble(),
                min: DanmakuStyleRange.maxVisibleMin.toDouble(),
                max: DanmakuStyleRange.maxVisibleMax.toDouble(),
                divisions: DanmakuStyleRange.maxVisibleDivisions,
                onChanged: style.massMode ? null : (value) => unawaited(controller.setMaxVisibleCount(value.round())),
                semanticLabel: t.settings.styleMaxVisible,
                semanticFormatter: (value) => t.settings.styleMaxVisibleValue(count: '${value.round()}'),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.waves),
              title: t.settings.styleMassMode,
              control: DsSwitch(
                value: style.massMode,
                onChanged: (value) => unawaited(controller.setMassMode(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gift),
              title: t.settings.danmakuShowGifts,
              control: DsSwitch(
                value: ref.watch(danmakuShowGiftsProvider),
                onChanged: (value) => unawaited(ref.read(danmakuShowGiftsProvider.notifier).set(value: value)),
              ),
            ),
          ],
        ),
        // The lanes the engine allocates and the edges it must not cross.
        DsListSection(
          header: Text(t.settings.danmakuLaneGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.styleTrackHeight,
              detail: Text('${style.trackHeight.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.trackHeight,
                min: DanmakuStyleRange.trackHeightMin,
                max: DanmakuStyleRange.trackHeightMax,
                divisions: (DanmakuStyleRange.trackHeightMax - DanmakuStyleRange.trackHeightMin).round(),
                onChanged: (value) => unawaited(controller.setTrackHeight(value)),
                semanticLabel: t.settings.styleTrackHeight,
                semanticFormatter: (value) => '${value.round()} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.faceSmile),
              title: t.settings.styleEmojiSize,
              detail: Text('${style.emojiSize.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.emojiSize,
                min: DanmakuStyleRange.emojiSizeMin,
                max: DanmakuStyleRange.emojiSizeMax,
                divisions: (DanmakuStyleRange.emojiSizeMax - DanmakuStyleRange.emojiSizeMin).round(),
                onChanged: (value) => unawaited(controller.setEmojiSize(value)),
                semanticLabel: t.settings.styleEmojiSize,
                semanticFormatter: (value) => '${value.round()} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowsLeftRightLine),
              title: t.settings.styleOverlapGap,
              detail: Text('${style.overlapSafeGap.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.overlapSafeGap,
                max: DanmakuStyleRange.overlapSafeGapMax,
                divisions: DanmakuStyleRange.overlapSafeGapMax.round(),
                onChanged: (value) => unawaited(controller.setOverlapSafeGap(value)),
                semanticLabel: t.settings.styleOverlapGap,
                semanticFormatter: (value) => '${value.round()} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.shield),
              title: t.settings.styleSafeArea,
              control: DsSwitch(
                value: style.safeArea,
                onChanged: (value) => unawaited(controller.setSafeArea(value: value)),
              ),
            ),
          ],
        ),
        // The queue the layer drains and the caches it draws from: what a
        // burst does to these decides whether a message arrives fresh or
        // late.
        DsListSection(
          header: Text(t.settings.danmakuQueueGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.list),
              title: t.settings.styleMaxPending,
              detail: Text('${style.maxPendingCount}'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.maxPendingCount,
                min: DanmakuStyleRange.maxPendingMin,
                max: DanmakuStyleRange.maxPendingMax,
                semanticLabel: t.settings.styleMaxPending,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setMaxPendingCount(value.toInt()));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.timer),
              title: t.settings.styleMaxPendingAge,
              detail: Text('${style.maxPendingAge.toStringAsFixed(0)} s'),
              controlWidth: 220,
              control: DsSlider(
                value: style.maxPendingAge,
                min: DanmakuStyleRange.maxPendingAgeMin,
                max: DanmakuStyleRange.maxPendingAgeMax,
                divisions: (DanmakuStyleRange.maxPendingAgeMax - DanmakuStyleRange.maxPendingAgeMin).round(),
                onChanged: (value) => unawaited(controller.setMaxPendingAge(value)),
                semanticLabel: t.settings.styleMaxPendingAge,
                semanticFormatter: (value) => '${value.round()} s',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.send),
              title: t.settings.styleEmitInterval,
              detail: Text('${(style.emitInterval * 1000).round()} ms'),
              controlWidth: 220,
              control: DsSlider(
                value: style.emitInterval,
                onChanged: style.massMode ? null : (value) => unawaited(controller.setEmitInterval(value)),
                semanticLabel: t.settings.styleEmitInterval,
                semanticFormatter: (value) => '${(value * 1000).round()} ms',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.image),
              title: t.settings.styleRasterize,
              control: DsSwitch(
                value: style.rasterize,
                onChanged: (value) => unawaited(controller.setRasterize(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.layers),
              title: t.settings.styleBarragePool,
              detail: Text('${style.barragePoolMaxSize}'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.barragePoolMaxSize,
                min: DanmakuStyleRange.barragePoolMin,
                max: DanmakuStyleRange.barragePoolMax,
                semanticLabel: t.settings.styleBarragePool,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setBarragePoolMaxSize(value.toInt()));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.images),
              title: t.settings.stylePictureCache,
              detail: Text('${style.pictureCacheMaxSize}'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.pictureCacheMaxSize,
                min: DanmakuStyleRange.pictureCacheMin,
                max: DanmakuStyleRange.pictureCacheMax,
                semanticLabel: t.settings.stylePictureCache,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setPictureCacheMaxSize(value.toInt()));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.styleTextCache,
              detail: Text('${style.textCacheMaxSize}'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.textCacheMaxSize,
                min: DanmakuStyleRange.textCacheMin,
                max: DanmakuStyleRange.textCacheMax,
                semanticLabel: t.settings.styleTextCache,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setTextCacheMaxSize(value.toInt()));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.database),
              title: t.settings.styleRasterCache,
              detail: Text('${style.rasterCacheMb} MB'),
              controlWidth: 220,
              control: DsNumberField(
                value: style.rasterCacheMb,
                min: DanmakuStyleRange.rasterCacheMbMin,
                max: DanmakuStyleRange.rasterCacheMbMax,
                semanticLabel: t.settings.styleRasterCache,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setRasterCacheMb(value.toInt()));
                },
              ),
            ),
          ],
        ),
        // The compact window's own layer: whether it draws danmaku at all,
        // and how large they are against the shrunken picture.
        DsListSection(
          header: Text(t.settings.navMiniDanmaku),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pictureInPicture),
              title: t.settings.miniDanmakuVisible,
              control: DsSwitch(
                value: playback.miniDanmakuVisible,
                onChanged: (value) =>
                    unawaited(ref.read(playbackSettingsProvider.notifier).setMiniDanmakuVisible(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.appWindow),
              title: t.settings.pipDanmakuScaleAuto,
              control: DsSwitch(
                value: pipScale.auto,
                onChanged: (value) => unawaited(pipScaleController.setAuto(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.scale),
              title: t.settings.pipDanmakuScale,
              detail: Text('x${pipScale.scale.toStringAsFixed(2)}'),
              controlWidth: 220,
              // The manual scale is greyed out while the auto scale owns it —
              // the row stays on screen, it only stops answering taps.
              control: DsSlider(
                value: pipScale.scale,
                min: kPipDanmakuScaleMin,
                divisions: ((kPipDanmakuScaleMax - kPipDanmakuScaleMin) / 0.01).round(),
                onChanged: pipScale.auto ? null : (value) => unawaited(pipScaleController.setScale(value)),
                semanticLabel: t.settings.pipDanmakuScale,
                semanticFormatter: (value) => 'x${value.toStringAsFixed(2)}',
              ),
            ),
            SettingsHint(t.settings.miniDanmakuHint),
          ],
        ),
      ],
    );
  }
}

/// The chat list beside the picture: whose name shows, what the list keeps,
/// and how the lines are set.
final class DanmakuDisplayPane extends ConsumerWidget {
  /// The pane.
  const DanmakuDisplayPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final showGifts = ref.watch(chatShowGiftsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.chatListGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.userRound),
              title: t.settings.chatShowNames,
              description: t.settings.chatShowNamesDesc,
              control: DsSwitch(
                value: ref.watch(chatNamesProvider),
                onChanged: (value) => unawaited(ref.read(chatNamesProvider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gift),
              title: t.settings.chatShowGifts,
              description: t.settings.chatShowGiftsDesc,
              control: DsSwitch(
                value: showGifts,
                onChanged: (value) => unawaited(ref.read(chatShowGiftsProvider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.coins),
              title: t.settings.chatGiftsAboveTier,
              description: t.settings.chatGiftsAboveTierDesc,
              control: DsSwitch(
                value: ref.watch(chatGiftsAboveTierProvider),
                onChanged: showGifts
                    ? (value) => unawaited(ref.read(chatGiftsAboveTierProvider.notifier).set(value: value))
                    : null,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.banknote),
              title: t.settings.chatGiftValueInYuan,
              description: t.settings.chatGiftValueInYuanDesc,
              control: DsSwitch(
                value: ref.watch(chatGiftValueInYuanProvider),
                onChanged: showGifts
                    ? (value) => unawaited(ref.read(chatGiftValueInYuanProvider.notifier).set(value: value))
                    : null,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rocket),
              title: t.settings.superChatIncludesMembership,
              description: t.settings.superChatIncludesMembershipDesc,
              control: DsSwitch(
                value: ref.watch(superChatIncludesMembershipProvider),
                onChanged: (value) =>
                    unawaited(ref.read(superChatIncludesMembershipProvider.notifier).set(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.chatListLayoutGroup),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.caseSensitive),
              title: t.settings.chatListFontSize,
              description: t.settings.chatListFontSizeDesc,
              value: ref.watch(chatListFontSizeProvider),
              options: [
                DsSelectOption(value: 0, label: t.settings.chatListFollowTheme),
                for (final size in const [12, 14, 16, 18, 20, 22])
                  DsSelectOption(
                    value: size,
                    label: t.settings.chatListFontSizeValue(size: size),
                  ),
              ],
              onChanged: (value) => unawaited(ref.read(chatListFontSizeProvider.notifier).set(value)),
            ),
            SettingsSegmentedRow<String>(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.chatListLineSpacing,
              description: t.settings.chatListLineSpacingDesc,
              value: ref.watch(chatListLineSpacingProvider),
              options: [
                (value: 'compact', label: t.settings.chatListSpacingCompact),
                (value: 'standard', label: t.settings.chatListSpacingStandard),
                (value: 'loose', label: t.settings.chatListSpacingLoose),
              ],
              onChanged: (value) => unawaited(ref.read(chatListLineSpacingProvider.notifier).set(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.panelRight),
              title: t.settings.chatPanelWidth,
              description: t.settings.chatPanelWidthDesc,
              detail: Text('${ref.watch(chatPanelWidthProvider).round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: ref.watch(chatPanelWidthProvider),
                min: kChatPanelWidthMin,
                max: kChatPanelWidthMax,
                divisions: ((kChatPanelWidthMax - kChatPanelWidthMin) / 20).round(),
                onChanged: (value) => unawaited(ref.read(chatPanelWidthProvider.notifier).set(value)),
                semanticLabel: t.settings.chatPanelWidth,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The way into the full-window sample. The sample used to sit inline on the
/// settings page; it now opens as a page of its own, so the flying layer can
/// be seen at a room's size while its controls sit beside it.
final class DanmakuPreviewEntry extends StatelessWidget {
  /// The entry.
  const DanmakuPreviewEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsListSection(
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.captions),
          title: Text(t.settings.danmakuPreview),
          description: Text(t.settings.danmakuPreviewHint),
          showChevron: true,
          onPressed: () => unawaited(showDanmakuPreview(context)),
        ),
      ],
    );
  }
}

/// Opens the danmaku sample full-window and alone.
Future<void> showDanmakuPreview(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => const DanmakuPreviewPage()));
}

/// A live sample of the flying layer, full-window: the real barrage engine,
/// the real config the player builds, and a short loop of messages, with every
/// style control in the sidebar so a knob answers where it is moved.
///
/// The sample text is what a room actually sends: a long title, an emoji, a
/// coloured gift and a top-pinned line.
final class DanmakuPreviewPage extends ConsumerStatefulWidget {
  /// The page.
  const DanmakuPreviewPage({super.key});

  @override
  ConsumerState<DanmakuPreviewPage> createState() => _DanmakuPreviewPageState();
}

final class _DanmakuPreviewPageState extends ConsumerState<DanmakuPreviewPage> {
  final BarrageController _controller = BarrageController();
  Timer? _timer;
  int _cursor = 0;

  /// The sample lines, cycled forever — what a room actually sends, so the
  /// long line shows the wrap and the coloured ones show what colour does.
  static const List<_PreviewLine> _lines = [
    _PreviewLine('前方高能预警', color: 0xFFFF4455),
    _PreviewLine('这画面也太好看了吧'),
    _PreviewLine('主播的声音很治愈啊～', color: 0xFF6BE58A),
    _PreviewLine('233333 名场面来了'),
    _PreviewLine('礼物特效好炫！', color: 0xFFFFD700),
    _PreviewLine('顶上去给后来的人看看，这条比较长一点', color: 0xFF7FD4FF),
  ];

  /// The two pinned lanes' sample lines.
  static const List<(DanmakuPlacement, String)> _pinned = [
    (DanmakuPlacement.top, '这是一条置顶弹幕'),
    (DanmakuPlacement.bottom, '这是一条置底弹幕'),
  ];

  @override
  void initState() {
    super.initState();
    _send();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final line = _lines[_cursor % _lines.length];
    _cursor++;
    _controller.send(
      BarrageItemMapper.toItem(
        DanmakuMessage(
          type: DanmakuMessageType.chat,
          userName: '',
          text: line.text,
          color: DanmakuColor.fromInt(line.color),
          messageId: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
    );
    // Every third beat also drops one line on each pinned lane, so the two
    // lane switches and the stay beside them answer in the frame: a lane
    // that is switched off sends nothing.
    if (_cursor % 3 != 1) return;
    final top = ref.read(danmakuFixedTopProvider);
    final bottom = ref.read(danmakuFixedBottomProvider);
    for (final (placement, text) in _pinned) {
      if (placement == DanmakuPlacement.top && !top) continue;
      if (placement == DanmakuPlacement.bottom && !bottom) continue;
      _controller.send(
        BarrageItemMapper.toItem(
          DanmakuMessage(
            type: DanmakuMessageType.chat,
            userName: '',
            text: text,
            color: DanmakuColor.fromInt(0xFFFFD700),
            messageId: 'preview-${placement.name}-${DateTime.now().microsecondsSinceEpoch}',
            style: DanmakuStyle(fontSize: 16, baseSpeed: 120, fontWeight: 500, placement: placement),
          ),
        ),
      );
    }
  }

  /// Restarts the sample from the first line: a viewer tuning a slider
  /// often wants the frame cleared rather than wait for the loop to come
  /// around.
  void _replay() {
    _controller.clear();
    _cursor = 0;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final style = ref.watch(danmakuStyleProvider);
    final fps = ref.watch(danmakuEffectiveFpsProvider);
    final family = resolvedFontFamily(style.fontFamily);
    return SettingsPreviewPage(
      icon: DsIcons.captions,
      title: t.settings.danmakuPreview,
      subtitle: '${style.fontSize.toStringAsFixed(0)} px · ${style.baseSpeed.round()} px/s',
      stage: Stack(
        fit: StackFit.expand,
        children: [
          FlameBarrageWidget(
            config: roomBarrageConfig(
              style,
              fps,
              family: family,
              fixedDuration: Duration(milliseconds: (ref.watch(danmakuFixedDurationProvider) * 1000).round()),
            ),
            emojiAtlas: EmojiAtlas.instance,
            controller: _controller,
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: SettingsPreviewBar(
              children: [
                SettingsPreviewCircleButton(icon: DsIcons.rotateCcw, semanticLabel: t.common.retry, onPressed: _replay),
                const SizedBox(width: DsSpace.s8),
                Text(
                  t.settings.backgroundPreviewMedia,
                  style: theme.typography.small.copyWith(color: const Color(0xCCFFFFFF)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      settings: const DanmakuStyleSettings(),
    );
  }
}

/// One sample line of the preview.
final class _PreviewLine {
  const _PreviewLine(this.text, {this.color = 0xFFFFFFFF});

  final String text;
  final int color;
}

/// The text, outline and shadow rows' choices: each palette colour with its
/// name and a swatch, so the answer reads without opening the list.
List<DsSelectOption<int>> _colorOptions(Translations t) => [
  for (final color in kDanmakuColorChoices)
    DsSelectOption(
      value: color,
      label: danmakuColorLabel(t, color),
      leading: _DanmakuColorDot(color: color),
    ),
];

/// One palette colour as a dot; a rim keeps white readable on white.
final class _DanmakuColorDot extends StatelessWidget {
  const _DanmakuColorDot({required this.color});

  final int color;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(color),
        border: Border.all(color: colors.border),
      ),
    );
  }
}

/// The glyph a save format gets in the list: markup, braces, styled captions,
/// plain captions, plain text.
DsIconData _saveFormatIcon(DanmakuFormat format) => switch (format) {
  DanmakuFormat.xml => DsIcons.fileCode,
  DanmakuFormat.json => DsIcons.fileBraces,
  DanmakuFormat.ass => DsIcons.captions,
  DanmakuFormat.srt => DsIcons.captionsShort,
  DanmakuFormat.txt => DsIcons.fileText,
};
