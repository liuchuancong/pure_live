import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
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
