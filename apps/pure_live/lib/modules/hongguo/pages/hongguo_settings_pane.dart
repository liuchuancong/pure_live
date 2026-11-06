import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart'
    show HongguoDanmakuDensity, hongguoDanmakuSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';
import 'package:pure_live/modules/hongguo/widgets/hongguo_card_preview.dart' show showHongguoCardPreview;

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
            // The picture's shape, the bar's hide delay and the screen's wake
            // are the app's own player settings — this player reads all three —
            // so the row opens the page that carries them rather than a second
            // copy of each switch here. The row names what this module meets
            // there: the page is titled for the live room's full set, whose
            // floating-window rows and rendition choice it never shows.
            SettingsChildEntry(
              child: SettingsSection.picture,
              title: t.settings.sharedPictureEntry,
              description: t.settings.sharedPictureEntryDesc,
            ),
            // The mute pair, the background switch and the seed volume are the
            // app's own, read when this player opens a handle.
            SettingsChildEntry(
              child: SettingsSection.quality,
              title: t.settings.sharedSoundEntry,
              description: t.settings.sharedSoundEntryDesc,
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

/// What the poster card draws: one entry to the page that shows the card and
/// carries a switch for every piece, the way the room card's pane does.
final class HongguoInterfacePane extends ConsumerWidget {
  const HongguoInterfacePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // The card's own page opens from here, so the section carries the entry
        // the way this pane's other entries do — without a heading that repeats
        // what the page's own switch list is called.
        DsListSection(
          children: [
            // The row opens the card's own page — the poster sample at a wall's
            // size, with the piece switches beside it — rather than a second
            // copy of those switches here, where they could not be seen.
            DsListRow(
              leading: const DsIcon(DsIcons.idCard),
              title: Text(t.settings.hongguoCardSettingsTitle),
              description: Text(t.settings.hongguoCardPreviewHint),
              showChevron: true,
              onPressed: () => unawaited(showHongguoCardPreview(context)),
            ),
          ],
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
