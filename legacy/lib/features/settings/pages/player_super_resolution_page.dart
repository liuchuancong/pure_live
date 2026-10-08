import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/super_resolution.dart';

/// Anime4K super-resolution: off / efficiency / quality, one card each.
///
/// Only desktop GPUs can hold the CNN chain in realtime, so the page is
/// reachable everywhere but the guide says so; the property itself only
/// mounts on Windows (see MediaKitLiveProperties.superResolutionAvailable).
class PlayerSuperResolutionPage extends GetView<SettingsService> {
  const PlayerSuperResolutionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('super_resolution_section'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(i18n('super_resolution_hint'), style: theme.textTheme.bodySmall),
          ),
          for (final mode in SuperResolutionMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(i18n(mode.labelKey), style: theme.textTheme.titleMedium),
                  subtitle: Text(i18n(mode.descriptionKey), style: theme.textTheme.bodySmall),
                  trailing: Obx(() {
                    final active =
                        SuperResolutionMode.fromName(SettingsService.to.player.superResolutionMode.v) == mode;
                    return active
                        ? Icon(Remix.checkbox_circle_fill, color: theme.colorScheme.primary)
                        : const Icon(Remix.checkbox_blank_circle_line);
                  }),
                  onTap: () => SettingsService.to.player.superResolutionMode.v = mode.name,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
