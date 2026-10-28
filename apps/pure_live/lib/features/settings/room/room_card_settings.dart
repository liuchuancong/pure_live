import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';

/// Which set of room-card choices a surface reads (the reference's
/// `RoomCardViewport`): phones and tablets use [mobile], desktops and TVs
/// use [desktop].
enum RoomCardViewport {
  /// The touch shell's cards.
  mobile,

  /// The windowed shell's cards.
  desktop,
}

/// One piece a card can draw. The card and row designs are fixed; a choice
/// only decides whether the piece appears.
enum RoomCardElement {
  /// The room's title.
  title,

  /// The room's category over the grid card's cover (虚拟主播, 游戏区…).
  coverType,

  /// The anchor's avatar.
  avatar,

  /// The anchor's name.
  anchorName,

  /// The platform mark in the grid cover's top-left corner.
  platformBadge,

  /// The audience figure.
  audience,

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

/// The cover's shape on a grid card.
enum RoomCardCoverAspect {
  /// 16:9, the shape most platforms stream in.
  wide(16 / 9),

  /// 4:3, taller tiles for feeds with squarer pictures.
  boxed(4 / 3);

  RoomCardCoverAspect(this.coverRatio);

  /// The cover's width over height.
  final double coverRatio;

  /// The stored name's value, falling back to the default shape.
  static RoomCardCoverAspect fromName(String? name) => name == boxed.name ? boxed : wide;
}

/// The information area under a grid card's cover: room for the avatar with
/// the title and the anchor aligned beside it, and nothing more.
const double kRoomCardInfoExtent = 56;

/// The grid tile's height for a card [width] wide: the cover keeps its shape
/// and the information area keeps [kRoomCardInfoExtent] — a wider tile gets
/// a wider cover, never a taller title block.
double roomCardTileHeight(double width, {required RoomCardCoverAspect cover}) =>
    width / cover.coverRatio + kRoomCardInfoExtent;

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

/// Both viewports' appearances (the reference keeps two independent sets).
typedef RoomCardTargets = ({RoomCardAppearance mobile, RoomCardAppearance desktop});

/// The reference's defaults: the standard preset on both targets.
const RoomCardTargets _targetDefaults = (mobile: RoomCardAppearance.standard, desktop: RoomCardAppearance.standard);

/// The persisted keys one viewport's appearance lives under.
const String kRoomCardMobilePrefsKey = 'interface.roomCard.mobile';
const String kRoomCardDesktopPrefsKey = 'interface.roomCard.desktop';

/// Owns both viewports' card appearances under `interface.roomCard.*`.
final class RoomCardSettingsController extends Notifier<RoomCardTargets> {
  @override
  RoomCardTargets build() {
    try {
      return (mobile: _read(RoomCardViewport.mobile), desktop: _read(RoomCardViewport.desktop));
    } on Object {
      return _targetDefaults;
    }
  }

  static RoomCardAppearance _read(RoomCardViewport viewport) {
    final String? raw;
    try {
      raw = switch (viewport) {
        RoomCardViewport.mobile => StoragePrefs.getString(kRoomCardMobilePrefsKey),
        RoomCardViewport.desktop => StoragePrefs.getString(kRoomCardDesktopPrefsKey),
      };
    } on Object {
      return RoomCardAppearance.standard;
    }
    if (raw == null || raw.trim().isEmpty) return RoomCardAppearance.standard;
    try {
      return RoomCardAppearance.fromJson(jsonDecode(raw));
    } on Object {
      return RoomCardAppearance.standard;
    }
  }

  /// The appearance one viewport reads.
  RoomCardAppearance forViewport(RoomCardViewport viewport) =>
      viewport == RoomCardViewport.mobile ? state.mobile : state.desktop;

  /// Replaces one viewport's appearance and writes it through; the preset
  /// follows from the values, as in the reference.
  Future<void> update(RoomCardViewport viewport, RoomCardAppearance appearance) async {
    final next = (
      mobile: viewport == RoomCardViewport.mobile ? appearance : state.mobile,
      desktop: viewport == RoomCardViewport.desktop ? appearance : state.desktop,
    );
    state = next;
    try {
      switch (viewport) {
        case RoomCardViewport.mobile:
          await StoragePrefs.setString(kRoomCardMobilePrefsKey, jsonEncode(appearance.toJson()));
        case RoomCardViewport.desktop:
          await StoragePrefs.setString(kRoomCardDesktopPrefsKey, jsonEncode(appearance.toJson()));
      }
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Puts one viewport's display back to the designed default.
  Future<void> reset(RoomCardViewport viewport) => update(viewport, RoomCardAppearance.standard);
}

/// Both viewports' card appearances.
final roomCardSettingsProvider = NotifierProvider<RoomCardSettingsController, RoomCardTargets>(
  RoomCardSettingsController.new,
);

/// The appearance the current device's cards use: phones and tablets read
/// the mobile set, desktop windows and TVs the desktop set.
final roomCardAppearanceProvider = Provider<RoomCardAppearance>((ref) {
  final profile = ref.watch(deviceProfileProvider);
  final targets = ref.watch(roomCardSettingsProvider);
  return profile == DeviceProfile.mobile ? targets.mobile : targets.desktop;
});
