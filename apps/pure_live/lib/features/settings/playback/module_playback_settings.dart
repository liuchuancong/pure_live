import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/features/settings/playback/playback_settings_providers.dart'
    show kControlsAutoHideSecondsMax, kControlsAutoHideSecondsMin, usesMobileVolumeDefault;

/// The player modules that keep their own playback settings — the auto-hide
/// pace and the volume a module remembers for itself, so a live room's
/// choices never dictate a video page's and a short-drama's never a
/// channel's. The live room stays on the shared `playbackSettingsProvider`:
/// its set is the room's own.
enum PlayerModule {
  /// The IPTV channel player.
  iptv,

  /// The huya video player.
  huya,

  /// The Bilibili video and season players.
  vod,

  /// The replay (SOOP/Douyu archive) player.
  archive,

  /// The hongguo short-drama player.
  hongguo,

  /// The media preview over local files.
  preview,
}

/// One module's own playback settings: the bar's auto-hide delay (its zero
/// is 常显) and the volume a new handle starts on.
typedef ModulePlaybackSettings = ({int controlsAutoHideSeconds, double volume});

/// One module's stored playback settings, persisted under
/// `playback.<module>.*`; the same keys the shared provider uses, namespaced
/// by the module, so the modules drift apart by choice and never by accident.
final class ModulePlaybackSettingsController extends Notifier<ModulePlaybackSettings> {
  ModulePlaybackSettingsController(this.module);

  /// The module these settings belong to.
  final PlayerModule module;

  String get _autoHideKey => 'playback.${module.name}.controlsAutoHide';

  String get _volumeKey => 'playback.${module.name}.volume';

  @override
  ModulePlaybackSettings build() => _read();

  ModulePlaybackSettings _read() {
    try {
      return (
        controlsAutoHideSeconds: (StoragePrefs.getInt(_autoHideKey) ?? 3).clamp(
          kControlsAutoHideSecondsMin,
          kControlsAutoHideSecondsMax,
        ),
        volume: StoragePrefs.getDouble(_volumeKey)?.clamp(0.0, 1.0) ?? (usesMobileVolumeDefault ? 0.5 : 1.0),
      );
    } on Object {
      return (controlsAutoHideSeconds: 3, volume: usesMobileVolumeDefault ? 0.5 : 1.0);
    }
  }

  /// The bar's auto-hide delay; zero is 常显.
  Future<void> setControlsAutoHideSeconds(int value) async {
    final clamped = value.clamp(kControlsAutoHideSecondsMin, kControlsAutoHideSecondsMax);
    state = (controlsAutoHideSeconds: clamped, volume: state.volume);
    await StoragePrefs.setInt(_autoHideKey, clamped);
  }

  /// The volume a new handle starts on, stored for the current platform.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = (controlsAutoHideSeconds: state.controlsAutoHideSeconds, volume: clamped);
    await StoragePrefs.setDouble(_volumeKey, clamped);
  }
}

/// One module's own playback settings, keyed by [PlayerModule].
final NotifierProviderFamily<ModulePlaybackSettingsController, ModulePlaybackSettings, PlayerModule>
modulePlaybackSettingsProvider =
    NotifierProvider.family<ModulePlaybackSettingsController, ModulePlaybackSettings, PlayerModule>(
      ModulePlaybackSettingsController.new,
    );
