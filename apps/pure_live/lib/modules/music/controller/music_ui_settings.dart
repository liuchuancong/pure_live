import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/l10n/translations.dart';

/// One decorative piece the module's surfaces can draw. The designs are
/// fixed; a choice only decides whether the piece appears.
enum MusicUiElement {
  /// The player page's blurred cover backdrop.
  blurredBackdrop,

  /// The live FFT bars on the player page's stage.
  spectrum,

  /// The 推荐 page's banner, above its first row.
  recommendBanner,
}

/// What the player's stage draws: the sleeve as it is, the record on a
/// turntable, or the words alone — the reference's three player modes.
enum MusicPlayerMode {
  /// The square cover card, the default.
  standard,

  /// The record, its cover as the label, with the tonearm.
  vinyl,

  /// The lyrics in the stage's place, for reading along.
  lyrics;

  /// The mode's name where a person reads it.
  String label(Translations t) => switch (this) {
    MusicPlayerMode.standard => t.music.playerModeStandard,
    MusicPlayerMode.vinyl => t.music.playerModeVinyl,
    MusicPlayerMode.lyrics => t.music.playerModeLyrics,
  };
}

/// How the stage's live visualiser draws the engine's own data: vertical
/// bars, a ring around a hole, or a time-domain wave.
enum MusicSpectrumStyle {
  /// Vertical bars, one per FFT band.
  bars,

  /// The same bands as spokes on a ring.
  circle,

  /// The live PCM samples as a mirrored wave.
  wave;

  /// The style's name where a person reads it.
  String label(Translations t) => switch (this) {
    MusicSpectrumStyle.bars => t.music.spectrumStyleBars,
    MusicSpectrumStyle.circle => t.music.spectrumStyleCircle,
    MusicSpectrumStyle.wave => t.music.spectrumStyleWave,
  };
}

/// The stored key of the player's mode.
const String kMusicPlayerModeKey = 'music.playerMode';

/// Owns the player's default mode under `music.playerMode`.
final class MusicPlayerModeController extends Notifier<MusicPlayerMode> {
  @override
  MusicPlayerMode build() {
    try {
      return MusicPlayerMode.values.asNameMap()[StoragePrefs.getString(kMusicPlayerModeKey) ?? ''] ??
          MusicPlayerMode.standard;
    } on Object {
      return MusicPlayerMode.standard;
    }
  }

  /// Chooses the default stage and writes it through.
  Future<void> set(MusicPlayerMode mode) async {
    state = mode;
    try {
      await StoragePrefs.setString(kMusicPlayerModeKey, mode.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Back to the reference's standard stage.
  Future<void> reset() => set(MusicPlayerMode.standard);
}

/// The default stage every player surface starts from.
final musicPlayerModeProvider = NotifierProvider<MusicPlayerModeController, MusicPlayerMode>(
  MusicPlayerModeController.new,
);

/// The stage chosen on the player page this run, or null while the stored
/// default still decides. The settings row is a default; the page's own
/// switch overrides it without writing it, so a visit never rewrites the
/// preference the viewer set deliberately.
final class MusicStageOverride extends Notifier<MusicPlayerMode?> {
  @override
  MusicPlayerMode? build() => null;

  /// Takes this run's stage.
  void choose(MusicPlayerMode mode) {
    if (state == mode) return;
    state = mode;
  }
}

/// The stage the player page draws: this run's choice, else the default.
final musicStageOverrideProvider = NotifierProvider<MusicStageOverride, MusicPlayerMode?>(MusicStageOverride.new);

/// Which pieces the module's surfaces draw, and how the visualiser draws
/// its data.
@immutable
final class MusicUiSettings {
  /// Creates the settings.
  const MusicUiSettings(this.hidden, {this.spectrumStyle = MusicSpectrumStyle.bars});

  /// Hides exactly [hidden].
  factory MusicUiSettings.hiding(
    Iterable<MusicUiElement> hidden, {
    MusicSpectrumStyle spectrumStyle = MusicSpectrumStyle.bars,
  }) => MusicUiSettings(Set.unmodifiable(hidden), spectrumStyle: spectrumStyle);

  /// Reads stored settings; anything unreadable falls back to the default.
  factory MusicUiSettings.fromJson(Object? value) {
    if (value is! Map) return standard;
    final hidden = value['hidden'];
    final elements = <MusicUiElement>{};
    if (hidden is List) {
      for (final name in hidden) {
        if (name is! String) continue;
        for (final element in MusicUiElement.values) {
          if (element.name == name) {
            elements.add(element);
            break;
          }
        }
      }
    }
    // A store written before the style existed has no key; bars is what it
    // drew then.
    final storedStyle = value['spectrumStyle'];
    final style = storedStyle is String ? MusicSpectrumStyle.values.asNameMap()[storedStyle] : null;
    return MusicUiSettings.hiding(elements, spectrumStyle: style ?? MusicSpectrumStyle.bars);
  }

  /// The designed default: every piece drawn, as bars.
  static const MusicUiSettings standard = MusicUiSettings({});

  /// The pieces not drawn.
  final Set<MusicUiElement> hidden;

  /// How the live visualiser draws its data.
  final MusicSpectrumStyle spectrumStyle;

  /// Whether [element] is drawn.
  bool shows(MusicUiElement element) => !hidden.contains(element);

  /// A copy with [element] on or off.
  MusicUiSettings withElement(MusicUiElement element, {required bool visible}) {
    final next = {...hidden};
    visible ? next.remove(element) : next.add(element);
    return MusicUiSettings.hiding(next, spectrumStyle: spectrumStyle);
  }

  /// A copy drawing the visualiser [style].
  MusicUiSettings withSpectrumStyle(MusicSpectrumStyle style) => MusicUiSettings.hiding(hidden, spectrumStyle: style);

  /// The stored form.
  Map<String, Object?> toJson() => {
    'hidden': [
      for (final element in MusicUiElement.values)
        if (hidden.contains(element)) element.name,
    ],
    'spectrumStyle': spectrumStyle.name,
  };

  @override
  bool operator ==(Object other) =>
      other is MusicUiSettings &&
      other.spectrumStyle == spectrumStyle &&
      other.hidden.length == hidden.length &&
      other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hash(spectrumStyle, Object.hashAllUnordered(hidden));
}

/// The key the visibility lives under; one set for every device.
const String kMusicUiPrefsKey = 'interface.musicUi';

/// Owns the module's element visibility and visualiser style under
/// `interface.musicUi`.
final class MusicUiSettingsController extends Notifier<MusicUiSettings> {
  @override
  MusicUiSettings build() {
    final String? raw;
    try {
      raw = StoragePrefs.getString(kMusicUiPrefsKey);
    } on Object {
      return MusicUiSettings.standard;
    }
    if (raw == null || raw.trim().isEmpty) return MusicUiSettings.standard;
    try {
      return MusicUiSettings.fromJson(jsonDecode(raw));
    } on Object {
      return MusicUiSettings.standard;
    }
  }

  /// Replaces the settings and writes them through.
  Future<void> set(MusicUiSettings settings) async {
    state = settings;
    try {
      await StoragePrefs.setString(kMusicUiPrefsKey, jsonEncode(settings.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts one piece on or off.
  Future<void> setElement(MusicUiElement element, {required bool visible}) =>
      set(state.withElement(element, visible: visible));

  /// Draws the visualiser [style].
  Future<void> setSpectrumStyle(MusicSpectrumStyle style) => set(state.withSpectrumStyle(style));

  /// Puts the player back to the designed default.
  Future<void> reset() => set(MusicUiSettings.standard);
}

/// The settings every module surface draws.
final musicUiSettingsProvider = NotifierProvider<MusicUiSettingsController, MusicUiSettings>(
  MusicUiSettingsController.new,
);
