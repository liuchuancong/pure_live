import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart'
    show BarrageItemMapper, DanmakuColor, DanmakuMessage, DanmakuMessageType;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/room/player/room_barrage_config.dart' show roomBarrageConfig;
import 'package:pure_live/features/settings/danmaku/chat_display_settings.dart'
    show
        chatGiftValueInYuanProvider,
        chatGiftsAboveTierProvider,
        chatListFontSizeProvider,
        chatListLineSpacingProvider,
        chatListStyleProvider,
        chatNamesProvider,
        chatPanelWidthProvider,
        chatShowGiftsProvider,
        kChatPanelWidthMax,
        kChatPanelWidthMin;
import 'package:pure_live/features/settings/danmaku/danmaku_hold_provider.dart' show danmakuHoldProvider;
import 'package:pure_live/features/settings/danmaku/danmaku_presets.dart' show DanmakuPreset, presetLabel;
import 'package:pure_live/features/settings/danmaku/danmaku_show_gifts_provider.dart' show danmakuShowGiftsProvider;
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart';
import 'package:pure_live/features/settings/danmaku/super_chat_settings.dart' show superChatIncludesMembershipProvider;
import 'package:pure_live/features/settings/pages/font_manager_page.dart'
    show fontFamilyLabel, showFontManagerPage;
import 'package:pure_live/features/settings/playback/pip_danmaku_scale_provider.dart'
    show kPipDanmakuScaleMax, kPipDanmakuScaleMin, pipDanmakuScaleProvider;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart'
    show playbackSettingsProvider;
import 'package:pure_live/features/settings/surface/settings_page.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';

/// The danmaku settings, split across three pages: this one is the switch and
/// the interaction of the flying layer, [DanmakuStylePane] tunes how a
/// danmaku looks (with a live preview), and [DanmakuDisplayPane] is the chat
/// list beside the picture. The shield keeps its own page under this one.
final class DanmakuPane extends ConsumerWidget {
  /// The pane.
  const DanmakuPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final playback = ref.watch(playbackSettingsProvider);
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
        // The master switch above decides whether the layer draws; the
        // sample sits right under it so the answer to "on" is visible.
        const DanmakuPreviewCard(),
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
                onChanged: (value) => unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).set(value: value)),
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
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.danmakuStyle),
            SettingsChildEntry(child: SettingsSection.danmakuDisplay),
            SettingsChildEntry(child: SettingsSection.shield),
          ],
        ),
      ],
    );
  }
}

/// The flying layer's own look: a live preview over the controls, the built-in
/// presets, and every knob of one danmaku. Split from the chat list because
/// the two answer different questions — what flies over the picture, and what
/// the list beside it keeps.
final class DanmakuStylePane extends ConsumerWidget {
  /// The pane.
  const DanmakuStylePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final playback = ref.watch(playbackSettingsProvider);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final frameRate = ref.watch(danmakuFrameRateProvider);
    final frameRateController = ref.read(danmakuFrameRateProvider.notifier);
    final effectiveFps = ref.watch(danmakuEffectiveFpsProvider);
    final activePreset = DanmakuPreset.matching(style, frameRate);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final pipScaleController = ref.read(pipDanmakuScaleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        const DanmakuPreviewCard(),
        DsListSection(
          children: [
            SettingsChoiceRow<DanmakuPreset>(
              leading: const DsIcon(DsIcons.layoutTemplate),
              title: t.settings.preset,
              description: t.settings.danmakuPresetHint,
              value: activePreset,
              placeholder: t.settings.danmakuPresetCustom,
              options: [
                for (final preset in DanmakuPreset.values) DsSelectOption(value: preset, label: presetLabel(t, preset)),
              ],
              onChanged: (preset) => unawaited(_applyPreset(context, ref, preset)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.danmakuFont),
              description: Text(t.settings.danmakuFontDescription),
              detail: Text(
                style.fontFamily == null
                    ? platformFontFamilyLabel()
                    : fontFamilyLabel(
                        t,
                        style.fontFamily,
                        cloudName: ref.read(fontLibraryProvider).nameOf(style.fontFamily!),
                      ),
              ),
              showChevron: true,
              onPressed: () => showFontManagerPage(context, ref, danmaku: true),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.danmakuStyleGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.caseSensitive),
              title: t.settings.styleFontSize,
              description: t.settings.styleFontSizeDesc,
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
              description: t.settings.styleFontWeightDesc,
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
              leading: const DsIcon(DsIcons.letterSpacing),
              title: t.settings.styleLetterSpacing,
              description: t.settings.styleLetterSpacingDesc,
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
              description: t.settings.styleSpeedDesc,
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
              description: t.settings.styleAreaDesc,
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
              description: t.settings.styleTopMarginDesc,
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
              description: t.settings.styleBottomMarginDesc,
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.blend),
              title: t.settings.styleOpacity,
              description: t.settings.styleOpacityDesc,
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
              description: t.settings.styleStrokeDesc,
              control: DsSwitch(
                value: style.showStroke,
                onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.penTool),
              title: t.settings.styleStrokeWidth,
              description: t.settings.styleStrokeWidthDesc,
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circleSlash),
              title: t.settings.styleNoEmoji,
              description: t.settings.styleNoEmojiDesc,
              control: DsSwitch(
                value: style.noEmoji,
                onChanged: (value) => unawaited(controller.setNoEmoji(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sparkles),
              title: t.settings.styleFpsFollow,
              description: t.settings.styleFpsFollowDesc,
              control: DsSwitch(
                value: frameRate.autoFps,
                onChanged: (value) => unawaited(frameRateController.setAutoFps(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.styleFps,
              description: t.settings.styleFpsDesc,
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
              description: t.settings.styleMaxVisibleDesc,
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
              description: t.settings.styleMassModeDesc,
              control: DsSwitch(
                value: style.massMode,
                onChanged: (value) => unawaited(controller.setMassMode(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gift),
              title: t.settings.danmakuShowGifts,
              description: t.settings.danmakuShowGiftsDesc,
              control: DsSwitch(
                value: ref.watch(danmakuShowGiftsProvider),
                onChanged: (value) => unawaited(ref.read(danmakuShowGiftsProvider.notifier).set(value: value)),
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
              description: t.settings.miniDanmakuVisibleDesc,
              control: DsSwitch(
                value: playback.miniDanmakuVisible,
                onChanged: (value) => unawaited(
                  ref.read(playbackSettingsProvider.notifier).setMiniDanmakuVisible(value: value),
                ),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.appWindow),
              title: t.settings.pipDanmakuScaleAuto,
              description: t.settings.pipDanmakuScaleAutoDesc,
              control: DsSwitch(
                value: pipScale.auto,
                onChanged: (value) => unawaited(pipScaleController.setAuto(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.scale),
              title: t.settings.pipDanmakuScale,
              description: t.settings.pipDanmakuScaleDesc,
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
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCw),
              title: Text(t.settings.styleReset),
              onPressed: () {
                unawaited(controller.reset());
                unawaited(frameRateController.reset());
                unawaited(ref.read(danmakuTapInteractionProvider.notifier).reset());
                unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).reset());
                unawaited(pipScaleController.reset());
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyPreset(BuildContext context, WidgetRef ref, DanmakuPreset preset) async {
    await preset.apply(
      style: ref.read(danmakuStyleProvider.notifier),
      frameRate: ref.read(danmakuFrameRateProvider.notifier),
      noEmoji: ref.read(danmakuStyleProvider).noEmoji,
      fps: ref.read(danmakuFrameRateProvider).fps,
    );
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.settings.danmakuPresetApplied);
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
                onChanged: (value) => unawaited(ref.read(superChatIncludesMembershipProvider.notifier).set(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.chatListLayoutGroup),
          children: [
            SettingsSegmentedRow<String>(
              leading: const DsIcon(DsIcons.list),
              title: t.settings.chatListStyle,
              description: t.settings.chatListStyleDesc,
              value: ref.watch(chatListStyleProvider),
              options: [
                (value: 'compact', label: t.settings.chatListStyleCompact),
                (value: 'card', label: t.settings.chatListStyleCard),
              ],
              onChanged: (value) => unawaited(ref.read(chatListStyleProvider.notifier).set(value)),
            ),
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

/// A live sample of the flying layer: the real barrage engine, the real
/// config the player builds, and a short loop of messages, so every knob on
/// this page answers where it is moved.
///
/// The box is a 16:9 picture at a feed's width; the engine needs a bounded
/// box, and the sample text is what a room actually sends — a long title, an
/// emoji, a coloured gift and a top-pinned line.
final class DanmakuPreviewCard extends ConsumerStatefulWidget {
  /// The card.
  const DanmakuPreviewCard({super.key});

  @override
  ConsumerState<DanmakuPreviewCard> createState() => _DanmakuPreviewCardState();
}

final class _DanmakuPreviewCardState extends ConsumerState<DanmakuPreviewCard> {
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
    final colors = DsTheme.colorsOf(context);
    final style = ref.watch(danmakuStyleProvider);
    final rate = ref.watch(danmakuFrameRateProvider);
    final fps = ref.watch(danmakuEffectiveFpsProvider);
    final family = effectiveFontFamily(style.fontFamily, ref.watch(danmakuFontFaceProvider));
    final preset = DanmakuPreset.matching(style, rate);
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s8, DsSpace.s8, DsSpace.s8),
            child: Row(
              children: [
                const DsIcon(DsIcons.captions, size: 16),
                const SizedBox(width: DsSpace.s8),
                Text(t.settings.navDanmaku, style: theme.typography.bodyStrong.copyWith(color: colors.text)),
                const SizedBox(width: DsSpace.s8),
                DsBadge(
                  label: Text(preset == null ? t.settings.danmakuPresetCustom : presetLabel(t, preset)),
                  dot: false,
                ),
                const Spacer(),
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: _replay,
                  icon: const DsIcon(DsIcons.rotateCcw),
                  semanticLabel: t.common.retry,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16),
            // The frame keeps a preview's size on a wide pane: a 16:9 box
            // at the settings column's full 960px would be a half-screen
            // picture, not a sample.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s16)),
                  child: ColoredBox(
                    color: const Color(0xFF101418),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FlameBarrageWidget(
                        config: roomBarrageConfig(style, fps, family: family),
                        emojiAtlas: EmojiAtlas.instance,
                        controller: _controller,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s12),
            child: Text(
              t.settings.danmakuPreviewHint,
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sample line of the preview.
final class _PreviewLine {
  const _PreviewLine(this.text, {this.color = 0xFFFFFFFF});

  final String text;
  final int color;
}
