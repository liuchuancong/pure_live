import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// One piece a card can draw. The card and row designs are fixed; a choice
/// only decides whether the piece appears.
enum RoomCardElement {
  /// The room's title.
  title,

  /// The audience figure — the room's heat.
  audience,

  /// The room's category over the grid card's cover (虚拟主播, 游戏区…).
  coverType,

  /// The anchor's avatar.
  avatar,

  /// The anchor's name.
  anchorName,

  /// The platform mark in the grid cover's top-left corner.
  platformBadge,

  /// The pill naming a recording (the one state a feed cannot assume).
  status,
}

/// The list row's design height, padding included: the avatar beside the
/// title, the streamer and the audience; a feed's list layout keeps its
/// tiles this tall so the row design is never stretched.
const double kRoomCardListDesignHeight = 88;

/// The list row's height when the card carries its tags under the meta
/// line — the follows page's rows — one line taller than the plain row.
const double kRoomCardListTagsHeight = kRoomCardListDesignHeight + 20;

/// Which pieces a card draws. Both shapes read the same set: the grid card
/// places them on its cover and information line, the list row folds them
/// into its text and trailing figures — the cover-only chip simply has no
/// place there.
@immutable
final class RoomCardVisibility {
  /// Creates a visibility set.
  const RoomCardVisibility(this.hidden);

  /// Hides exactly [hidden].
  factory RoomCardVisibility.hiding(Iterable<RoomCardElement> hidden) => RoomCardVisibility(Set.unmodifiable(hidden));

  /// Reads stored visibility: the current list, the old canvas placements'
  /// visible flags, or the older boolean flags.
  factory RoomCardVisibility.fromJson(Object? value) {
    if (value is! Map) return standard;
    final hidden = value['hidden'];
    if (hidden is List) {
      return RoomCardVisibility.hiding(_elementsNamed(hidden));
    }
    final placements = value['gridLayout'] ?? value['listLayout'];
    if (placements is Map) {
      final hiddenElements = <RoomCardElement>{};
      for (final element in RoomCardElement.values) {
        final stored = placements[element.name];
        if (stored is Map && stored['visible'] == false) hiddenElements.add(element);
      }
      return RoomCardVisibility.hiding(hiddenElements);
    }
    // The pre-canvas flags: absent means shown.
    final platform = value['platformBadge'];
    final legacyHidden = <RoomCardElement>{
      if (value['showAvatar'] == false) RoomCardElement.avatar,
      if (value['showAnchorName'] == false) RoomCardElement.anchorName,
      if (value['showAudience'] == false) RoomCardElement.audience,
      if (platform == 'hidden') RoomCardElement.platformBadge,
    };
    return RoomCardVisibility.hiding(legacyHidden);
  }

  /// The designed default: every piece drawn.
  static const RoomCardVisibility standard = RoomCardVisibility({});

  /// The pieces not drawn.
  final Set<RoomCardElement> hidden;

  /// Whether [element] is drawn.
  bool shows(RoomCardElement element) => !hidden.contains(element);

  /// A copy with [element] on or off.
  RoomCardVisibility withElement(RoomCardElement element, {required bool visible}) {
    final next = {...hidden};
    visible ? next.remove(element) : next.add(element);
    return RoomCardVisibility.hiding(next);
  }

  /// The stored form.
  Map<String, Object?> toJson() => {
    'hidden': [
      for (final element in RoomCardElement.values)
        if (hidden.contains(element)) element.name,
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is RoomCardVisibility && other.hidden.length == hidden.length && other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hashAllUnordered(hidden);

  static Iterable<RoomCardElement> _elementsNamed(Iterable<Object?> names) sync* {
    for (final name in names) {
      if (name is! String) continue;
      for (final element in RoomCardElement.values) {
        if (element.name == name) {
          yield element;
          break;
        }
      }
    }
  }
}

/// The grid cover's width over height: 16:9, the shape most platforms
/// stream in. The card's design fixes it — the tile height comes from the
/// cover's shape plus a fixed information block, so a free ratio would only
/// offer ways to make every card taller.
const double kRoomCardCoverRatio = 16 / 9;

/// The information area under a grid card's cover: room for the avatar with
/// the title and the anchor aligned beside it, and nothing more.
const double kRoomCardInfoExtent = 56;

/// The grid tile's height for a card [width] wide: the cover keeps its shape
/// and the information area keeps [kRoomCardInfoExtent] — a wider tile gets
/// a wider cover, never a taller title block.
double roomCardTileHeight(double width) => width / kRoomCardCoverRatio + kRoomCardInfoExtent;

/// One viewport's card appearance: which pieces show. The designs
/// themselves are fixed, and every piece is its own property — there are no
/// bundled presets to overwrite them. Corners follow the theme's card radius.
@immutable
final class RoomCardAppearance {
  /// Creates an appearance.
  const RoomCardAppearance({required this.visibility});

  /// Reads a stored object, including the older arrangement and flag forms.
  factory RoomCardAppearance.fromJson(Object? value, {RoomCardAppearance fallback = standard}) {
    if (value is! Map) return fallback;
    return RoomCardAppearance(visibility: RoomCardVisibility.fromJson(value));
  }

  /// The designed default: the standard visibility.
  static const RoomCardAppearance standard = RoomCardAppearance(visibility: RoomCardVisibility.standard);

  /// Which pieces the card draws.
  final RoomCardVisibility visibility;

  /// A copy with selected fields replaced.
  RoomCardAppearance copyWith({RoomCardVisibility? visibility}) =>
      RoomCardAppearance(visibility: visibility ?? this.visibility);

  /// Shows or hides one piece.
  RoomCardAppearance withElement(RoomCardElement element, {required bool visible}) =>
      copyWith(visibility: visibility.withElement(element, visible: visible));

  /// The stored form.
  Map<String, Object?> toJson() => visibility.toJson();

  @override
  bool operator ==(Object other) => other is RoomCardAppearance && other.visibility == visibility;

  @override
  int get hashCode => visibility.hashCode;
}

/// The key the appearance lives under; one set for every device.
const String kRoomCardPrefsKey = 'interface.roomCard';

/// The per-viewport keys older builds wrote; read once to carry a stored set
/// over, never written again.
const String kRoomCardMobilePrefsKey = 'interface.roomCard.mobile';
const String kRoomCardDesktopPrefsKey = 'interface.roomCard.desktop';

/// Owns the card appearance under `interface.roomCard`.
///
/// One set serves phones, desktops and TVs alike: the designs are the same
/// card and row everywhere, so a choice made on one device holds on the next.
final class RoomCardSettingsController extends Notifier<RoomCardAppearance> {
  @override
  RoomCardAppearance build() {
    try {
      return _read(kRoomCardPrefsKey) ??
          _read(kRoomCardDesktopPrefsKey) ??
          _read(kRoomCardMobilePrefsKey) ??
          RoomCardAppearance.standard;
    } on Object {
      return RoomCardAppearance.standard;
    }
  }

  /// The stored appearance under [key]; null when absent or unreadable.
  static RoomCardAppearance? _read(String key) {
    final String? raw;
    try {
      raw = StoragePrefs.getString(key);
    } on Object {
      return null;
    }
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return RoomCardAppearance.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  /// Replaces the appearance and writes it through.
  Future<void> set(RoomCardAppearance appearance) async {
    state = appearance;
    try {
      await StoragePrefs.setString(kRoomCardPrefsKey, jsonEncode(appearance.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts the display back to the designed default.
  Future<void> reset() => set(RoomCardAppearance.standard);
}

/// The card appearance every surface draws.
final roomCardSettingsProvider = NotifierProvider<RoomCardSettingsController, RoomCardAppearance>(
  RoomCardSettingsController.new,
);
