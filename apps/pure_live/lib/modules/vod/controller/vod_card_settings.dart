import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// One piece a Bilibili card draws. The cards' layout is fixed — the live
/// module's cover ink, the counts in capsules at the cover foot's start, the
/// length in a capsule at its end, the uploader's picture at the head of the
/// information area with the name under the title, the poster's score in its
/// one corner or the state there with the state line under the name — and
/// a choice here only says whether a piece appears at all.
enum VodCardElement {
  /// The play figure at the cover's foot, its start.
  plays,

  /// The danmaku count beside the play figure.
  danmaku,

  /// The length in the dark capsule at the cover's foot's end.
  duration,

  /// The uploader's name under the title.
  uploader,

  /// The uploader's picture at the start of the card's information area.
  avatar,

  /// The poster card's state: where the season stands
  /// (更新至第 12 话 / 全 26 集 / 上映日) — in the poster's corner while no
  /// score takes it, else on the line under the name.
  seasonState,

  /// The poster card's score, in the accent's ink in the poster's corner.
  seasonScore,
}

/// Which pieces a card draws — the archive card and the poster card read the
/// same set, each taking the pieces it has.
@immutable
final class VodCardVisibility {
  /// Creates a visibility set.
  const VodCardVisibility(this.hidden);

  /// Hides exactly [hidden].
  factory VodCardVisibility.hiding(Iterable<VodCardElement> hidden) => VodCardVisibility(Set.unmodifiable(hidden));

  /// Reads stored visibility; anything unreadable falls back to the default.
  factory VodCardVisibility.fromJson(Object? value) {
    if (value is! Map) return standard;
    final hidden = value['hidden'];
    if (hidden is! List) return standard;
    final elements = <VodCardElement>{};
    for (final name in hidden) {
      if (name is! String) continue;
      for (final element in VodCardElement.values) {
        if (element.name == name) {
          elements.add(element);
          break;
        }
      }
    }
    return VodCardVisibility.hiding(elements);
  }

  /// The designed default: every piece drawn, the way the station lays them.
  static const VodCardVisibility standard = VodCardVisibility({});

  /// The pieces not drawn.
  final Set<VodCardElement> hidden;

  /// Whether [element] is drawn.
  bool shows(VodCardElement element) => !hidden.contains(element);

  /// A copy with [element] on or off.
  VodCardVisibility withElement(VodCardElement element, {required bool visible}) {
    final next = {...hidden};
    visible ? next.remove(element) : next.add(element);
    return VodCardVisibility.hiding(next);
  }

  /// The stored form.
  Map<String, Object?> toJson() => {
    'hidden': [
      for (final element in VodCardElement.values)
        if (hidden.contains(element)) element.name,
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is VodCardVisibility && other.hidden.length == hidden.length && other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hashAllUnordered(hidden);
}

/// The key the card visibility lives under; one set for every device.
const String kVodCardPrefsKey = 'interface.vodCard';

/// Owns the browse cards' visibility under `interface.vodCard`.
final class VodCardSettingsController extends Notifier<VodCardVisibility> {
  @override
  VodCardVisibility build() {
    final String? raw;
    try {
      raw = StoragePrefs.getString(kVodCardPrefsKey);
    } on Object {
      return VodCardVisibility.standard;
    }
    if (raw == null || raw.trim().isEmpty) return VodCardVisibility.standard;
    try {
      return VodCardVisibility.fromJson(jsonDecode(raw));
    } on Object {
      return VodCardVisibility.standard;
    }
  }

  /// Replaces the visibility and writes it through.
  Future<void> set(VodCardVisibility visibility) async {
    state = visibility;
    try {
      await StoragePrefs.setString(kVodCardPrefsKey, jsonEncode(visibility.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts one piece on or off.
  Future<void> setElement(VodCardElement element, {required bool visible}) =>
      set(state.withElement(element, visible: visible));
}

/// The card visibility every browse grid draws.
final vodCardSettingsProvider = NotifierProvider<VodCardSettingsController, VodCardVisibility>(
  VodCardSettingsController.new,
);
