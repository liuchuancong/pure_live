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

  /// The title chip over the grid card's cover.
  coverTitle,

  /// The anchor's avatar.
  avatar,

  /// The anchor's name.
  anchorName,

  /// The platform mark.
  platformBadge,

  /// The audience figure.
  audience,

  /// The replay/recording mark.
  replayBadge,

  /// The broadcast state, e.g. "live".
  status,
}

/// The list row's design height, padding included; a feed's list layout
/// keeps its tiles this tall so the row design is never stretched.
const double kRoomCardListDesignHeight = 100;

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
      if (value['showReplayBadge'] == false) RoomCardElement.replayBadge,
      if (platform == 'hidden') RoomCardElement.platformBadge,
    };
    return RoomCardVisibility.hiding(legacyHidden);
  }

  /// The designed default: every piece except the chip over the cover.
  static const RoomCardVisibility standard = RoomCardVisibility({RoomCardElement.coverTitle});

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

/// One viewport's card appearance: the corner radius and which pieces show.
/// The designs themselves are fixed, and every piece is its own property —
/// there are no bundled presets to overwrite them.
@immutable
final class RoomCardAppearance {
  /// Creates an appearance.
  const RoomCardAppearance({required this.cornerRadius, required this.visibility});

  /// Reads a stored object, including the older arrangement and flag forms.
  factory RoomCardAppearance.fromJson(Object? value, {RoomCardAppearance fallback = standard}) {
    if (value is! Map) return fallback;
    final json = Map<String, Object?>.from(value);
    final radius = json['cornerRadius'];
    return RoomCardAppearance(
      cornerRadius: radius is num ? normalizeCornerRadius(radius) : fallback.cornerRadius,
      visibility: RoomCardVisibility.fromJson(json),
    );
  }

  /// The designed default corner radius.
  static const double defaultCornerRadius = 20;

  /// The smallest corner radius.
  static const double minCornerRadius = 0;

  /// The largest corner radius.
  static const double maxCornerRadius = 32;

  /// The designed default: the standard visibility and corner radius.
  static const RoomCardAppearance standard = RoomCardAppearance(
    cornerRadius: defaultCornerRadius,
    visibility: RoomCardVisibility.standard,
  );

  /// The card's corner radius.
  final double cornerRadius;

  /// Which pieces the card draws.
  final RoomCardVisibility visibility;

  /// Clamps a radius to the design's range.
  static double normalizeCornerRadius(num value) {
    final converted = value.toDouble();
    if (!converted.isFinite) return defaultCornerRadius;
    return converted.clamp(minCornerRadius, maxCornerRadius);
  }

  /// A copy with selected fields replaced.
  RoomCardAppearance copyWith({double? cornerRadius, RoomCardVisibility? visibility}) => RoomCardAppearance(
    cornerRadius: normalizeCornerRadius(cornerRadius ?? this.cornerRadius),
    visibility: visibility ?? this.visibility,
  );

  /// Shows or hides one piece.
  RoomCardAppearance withElement(RoomCardElement element, {required bool visible}) =>
      copyWith(visibility: visibility.withElement(element, visible: visible));

  /// The stored form.
  Map<String, Object?> toJson() => {'cornerRadius': normalizeCornerRadius(cornerRadius), ...visibility.toJson()};

  @override
  bool operator ==(Object other) =>
      other is RoomCardAppearance && other.cornerRadius == cornerRadius && other.visibility == visibility;

  @override
  int get hashCode => Object.hash(cornerRadius, visibility);
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

  /// Puts one viewport's display back to the designed default, keeping its
  /// corner radius.
  Future<void> reset(RoomCardViewport viewport) =>
      update(viewport, forViewport(viewport).copyWith(visibility: RoomCardVisibility.standard));
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
