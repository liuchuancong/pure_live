import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// One decorative piece the player's surfaces can draw. The designs are
/// fixed; a choice only decides whether the piece appears.
enum MusicUiElement {
  /// The player page's blurred cover backdrop.
  blurredBackdrop,

  /// The record peeking out behind the stage's artwork.
  vinylDisc,

  /// The live FFT bars on the player page's stage.
  spectrum,
}

/// Which pieces the player draws.
@immutable
final class MusicUiVisibility {
  /// Creates a visibility set.
  const MusicUiVisibility(this.hidden);

  /// Hides exactly [hidden].
  factory MusicUiVisibility.hiding(Iterable<MusicUiElement> hidden) =>
      MusicUiVisibility(Set.unmodifiable(hidden));

  /// Reads stored visibility; anything unreadable falls back to the default.
  factory MusicUiVisibility.fromJson(Object? value) {
    if (value is! Map) return standard;
    final hidden = value['hidden'];
    if (hidden is! List) return standard;
    final elements = <MusicUiElement>{};
    for (final name in hidden) {
      if (name is! String) continue;
      for (final element in MusicUiElement.values) {
        if (element.name == name) {
          elements.add(element);
          break;
        }
      }
    }
    return MusicUiVisibility.hiding(elements);
  }

  /// The designed default: every piece drawn.
  static const MusicUiVisibility standard = MusicUiVisibility({});

  /// The pieces not drawn.
  final Set<MusicUiElement> hidden;

  /// Whether [element] is drawn.
  bool shows(MusicUiElement element) => !hidden.contains(element);

  /// A copy with [element] on or off.
  MusicUiVisibility withElement(MusicUiElement element, {required bool visible}) {
    final next = {...hidden};
    visible ? next.remove(element) : next.add(element);
    return MusicUiVisibility.hiding(next);
  }

  /// The stored form.
  Map<String, Object?> toJson() => {
    'hidden': [
      for (final element in MusicUiElement.values)
        if (hidden.contains(element)) element.name,
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is MusicUiVisibility && other.hidden.length == hidden.length && other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hashAllUnordered(hidden);
}

/// The key the visibility lives under; one set for every device.
const String kMusicUiPrefsKey = 'interface.musicUi';

/// Owns the player's visibility under `interface.musicUi`.
final class MusicUiSettingsController extends Notifier<MusicUiVisibility> {
  @override
  MusicUiVisibility build() {
    final String? raw;
    try {
      raw = StoragePrefs.getString(kMusicUiPrefsKey);
    } on Object {
      return MusicUiVisibility.standard;
    }
    if (raw == null || raw.trim().isEmpty) return MusicUiVisibility.standard;
    try {
      return MusicUiVisibility.fromJson(jsonDecode(raw));
    } on Object {
      return MusicUiVisibility.standard;
    }
  }

  /// Replaces the visibility and writes it through.
  Future<void> set(MusicUiVisibility visibility) async {
    state = visibility;
    try {
      await StoragePrefs.setString(kMusicUiPrefsKey, jsonEncode(visibility.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts one piece on or off.
  Future<void> setElement(MusicUiElement element, {required bool visible}) =>
      set(state.withElement(element, visible: visible));

  /// Puts the player back to the designed default.
  Future<void> reset() => set(MusicUiVisibility.standard);
}

/// The visibility every player surface draws.
final musicUiSettingsProvider = NotifierProvider<MusicUiSettingsController, MusicUiVisibility>(
  MusicUiSettingsController.new,
);
