import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_sites/live_sites.dart' show LiveSiteManifest;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/rooms/play_quality.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The video settings (the reference's `SettingsSection.video`, scoped to
/// what this build backs): the audio defaults a room opens with, the quality
/// answers the stream resolve reads (`preferResolution` per network, the
/// H.264 rule, the picture fit), the room's auto-fullscreen switch, and the
/// links to the danmaku's own page and block list.
///
/// The answers stored here are the ones the room reads at open — the volume
/// and mute as in the reference's room volume dialog, the quality through
/// `defaultQualityIndex` in the room's `_loadQualities`, the fit as the
/// surface's starting `BoxFit` (and the in-room 画面比例 menu writes it
/// back).
///
/// The reference's rows without a backing service in this build stay out and
/// are named: the screen keep-on and background-play group (no wakelock or
/// audio-focus service yet), the PiP geometry rows (the window surfaces are
/// media_core's, entered from the room bar), the portrait/audience subpages,
/// and the danmaku font (no font manager).
final class VideoSettingsPage extends ConsumerWidget {
  /// The video settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final isMobile = switch (ref.read(environmentProvider).runtime.kind) {
      PlatformKind.android || PlatformKind.ios => true,
      _ => false,
    };
    final isDesktop = switch (ref.read(environmentProvider).runtime.kind) {
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => true,
      _ => false,
    };
    final sites = ref.watch(sitesProvider).registry.all;
    final knownIds = {for (final site in sites) site.manifest.id};
    final trustedHere = preferences.realOnlinePlatforms.where(knownIds.contains).length;
    return SettingsChrome(
      title: t.settings.video,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupAudio),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: Text(t.room.globalMute),
                description: Text(t.room.globalMuteSubtitle),
                initialValue: preferences.volumeMuted,
                onToggle: (value) => unawaited(update((p) => p.copyWith(volumeMuted: value))),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.phone_android,
                  title: t.room.mobileDefaultVolume,
                  subtitle: t.settings.defaultVolumeSubtitle,
                  value: preferences.defaultMobileVolume,
                  valueLabel: '${(preferences.defaultMobileVolume * 100).round()}%',
                  onChanged: (value) => unawaited(update((p) => p.copyWith(defaultMobileVolume: value))),
                ),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.computer,
                  title: t.room.desktopDefaultVolume,
                  subtitle: t.settings.defaultVolumeSubtitle,
                  value: preferences.defaultDesktopVolume,
                  valueLabel: '${(preferences.defaultDesktopVolume * 100).round()}%',
                  onChanged: (value) => unawaited(update((p) => p.copyWith(defaultDesktopVolume: value))),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupQuality),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('video-prefer-resolution'),
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(t.settings.preferResolution),
                description: Text(t.settings.preferResolutionDesc),
                value: Text(preferences.preferResolution),
                onPressed: (tileContext) => unawaited(
                  showSettingsChooser<String>(
                    tileContext,
                    title: t.settings.preferResolution,
                    current: preferences.preferResolution,
                    options: [for (final name in playQualityNames) (name, name)],
                  ).then((picked) => picked == null ? null : update((p) => p.copyWith(preferResolution: picked))),
                ),
              ),
              if (isMobile)
                SettingsTile.navigation(
                  key: const ValueKey('video-prefer-resolution-cellular'),
                  leading: const Icon(Icons.sim_card_outlined),
                  title: Text(t.settings.mobileQuality),
                  description: Text(t.settings.mobileQualityDesc),
                  value: Text(preferences.preferResolutionCellular),
                  onPressed: (tileContext) => unawaited(
                    showSettingsChooser<String>(
                      tileContext,
                      title: t.settings.mobileQuality,
                      current: preferences.preferResolutionCellular,
                      options: [for (final name in playQualityNames) (name, name)],
                    ).then(
                      (picked) => picked == null ? null : update((p) => p.copyWith(preferResolutionCellular: picked)),
                    ),
                  ),
                ),
              SettingsTile.switchTile(
                key: const ValueKey('video-prefer-h264'),
                leading: const Icon(Icons.code_outlined),
                title: Text(t.settings.preferH264),
                description: Text(t.settings.preferH264Desc),
                initialValue: preferences.preferH264,
                onToggle: (value) => unawaited(update((p) => p.copyWith(preferH264: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('video-fit'),
                leading: const Icon(Icons.aspect_ratio_outlined),
                title: Text(t.settings.videoFit),
                description: Text(t.settings.videoFitDesc),
                value: Text(_fitName(context, preferences.videoFitIndex)),
                onPressed: (tileContext) => unawaited(_pickFit(tileContext, ref, preferences)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupAudience),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('video-audience-mode'),
                leading: const Icon(Icons.groups_outlined),
                title: Text(t.settings.audienceMode),
                description: Text(t.settings.audienceModeDesc),
                value: Text(
                  preferences.preferRealOnlineCounts ? t.settings.audienceModeOnline : t.settings.audienceModeHeat,
                ),
                onPressed: (tileContext) => unawaited(
                  showSettingsChooser<bool>(
                    tileContext,
                    title: t.settings.audienceMode,
                    current: preferences.preferRealOnlineCounts,
                    options: [(false, t.settings.audienceModeHeat), (true, t.settings.audienceModeOnline)],
                  ).then((picked) => picked == null ? null : update((p) => p.copyWith(preferRealOnlineCounts: picked))),
                ),
              ),
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.settings.audiencePlatforms, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final site in sites)
                            PureButton(
                              key: ValueKey('audience-platform-${site.manifest.id}'),
                              label: _siteName(context, site.manifest),
                              size: ControlSize.sm,
                              variant: preferences.realOnlinePlatforms.contains(site.manifest.id)
                                  ? ButtonVariant.primary
                                  : ButtonVariant.secondary,
                              onPressed: () => unawaited(
                                update(
                                  (p) => p.copyWith(
                                    realOnlinePlatforms: p.realOnlinePlatforms.contains(site.manifest.id)
                                        ? [
                                            for (final id in p.realOnlinePlatforms)
                                              if (id != site.manifest.id) id,
                                          ]
                                        : [...p.realOnlinePlatforms, site.manifest.id],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.settings.audienceHeatOnlyCount(count: '${sites.length - trustedHere}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupPlayback),
            tiles: [
              if (isDesktop)
                SettingsTile.switchTile(
                  key: const ValueKey('video-pip-on-top'),
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(t.settings.pipOnTop),
                  description: Text(t.settings.pipOnTopDesc),
                  initialValue: preferences.pipAlwaysOnTop,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(pipAlwaysOnTop: value))),
                ),
              if (isDesktop)
                SettingsTile.switchTile(
                  key: const ValueKey('video-mini-remember'),
                  leading: const Icon(Icons.push_pin_outlined),
                  title: Text(t.settings.miniRemember),
                  description: Text(t.settings.miniRememberDesc),
                  initialValue: preferences.miniRememberPosition,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(miniRememberPosition: value))),
                ),
              if (isDesktop)
                SettingsTile.switchTile(
                  key: const ValueKey('video-pause-on-tile-close'),
                  leading: const Icon(Icons.pause_circle_outline),
                  title: Text(t.settings.pauseOnTileClose),
                  description: Text(t.settings.pauseOnTileCloseDesc),
                  initialValue: preferences.pauseOnPipClose,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(pauseOnPipClose: value))),
                ),
              SettingsTile.switchTile(
                key: const ValueKey('video-auto-fullscreen'),
                leading: const Icon(Icons.fullscreen_outlined),
                title: Text(t.settings.autoFullscreen),
                description: Text(t.settings.autoFullscreenDesc),
                initialValue: preferences.openRoomFullscreen,
                onToggle: (value) => unawaited(update((p) => p.copyWith(openRoomFullscreen: value))),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionVideo),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('video-show-danmaku'),
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(t.settings.danmakuVisible),
                description: Text(t.settings.danmakuVisibleSubtitle),
                initialValue: preferences.danmakuVisible,
                onToggle: (value) => unawaited(update((p) => p.copyWith(danmakuVisible: value))),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.style_outlined),
                title: Text(t.settings.danmakuTitle),
                description: Text(t.settings.danmakuDesc),
                onPressed: (_) => unawaited(const DanmakuSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                key: const ValueKey('video-portrait-link'),
                leading: const Icon(Icons.screen_lock_rotation_outlined),
                title: Text(t.settings.portraitLiveSettings),
                description: Text(t.settings.portraitLiveSettingsDesc),
                onPressed: (_) => unawaited(const PortraitSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                key: const ValueKey('video-block-list'),
                leading: const Icon(Icons.block_outlined),
                title: Text(t.settings.blockList),
                description: Text(t.settings.blockListDesc),
                onPressed: (_) => unawaited(const ShieldRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.face_outlined),
                title: Text(t.settings.localInteraction),
                description: Text(t.settings.localInteractionSubtitle),
                onPressed: (_) => unawaited(const LocalInteractionRoute().push<void>(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The site's display name in the viewer's locale, the manifest map read
  /// the way it documents itself.
  static String _siteName(BuildContext context, LiveSiteManifest manifest) {
    final locale = Localizations.localeOf(context);
    final names = manifest.name;
    return names[locale.toLanguageTag()] ??
        names[locale.languageCode] ??
        names['zh'] ??
        names['en'] ??
        (names.values.isEmpty ? manifest.id : names.values.first);
  }

  static Future<void> _pickFit(BuildContext context, WidgetRef ref, AppPreferences preferences) async {
    final t = context.t;
    final names = [
      t.settings.fitDefault,
      t.settings.fitCrop,
      t.settings.fitFillScreen,
      t.settings.fitHeight,
      t.settings.fitWidth,
      t.settings.fitScaleDown,
    ];
    final picked = await showSettingsChooser<int>(
      context,
      title: t.settings.videoFit,
      current: preferences.videoFitIndex,
      options: [for (final (index, name) in names.indexed) (index, name)],
    );
    if (picked != null) {
      await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(videoFitIndex: picked));
    }
  }

  static String _fitName(BuildContext context, int index) => switch (index.clamp(0, 5)) {
    0 => context.t.settings.fitDefault,
    1 => context.t.settings.fitCrop,
    2 => context.t.settings.fitFillScreen,
    3 => context.t.settings.fitHeight,
    4 => context.t.settings.fitWidth,
    _ => context.t.settings.fitScaleDown,
  };
}
