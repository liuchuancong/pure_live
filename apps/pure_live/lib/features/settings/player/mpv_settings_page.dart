import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/engine/mpv_tuning.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomController;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_chooser.dart';
import 'package:pure_live/shared/widgets/settings_chrome.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';

/// The mpv tuning page — the reference's mpv option set, ported onto this
/// build's engine-option channel.
///
/// What it is allowed to show is exactly what the engine can honour: the
/// driver lists are media_kit's own catalog filtered by the platform
/// (`MpvPlatformProfile`), the values persist in the preferences document,
/// and [RoomController] pushes them to libmpv — the live-capable ones onto
/// the open player, the output drivers on the next stream. Reference tiles
/// with no workspace backing (player presets, super-resolution, the kernel
/// switch that would need adapter packages this app does not ship) stay out.
final class MpvSettingsPage extends ConsumerWidget {
  /// The page.
  const new({super.key});

  static TargetPlatform get _platform => defaultTargetPlatform;

  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;

    void pick(String title, Map<String, String> options, String current, ValueChanged<String> onPick) {
      unawaited(
        showSettingsChooser<String>(
          context,
          ref,
          title: title,
          current: current,
          options: [for (final entry in options.entries) (entry.key, entry.value)],
        ).then((picked) {
          if (picked != null) {
            onPick(picked);
          }
        }),
      );
    }

    return SettingsChrome(
      title: t.settings.playerTitle,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.mpvOutputSection),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.input_outlined),
                title: Text(t.settings.mpvCustomOutput),
                description: Text(t.settings.mpvCustomOutputSubtitle),
                initialValue: preferences.customPlayerOutput,
                onToggle: (value) => unawaited(update((p) => p.copyWith(customPlayerOutput: value))),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.graphic_eq_outlined),
                title: Text(t.settings.mpvAudioOutput),
                value: Text(preferences.audioOutputDriver),
                description: preferences.customPlayerOutput ? null : Text(t.settings.mpvNeedsCustomOutput),
                onPressed: (_) => pick(
                  t.settings.mpvAudioOutput,
                  MpvTuning.audioOutputs(_platform),
                  preferences.audioOutputDriver,
                  (value) => unawaited(update((p) => p.copyWith(audioOutputDriver: value))),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.mpvDecodeSection),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.memory_outlined),
                title: Text(t.settings.mpvHardwareDecoder),
                value: Text(preferences.hardwareDecoder),
                onPressed: (_) => pick(
                  t.settings.mpvHardwareDecoder,
                  MpvTuning.hardwareDecoders(_platform),
                  preferences.hardwareDecoder,
                  (value) => unawaited(update((p) => p.copyWith(hardwareDecoder: value))),
                ),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.layers_outlined),
                title: Text(t.settings.mpvDeinterlace),
                value: Text(preferences.deinterlace),
                onPressed: (_) => pick(
                  t.settings.mpvDeinterlace,
                  {for (final value in MpvTuning.deinterlaceValues) value: value},
                  preferences.deinterlace,
                  (value) => unawaited(update((p) => p.copyWith(deinterlace: value))),
                ),
              ),
              if (_isDesktop)
                SettingsTile.switchTile(
                  leading: const Icon(Icons.blur_circular_outlined),
                  title: Text(t.settings.mpvInterpolation),
                  description: Text(t.settings.mpvInterpolationSubtitle),
                  initialValue: preferences.frameInterpolation,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(frameInterpolation: value))),
                ),
              if (_isDesktop)
                SettingsTile.navigation(
                  leading: const Icon(Icons.gradient_outlined),
                  title: Text(t.settings.mpvScaler),
                  value: Text(preferences.scaler),
                  onPressed: (_) => pick(
                    t.settings.mpvScaler,
                    {for (final value in MpvTuning.scaleFilters) value: value},
                    preferences.scaler,
                    (value) => unawaited(update((p) => p.copyWith(scaler: value))),
                  ),
                ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.mpvCacheSection),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(t.settings.mpvCacheSeconds),
                description: Text(t.settings.mpvCacheSecondsSubtitle),
                value: Text(preferences.streamCacheSeconds == 0 ? t.common.off : '${preferences.streamCacheSeconds} s'),
                onPressed: (_) => pick(
                  t.settings.mpvCacheSeconds,
                  {
                    '0': t.common.off,
                    for (final seconds in const [1, 2, 5, 10, 20, 30, 60]) '$seconds': '$seconds s',
                  },
                  '${preferences.streamCacheSeconds}',
                  (value) => unawaited(update((p) => p.copyWith(streamCacheSeconds: int.parse(value)))),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.refresh_outlined),
                title: Text(t.settings.mpvReset),
                description: Text(t.settings.mpvResetSubtitle),
                onPressed: (_) => unawaited(
                  update(
                    (p) => p.copyWith(
                      customPlayerOutput: false,
                      audioOutputDriver: MpvTuning.auto,
                      hardwareDecoder: MpvTuning.auto,
                      frameInterpolation: false,
                      scaler: MpvTuning.auto,
                      deinterlace: MpvTuning.auto,
                      streamCacheSeconds: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              SettingsTile(
                title: Text(t.settings.mpvEffectiveNote),
                description: Text(t.settings.mpvEffectiveNoteBody),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
