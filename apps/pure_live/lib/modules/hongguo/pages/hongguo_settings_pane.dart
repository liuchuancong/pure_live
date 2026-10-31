import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart'
    show HongguoDanmakuDensity, hongguoDanmakuSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';

/// The station's own settings, split the way every module's are: the
/// rendition an episode opens with on its own page, the poster card's pieces,
/// the danmaku look and the device identity each behind one entry.
///
/// The picture mode stays on the app's own player setting, where every player
/// shares it.
final class HongguoSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → 红果短剧.
  const HongguoSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(hongguoSettingsProvider);
    final learned = ref.watch(hongguoDecoderLessonsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.hongguoPlayback),
          children: [
            SettingsChoiceRow<HongguoQualityChoice>(
              leading: const DsIcon(DsIcons.slidersHorizontal),
              title: t.settings.hongguoQuality,
              description: t.settings.hongguoQualityDesc,
              value: settings.quality,
              options: [
                for (final choice in HongguoQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (choice) => unawaited(ref.read(hongguoSettingsProvider.notifier).setQuality(choice)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.circleAlert),
              title: Text(t.hongguo.decoderLessons),
              description: Text(
                learned.isEmpty ? t.hongguo.decoderLessonsEmpty : t.hongguo.decoderLessonsCount(count: learned.length),
              ),
              onPressed: learned.isEmpty
                  ? null
                  : () async {
                      final count = learned.length;
                      await ref.read(hongguoDecoderLessonsProvider.notifier).reset();
                      if (context.mounted) {
                        showDsToast(
                          context: context,
                          title: t.hongguo.decoderResetDone(count: count),
                        );
                      }
                    },
            ),
          ],
        ),
        // The three pages that carry their own controls, one row each.
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.hongguoInterface),
            SettingsChildEntry(child: SettingsSection.hongguoDownload),
            SettingsChildEntry(child: SettingsSection.hongguoDanmaku),
            SettingsChildEntry(child: SettingsSection.hongguoDevice),
          ],
        ),
      ],
    );
  }
}

/// What the poster card draws: one switch per piece, the way the room card's
/// pane lays its own out.
final class HongguoInterfacePane extends ConsumerWidget {
  const HongguoInterfacePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final card = ref.watch(hongguoCardSettingsProvider);
    final cardController = ref.read(hongguoCardSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.settings.hongguoInterface),
      children: [
        for (final (element, icon, label) in <(HongguoCardElement, DsIconData, String)>[
          (HongguoCardElement.rank, DsIcons.trophy, t.settings.hongguoCardRank),
          (HongguoCardElement.coverTags, DsIcons.tag, t.settings.hongguoCardTags),
          (HongguoCardElement.episodes, DsIcons.listMusic, t.settings.hongguoCardEpisodes),
          (HongguoCardElement.today, DsIcons.calendar, t.settings.hongguoCardToday),
          (HongguoCardElement.score, DsIcons.star, t.settings.hongguoCardScore),
          (HongguoCardElement.hot, DsIcons.flame, t.settings.hongguoCardHot),
          (HongguoCardElement.meta, DsIcons.info, t.settings.hongguoCardMeta),
        ])
          SettingsConfigRow(
            leading: DsIcon(icon),
            title: label,
            control: DsSwitch(
              value: card.shows(element),
              onChanged: (value) => unawaited(cardController.setElement(element, visible: value)),
            ),
          ),
      ],
    );
  }
}

/// The danmaku the station's player draws: on or off, and the look it takes.
final class HongguoDanmakuPane extends ConsumerWidget {
  const HongguoDanmakuPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final controller = ref.read(hongguoDanmakuSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.hongguo.danmaku),
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.captions),
          title: t.hongguo.danmaku,
          description: t.hongguo.danmakuEnabledDesc,
          control: DsSwitch(
            value: danmaku.enabled,
            onChanged: (value) => unawaited(controller.setEnabled(value: value)),
          ),
        ),
        SettingsChoiceRow<double>(
          leading: const DsIcon(DsIcons.type),
          title: t.hongguo.danmakuFontSize,
          description: t.hongguo.danmakuFontSizeDesc,
          value: danmaku.fontSize,
          options: [
            for (final size in const <double>[16, 20, 24, 28, 32])
              DsSelectOption(value: size, label: '${size.round()}'),
          ],
          onChanged: (value) => unawaited(controller.setFontSize(value)),
        ),
        SettingsChoiceRow<double>(
          leading: const DsIcon(DsIcons.contrast),
          title: t.hongguo.danmakuOpacity,
          description: t.hongguo.danmakuOpacityDesc,
          value: danmaku.opacity,
          options: [
            for (final value in const <double>[0.5, 0.7, 0.9, 1])
              DsSelectOption(value: value, label: '${(value * 100).round()}%'),
          ],
          onChanged: (value) => unawaited(controller.setOpacity(value)),
        ),
        SettingsChoiceRow<double>(
          leading: const DsIcon(DsIcons.gauge),
          title: t.hongguo.danmakuSpeed,
          description: t.hongguo.danmakuSpeedDesc,
          value: danmaku.speed,
          options: [
            for (final value in const <double>[0.5, 1, 1.5, 2])
              DsSelectOption(value: value, label: '${value == value.roundToDouble() ? value.toInt() : value}x'),
          ],
          onChanged: (value) => unawaited(controller.setSpeed(value)),
        ),
        SettingsChoiceRow<HongguoDanmakuDensity>(
          leading: const DsIcon(DsIcons.slidersHorizontal),
          title: t.hongguo.danmakuDensity,
          description: t.hongguo.danmakuDensityDesc,
          value: danmaku.density,
          options: [
            for (final density in HongguoDanmakuDensity.values) DsSelectOption(value: density, label: density.label(t)),
          ],
          onChanged: (value) => unawaited(controller.setDensity(value)),
        ),
      ],
    );
  }
}

/// The device identity this install registered with the service, and the way
/// to start over with a fresh one.
final class HongguoDevicePane extends ConsumerWidget {
  const HongguoDevicePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsListSection(
      header: Text(t.settings.hongguoDevice),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCcw),
          title: Text(t.settings.hongguoDeviceReset),
          description: Text(t.settings.hongguoDeviceResetDesc),
          onPressed: () => unawaited(ref.read(hongguoClientProvider).resetDevice()),
        ),
      ],
    );
  }
}
