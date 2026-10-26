import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/vod/controller/vod_settings.dart';
import 'package:pure_live/l10n/translations.dart';

/// The Bilibili station's own settings: the Bilibili account the station
/// reads (and only that account — the live platforms' sign-ins stay in the
/// live module), and the quality a video opens with.
final class VodSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video.
  const VodSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final quality = ref.watch(vodQualityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        const AccountPane(siteIds: {SiteIds.bilibili}),
        DsListSection(
          header: Text(t.settings.vodPlayback),
          children: [
            SettingsChoiceRow<VodQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.vodQuality,
              description: t.settings.vodQualityDesc,
              value: quality,
              options: [
                for (final choice in VodQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: ref.read(vodQualityProvider.notifier).select,
            ),
          ],
        ),
      ],
    );
  }
}
