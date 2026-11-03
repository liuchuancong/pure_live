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

  /// The 今日 marker, as one of the cover's state candidates.
  today,

  /// The score, as one of the cover's state candidates.
  score,

  /// The episode count, as one of the cover's state candidates. The corner
  /// holds one state, and the listing's own reading is the last of them.
  episodes,

  /// The red heart naming a title this device keeps, at the cover's end —
  /// what a followed room's heart is on the room card. Off, the corner keeps
  /// the state alone and the shelf is tended from the card's menu.
  favorite,

  /// The heat text along the cover's foot.
  hot,

  /// The categories chip along the cover's foot.
  category,

  /// The listing line under the title (whatever the cover's own corners
  /// leave out — the heat or the categories, whichever their switch closed).
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
  ///
  /// An element's name is its stored identity and none has ever changed, so a
  /// set written before a piece existed leaves that piece to the designed
  /// default rather than losing the choices it did record: an absent name means
  /// drawn and an unknown one is skipped.
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

  /// The designed default. The episode count and the score are off: the cover
  /// carries one state pill, and where a poster wall has to choose, the
  /// viewer's own progress and the station's newest marker read before them.
  static const HongguoCardVisibility standard = HongguoCardVisibility({
    HongguoCardElement.episodes,
    HongguoCardElement.score,
  });

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
