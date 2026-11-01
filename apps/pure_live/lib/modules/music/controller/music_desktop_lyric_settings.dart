import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_settings_store.dart';

/// The desktop lyric overlay's half of the music module's preferences: its
/// on/off state, its look and how it sits on the screen. The player's own
/// lyric panel lives in the lyric group beside this one.
@immutable
final class MusicDesktopLyricsSettings {
  /// Creates the desktop-lyric preferences.
  const MusicDesktopLyricsSettings({
    required this.desktopLyrics,
    required this.desktopLyricLocked,
    required this.desktopLyricFontSize,
    required this.desktopLyricOpacity,
    required this.desktopLyricTextColor,
    required this.desktopLyricStrokeColor,
    required this.desktopLyricStrokeWidth,
    required this.desktopLyricLineGap,
    required this.desktopLyricBoldLine,
    required this.desktopLyricBoldExtended,
    required this.desktopLyricVertical,
    required this.desktopLyricAlignment,
  });

  /// The reference's defaults: the overlay off until it is asked for, a 40 px
  /// white line with a 2 px black outline, stacked 15 px apart.
  static const MusicDesktopLyricsSettings standard = MusicDesktopLyricsSettings(
    desktopLyrics: false,
    desktopLyricLocked: false,
    desktopLyricFontSize: 40,
    desktopLyricOpacity: 1,
    desktopLyricTextColor: 0xFFFFFFFF,
    desktopLyricStrokeColor: 0xFF000000,
    desktopLyricStrokeWidth: 2,
    desktopLyricLineGap: 15,
    desktopLyricBoldLine: true,
    desktopLyricBoldExtended: true,
    desktopLyricVertical: false,
    desktopLyricAlignment: audio.DesktopLyricAlignment.center,
  );

  /// Whether the desktop lyric overlay was left on.
  final bool desktopLyrics;

  /// Whether the overlay ignores pointer input.
  final bool desktopLyricLocked;

  /// The overlay's font size in logical pixels.
  final double desktopLyricFontSize;

  /// The overlay's opacity, 0.0–1.0.
  final double desktopLyricOpacity;

  /// The overlay's text colour as 0xAARRGGBB.
  final int desktopLyricTextColor;

  /// The overlay's outline colour as 0xAARRGGBB.
  final int desktopLyricStrokeColor;

  /// The overlay's outline width in logical pixels; 0 turns it off.
  final double desktopLyricStrokeWidth;

  /// The gap between the overlay's stacked lines, 0–25 — the reference's
  /// `desktopLyric.style.lineGap`.
  final int desktopLyricLineGap;

  /// Whether the overlay's main line draws bold — the reference's
  /// `desktopLyric.style.isFontWeightLine`.
  final bool desktopLyricBoldLine;

  /// Whether the overlay's translation line draws bold — the reference's
  /// `desktopLyric.style.isFontWeightExtended`.
  final bool desktopLyricBoldExtended;

  /// Whether the desktop lyric reads top-to-bottom in right-to-left columns —
  /// the reference's `desktopLyric.direction` = vertical.
  final bool desktopLyricVertical;

  /// The overlay's horizontal anchoring.
  final audio.DesktopLyricAlignment desktopLyricAlignment;

  /// A copy with selected fields replaced.
  MusicDesktopLyricsSettings copyWith({
    bool? desktopLyrics,
    bool? desktopLyricLocked,
    double? desktopLyricFontSize,
    double? desktopLyricOpacity,
    int? desktopLyricTextColor,
    int? desktopLyricStrokeColor,
    double? desktopLyricStrokeWidth,
    int? desktopLyricLineGap,
    bool? desktopLyricBoldLine,
    bool? desktopLyricBoldExtended,
    bool? desktopLyricVertical,
    audio.DesktopLyricAlignment? desktopLyricAlignment,
  }) => MusicDesktopLyricsSettings(
    desktopLyrics: desktopLyrics ?? this.desktopLyrics,
    desktopLyricLocked: desktopLyricLocked ?? this.desktopLyricLocked,
    desktopLyricFontSize: desktopLyricFontSize ?? this.desktopLyricFontSize,
    desktopLyricOpacity: desktopLyricOpacity ?? this.desktopLyricOpacity,
    desktopLyricTextColor: desktopLyricTextColor ?? this.desktopLyricTextColor,
    desktopLyricStrokeColor: desktopLyricStrokeColor ?? this.desktopLyricStrokeColor,
    desktopLyricStrokeWidth: desktopLyricStrokeWidth ?? this.desktopLyricStrokeWidth,
    desktopLyricLineGap: desktopLyricLineGap ?? this.desktopLyricLineGap,
    desktopLyricBoldLine: desktopLyricBoldLine ?? this.desktopLyricBoldLine,
    desktopLyricBoldExtended: desktopLyricBoldExtended ?? this.desktopLyricBoldExtended,
    desktopLyricVertical: desktopLyricVertical ?? this.desktopLyricVertical,
    desktopLyricAlignment: desktopLyricAlignment ?? this.desktopLyricAlignment,
  );
}

const String _desktopLyricsKey = 'music.lyric.desktop.enabled';
const String _desktopLyricLockedKey = 'music.lyric.desktop.locked';
const String _desktopLyricFontSizeKey = 'music.lyric.desktop.fontSize';
const String _desktopLyricOpacityKey = 'music.lyric.desktop.opacity';
const String _desktopLyricTextColorKey = 'music.lyric.desktop.textColor';
const String _desktopLyricStrokeColorKey = 'music.lyric.desktop.strokeColor';
const String _desktopLyricStrokeWidthKey = 'music.lyric.desktop.strokeWidth';
const String _desktopLyricLineGapKey = 'music.lyric.desktop.lineGap';
const String _desktopLyricBoldLineKey = 'music.lyric.desktop.boldLine';
const String _desktopLyricBoldExtendedKey = 'music.lyric.desktop.boldExtended';
const String _desktopLyricVerticalKey = 'music.lyric.desktop.vertical';
const String _desktopLyricAlignmentKey = 'music.lyric.desktop.alignment';

/// Owns the music module's desktop-lyric preferences.
final class MusicDesktopLyricsSettingsController extends Notifier<MusicDesktopLyricsSettings> {
  @override
  MusicDesktopLyricsSettings build() => MusicDesktopLyricsSettings(
    desktopLyrics: readMusicPrefBool(_desktopLyricsKey) ?? false,
    desktopLyricLocked: readMusicPrefBool(_desktopLyricLockedKey) ?? false,
    desktopLyricFontSize: readMusicPrefDouble(_desktopLyricFontSizeKey) ?? 40,
    desktopLyricOpacity: readMusicPrefDouble(_desktopLyricOpacityKey) ?? 1,
    desktopLyricTextColor: readMusicPrefInt(_desktopLyricTextColorKey) ?? 0xFFFFFFFF,
    desktopLyricStrokeColor: readMusicPrefInt(_desktopLyricStrokeColorKey) ?? 0xFF000000,
    desktopLyricStrokeWidth: readMusicPrefDouble(_desktopLyricStrokeWidthKey) ?? 2,
    desktopLyricLineGap: (readMusicPrefInt(_desktopLyricLineGapKey) ?? 15).clamp(0, 25),
    desktopLyricBoldLine: readMusicPrefBool(_desktopLyricBoldLineKey) ?? true,
    desktopLyricBoldExtended: readMusicPrefBool(_desktopLyricBoldExtendedKey) ?? true,
    desktopLyricVertical: readMusicPrefBool(_desktopLyricVerticalKey) ?? false,
    desktopLyricAlignment: _readAlignment(),
  );

  static audio.DesktopLyricAlignment _readAlignment() {
    final name = readMusicPref(_desktopLyricAlignmentKey);
    for (final alignment in audio.DesktopLyricAlignment.values) {
      if (alignment.name == name) return alignment;
    }
    return audio.DesktopLyricAlignment.center;
  }

  /// Remembers whether the desktop lyric overlay is on.
  Future<void> setDesktopLyrics({required bool visible}) async {
    state = state.copyWith(desktopLyrics: visible);
    await writeMusicPrefBool(_desktopLyricsKey, value: visible);
  }

  /// Locks or unlocks the desktop lyric overlay's click-through mode.
  Future<void> setDesktopLyricLocked({required bool locked}) async {
    state = state.copyWith(desktopLyricLocked: locked);
    await writeMusicPrefBool(_desktopLyricLockedKey, value: locked);
  }

  /// Sets the overlay's font size, within the window's usable range.
  Future<void> setDesktopLyricFontSize(double value) async {
    final clamped = value.clamp(18.0, 72.0);
    state = state.copyWith(desktopLyricFontSize: clamped);
    await writeMusicPrefDouble(_desktopLyricFontSizeKey, clamped);
  }

  /// Sets the overlay's opacity, within the range that stays readable.
  Future<void> setDesktopLyricOpacity(double value) async {
    final clamped = value.clamp(0.2, 1.0);
    state = state.copyWith(desktopLyricOpacity: clamped);
    await writeMusicPrefDouble(_desktopLyricOpacityKey, clamped);
  }

  /// Sets the overlay's text colour as 0xAARRGGBB.
  Future<void> setDesktopLyricTextColor(int value) async {
    state = state.copyWith(desktopLyricTextColor: value);
    await writeMusicPrefInt(_desktopLyricTextColorKey, value);
  }

  /// Sets the overlay's outline colour as 0xAARRGGBB.
  Future<void> setDesktopLyricStrokeColor(int value) async {
    state = state.copyWith(desktopLyricStrokeColor: value);
    await writeMusicPrefInt(_desktopLyricStrokeColorKey, value);
  }

  /// Sets the overlay's outline width; 0 turns the outline off.
  Future<void> setDesktopLyricStrokeWidth(double value) async {
    final clamped = value.clamp(0.0, 6.0);
    state = state.copyWith(desktopLyricStrokeWidth: clamped);
    await writeMusicPrefDouble(_desktopLyricStrokeWidthKey, clamped);
  }

  /// Sets the overlay's line gap, 0–25 — the reference steps it by one
  /// between those bounds.
  Future<void> setDesktopLyricLineGap(int value) async {
    final clamped = value.clamp(0, 25);
    state = state.copyWith(desktopLyricLineGap: clamped);
    await writeMusicPrefInt(_desktopLyricLineGapKey, clamped);
  }

  /// Switches the overlay's bold main line.
  Future<void> setDesktopLyricBoldLine({required bool value}) async {
    state = state.copyWith(desktopLyricBoldLine: value);
    await writeMusicPrefBool(_desktopLyricBoldLineKey, value: value);
  }

  /// Switches the overlay's bold translation line.
  Future<void> setDesktopLyricBoldExtended({required bool value}) async {
    state = state.copyWith(desktopLyricBoldExtended: value);
    await writeMusicPrefBool(_desktopLyricBoldExtendedKey, value: value);
  }

  /// Toggles the vertical reading direction.
  Future<void> setDesktopLyricVertical({required bool value}) async {
    state = state.copyWith(desktopLyricVertical: value);
    await writeMusicPrefBool(_desktopLyricVerticalKey, value: value);
  }

  /// Sets the overlay's horizontal anchoring.
  Future<void> setDesktopLyricAlignment(audio.DesktopLyricAlignment value) async {
    state = state.copyWith(desktopLyricAlignment: value);
    await writeMusicPref(_desktopLyricAlignmentKey, value.name);
  }
}

/// The music module's desktop-lyric preferences.
final musicDesktopLyricsSettingsProvider =
    NotifierProvider<MusicDesktopLyricsSettingsController, MusicDesktopLyricsSettings>(
      MusicDesktopLyricsSettingsController.new,
    );
