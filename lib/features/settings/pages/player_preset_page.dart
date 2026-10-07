import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/kernel/player_preset.dart';

/// One-click playback presets, one page per recipe.
///
/// A preset is stored per engine and per platform group: applying one
/// here changes the segment for the engine and platform this device is
/// currently on, and nothing else.
class PlayerPresetPage extends GetView<SettingsService> {
  const PlayerPresetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('player_preset_section'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(i18n('player_preset_hint'), style: theme.textTheme.bodySmall),
          ),
          for (final preset in PlayerPresetId.values)
            if (preset.availableOnCurrentPlatform)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(i18n(preset.nameKey), style: theme.textTheme.titleMedium),
                    subtitle: Text(i18n(preset.descriptionKey), style: theme.textTheme.bodySmall),
                    trailing: Obx(() {
                      final _ = SettingsService.to.player.outputSegmentRevision.value;
                      final active = SettingsService.to.player.currentPreset == preset;
                      return active
                          ? Icon(Remix.checkbox_circle_fill, color: theme.colorScheme.primary)
                          : const Icon(Remix.checkbox_blank_circle_line);
                    }),
                    onTap: () => SettingsService.to.player.applyPreset(preset),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
