import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart'
    show HongguoDanmakuDensity, hongguoDanmakuSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';

/// The station's own settings: it talks to the official service directly —
/// the signing and the anonymous device registration are its own business —
/// so what is left is the rendition an episode opens with, the decoder
/// lessons this machine learned, and the way to start over with a fresh
/// device identity. The picture mode stays on the app's own player setting,
/// where every player shares it.
final class HongguoSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → 红果短剧.
  const HongguoSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(hongguoSettingsProvider);
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final danmakuController = ref.read(hongguoDanmakuSettingsProvider.notifier);
    final learned = ref.watch(hongguoDecoderLessonsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsChoiceRow<HongguoQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.hongguoQuality,
              description: t.settings.hongguoQualityDesc,
              value: settings.quality,
              options: [
                for (final choice in HongguoQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (choice) => unawaited(ref.read(hongguoSettingsProvider.notifier).setQuality(choice)),
            ),
          ],
        ),
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.captions),
              title: t.hongguo.danmaku,
              description: t.hongguo.danmakuEnabledDesc,
              control: DsSwitch(
                value: danmaku.enabled,
                onChanged: (value) => unawaited(danmakuController.setEnabled(value: value)),
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
              onChanged: (value) => unawaited(danmakuController.setFontSize(value)),
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
              onChanged: (value) => unawaited(danmakuController.setOpacity(value)),
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
              onChanged: (value) => unawaited(danmakuController.setSpeed(value)),
            ),
            SettingsChoiceRow<HongguoDanmakuDensity>(
              leading: const DsIcon(DsIcons.slidersHorizontal),
              title: t.hongguo.danmakuDensity,
              description: t.hongguo.danmakuDensityDesc,
              value: danmaku.density,
              options: [
                for (final density in HongguoDanmakuDensity.values)
                  DsSelectOption(value: density, label: density.label(t)),
              ],
              onChanged: (value) => unawaited(danmakuController.setDensity(value)),
            ),
          ],
        ),
        DsListSection(
          children: [
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
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.hongguoDeviceReset),
              description: Text(t.settings.hongguoDeviceResetDesc),
              onPressed: () => unawaited(ref.read(hongguoClientProvider).resetDevice()),
            ),
          ],
        ),
      ],
    );
  }
}
