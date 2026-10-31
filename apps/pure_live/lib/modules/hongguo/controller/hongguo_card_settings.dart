import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// One piece a series card can draw. The card's design is fixed; a choice
/// only decides whether the piece appears.
enum HongguoCardElement {
  /// The board position flag in the cover's top-left corner.
  rank,

  /// The source's own corner tags (爆剧 / 新剧 / 独播).
  coverTags,

  /// The episode-count chip on the cover's top edge.
  episodes,

  /// The 今日 marker on the cover's top edge.
  today,

  /// The score chip on the cover's top edge.
  score,

  /// The heat text along the cover's foot.
  hot,

  /// The listing line under the title (heat · category).
  meta,
}

/// Which pieces a series card draws.
@immutable
final class HongguoCardVisibility {
  /// Creates a visibility set.
  const HongguoCardVisibility(this.hidden);

  /// Hides exactly [hidden].
  factory HongguoCardVisibility.hiding(Iterable<HongguoCardElement> hidden) =>
      HongguoCardVisibility(Set.unmodifiable(hidden));

  /// Reads stored visibility; anything unreadable falls back to the default.
  factory HongguoCardVisibility.fromJson(Object? value) {
    if (value is! Map) return standard;
    final hidden = value['hidden'];
    if (hidden is! List) return standard;
    final elements = <HongguoCardElement>{};
    for (final name in hidden) {
      if (name is! String) continue;
      for (final element in HongguoCardElement.values) {
        if (element.name == name) {
          elements.add(element);
          break;
        }
      }
    }
    return HongguoCardVisibility.hiding(elements);
  }

  /// The designed default: every piece drawn.
  static const HongguoCardVisibility standard = HongguoCardVisibility({});

  /// The pieces not drawn.
  final Set<HongguoCardElement> hidden;

  /// Whether [element] is drawn.
  bool shows(HongguoCardElement element) => !hidden.contains(element);

  /// A copy with [element] on or off.
  HongguoCardVisibility withElement(HongguoCardElement element, {required bool visible}) {
    final next = {...hidden};
    visible ? next.remove(element) : next.add(element);
    return HongguoCardVisibility.hiding(next);
  }

  /// The stored form.
  Map<String, Object?> toJson() => {
    'hidden': [
      for (final element in HongguoCardElement.values)
        if (hidden.contains(element)) element.name,
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is HongguoCardVisibility && other.hidden.length == hidden.length && other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hashAllUnordered(hidden);
}

/// The key the card visibility lives under; one set for every device.
const String kHongguoCardPrefsKey = 'interface.hongguoCard';

/// Owns the series card's visibility under `interface.hongguoCard`.
final class HongguoCardSettingsController extends Notifier<HongguoCardVisibility> {
  @override
  HongguoCardVisibility build() {
    final String? raw;
    try {
      raw = StoragePrefs.getString(kHongguoCardPrefsKey);
    } on Object {
      return HongguoCardVisibility.standard;
    }
    if (raw == null || raw.trim().isEmpty) return HongguoCardVisibility.standard;
    try {
      return HongguoCardVisibility.fromJson(jsonDecode(raw));
    } on Object {
      return HongguoCardVisibility.standard;
    }
  }

  /// Replaces the visibility and writes it through.
  Future<void> set(HongguoCardVisibility visibility) async {
    state = visibility;
    try {
      await StoragePrefs.setString(kHongguoCardPrefsKey, jsonEncode(visibility.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts one piece on or off.
  Future<void> setElement(HongguoCardElement element, {required bool visible}) =>
      set(state.withElement(element, visible: visible));

  /// Puts the card back to the designed default.
  Future<void> reset() => set(HongguoCardVisibility.standard);
}

/// The card visibility every surface draws.
final hongguoCardSettingsProvider = NotifierProvider<HongguoCardSettingsController, HongguoCardVisibility>(
  HongguoCardSettingsController.new,
);
