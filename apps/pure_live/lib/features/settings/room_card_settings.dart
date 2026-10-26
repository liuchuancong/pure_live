import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show DeviceProfile, deviceProfileProvider;

/// Which set of room-card choices a surface reads (the reference's
/// `RoomCardViewport`): phones and tablets use [mobile], desktops and TVs
/// use [desktop].
enum RoomCardViewport {
  /// The touch shell's cards.
  mobile,

  /// The windowed shell's cards.
  desktop,
}

/// The card's two shapes (the reference's `RoomCardLayout`).
enum RoomCardLayout {
  /// The 16:9 cover over a caption.
  cover,

  /// A coverless identity row.
  compact,
}

/// When the platform badge appears (the reference's
/// `RoomCardPlatformBadgeMode`).
enum RoomCardPlatformBadgeMode {
  /// On when the card is wide enough for a caption badge.
  automatic,

  /// Always on the cover (compact rows show it when wide enough).
  always,

  /// Never.
  hidden,
}

/// The reference's four quick presets; [custom] is derived, never applied.
enum RoomCardPreset {
  /// Coverless compact row, small radius.
  compact,

  /// The standard cover card.
  standard,

  /// The standard cover card with the platform badge pinned on.
  detailed,

  /// Anything the viewer changed by hand.
  custom,
}

/// One viewport's card appearance (the reference's `RoomCardAppearance`),
/// stored as one JSON object under `interface.roomCard.<viewport>`.
@immutable
final class RoomCardAppearance {
  /// Creates an appearance.
  const RoomCardAppearance({
    required this.layout,
    required this.showAvatar,
    required this.showAnchorName,
    required this.showAudience,
    required this.showReplayBadge,
    required this.platformBadge,
    required this.cornerRadius,
  });

  /// Reads a stored object; malformed fields fall back to [fallback]'s,
  /// out-of-range radii are clamped, and a damaged value never half-applies.
  factory RoomCardAppearance.fromJson(Object? value, {RoomCardAppearance fallback = standard}) {
    if (value is! Map) return fallback;
    final json = Map<String, Object?>.from(value);

    bool flag(String name, {required bool otherwise}) {
      final field = json[name];
      return field is bool ? field : otherwise;
    }

    final radius = json['cornerRadius'];
    final badge = json['platformBadge'];
    return RoomCardAppearance(
      layout: switch (json['layout']) {
        'compact' => RoomCardLayout.compact,
        'cover' => RoomCardLayout.cover,
        _ => fallback.layout,
      },
      showAvatar: flag('showAvatar', otherwise: fallback.showAvatar),
      showAnchorName: flag('showAnchorName', otherwise: fallback.showAnchorName),
      showAudience: flag('showAudience', otherwise: fallback.showAudience),
      showReplayBadge: flag('showReplayBadge', otherwise: fallback.showReplayBadge),
      platformBadge: switch (badge) {
        'automatic' => RoomCardPlatformBadgeMode.automatic,
        'always' => RoomCardPlatformBadgeMode.always,
        'hidden' => RoomCardPlatformBadgeMode.hidden,
        _ => fallback.platformBadge,
      },
      cornerRadius: radius is num ? normalizeCornerRadius(radius) : fallback.cornerRadius,
    );
  }

  /// The designed default corner radius.
  static const double defaultCornerRadius = 20;

  /// The smallest corner radius.
  static const double minCornerRadius = 0;

  /// The largest corner radius.
  static const double maxCornerRadius = 32;

  /// The reference's compact preset.
  static const RoomCardAppearance compact = RoomCardAppearance(
    layout: RoomCardLayout.compact,
    showAvatar: true,
    showAnchorName: true,
    showAudience: true,
    showReplayBadge: true,
    platformBadge: RoomCardPlatformBadgeMode.hidden,
    cornerRadius: 12,
  );

  /// The reference's standard preset.
  static const RoomCardAppearance standard = RoomCardAppearance(
    layout: RoomCardLayout.cover,
    showAvatar: true,
    showAnchorName: true,
    showAudience: true,
    showReplayBadge: true,
    platformBadge: RoomCardPlatformBadgeMode.automatic,
    cornerRadius: defaultCornerRadius,
  );

  /// The reference's detailed preset.
  static const RoomCardAppearance detailed = RoomCardAppearance(
    layout: RoomCardLayout.cover,
    showAvatar: true,
    showAnchorName: true,
    showAudience: true,
    showReplayBadge: true,
    platformBadge: RoomCardPlatformBadgeMode.always,
    cornerRadius: defaultCornerRadius,
  );

  /// The card's shape.
  final RoomCardLayout layout;

  /// Whether the anchor's avatar is drawn beside the title.
  final bool showAvatar;

  /// Whether the anchor's name sits under the title.
  final bool showAnchorName;

  /// Whether the audience figure is drawn.
  final bool showAudience;

  /// Whether replay/recording rooms carry the replay chip.
  final bool showReplayBadge;

  /// The platform badge's mode.
  final RoomCardPlatformBadgeMode platformBadge;

  /// The card's corner radius.
  final double cornerRadius;

  /// The appearance a preset stands for.
  static RoomCardAppearance fromPreset(RoomCardPreset preset) => switch (preset) {
    RoomCardPreset.compact => compact,
    RoomCardPreset.standard || RoomCardPreset.custom => standard,
    RoomCardPreset.detailed => detailed,
  };

  /// The preset this appearance matches, [RoomCardPreset.custom] otherwise.
  RoomCardPreset get preset {
    if (this == compact) return RoomCardPreset.compact;
    if (this == standard) return RoomCardPreset.standard;
    if (this == detailed) return RoomCardPreset.detailed;
    return RoomCardPreset.custom;
  }

  /// Clamps a radius to the reference's range.
  static double normalizeCornerRadius(num value) {
    final converted = value.toDouble();
    if (!converted.isFinite) return defaultCornerRadius;
    return converted.clamp(minCornerRadius, maxCornerRadius);
  }

  /// A copy with selected fields replaced.
  RoomCardAppearance copyWith({
    RoomCardLayout? layout,
    bool? showAvatar,
    bool? showAnchorName,
    bool? showAudience,
    bool? showReplayBadge,
    RoomCardPlatformBadgeMode? platformBadge,
    double? cornerRadius,
  }) => RoomCardAppearance(
    layout: layout ?? this.layout,
    showAvatar: showAvatar ?? this.showAvatar,
    showAnchorName: showAnchorName ?? this.showAnchorName,
    showAudience: showAudience ?? this.showAudience,
    showReplayBadge: showReplayBadge ?? this.showReplayBadge,
    platformBadge: platformBadge ?? this.platformBadge,
    cornerRadius: normalizeCornerRadius(cornerRadius ?? this.cornerRadius),
  );

  /// The stored form.
  Map<String, Object?> toJson() => {
    'layout': layout.name,
    'showAvatar': showAvatar,
    'showAnchorName': showAnchorName,
    'showAudience': showAudience,
    'showReplayBadge': showReplayBadge,
    'platformBadge': platformBadge.name,
    'cornerRadius': normalizeCornerRadius(cornerRadius),
  };

  @override
  bool operator ==(Object other) =>
      other is RoomCardAppearance &&
      other.layout == layout &&
      other.showAvatar == showAvatar &&
      other.showAnchorName == showAnchorName &&
      other.showAudience == showAudience &&
      other.showReplayBadge == showReplayBadge &&
      other.platformBadge == platformBadge &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(
    layout,
    showAvatar,
    showAnchorName,
    showAudience,
    showReplayBadge,
    platformBadge,
    cornerRadius,
  );
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

  /// Applies a quick preset; [RoomCardPreset.custom] never applies.
  Future<void> applyPreset(RoomCardViewport viewport, RoomCardPreset preset) async {
    if (preset == RoomCardPreset.custom) return;
    await update(viewport, RoomCardAppearance.fromPreset(preset));
  }

  /// Puts one viewport back to the standard preset.
  Future<void> reset(RoomCardViewport viewport) => applyPreset(viewport, RoomCardPreset.standard);
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
