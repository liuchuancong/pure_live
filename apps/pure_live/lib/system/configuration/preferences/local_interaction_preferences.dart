import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The local interaction card: whether the app joins its own room's interaction, and the name and colour it uses — the reference's `localInteraction` section.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class LocalInteractionPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.localInteractionEnabled = false,
    this.localInteractionUserName = '',
    this.localInteractionColor = 0xFFFFFFFF,
    this.localInteractionExperience = 0,
    this.localInteractionPreset = 'clean',
    this.localInteractionGiftBanner = true,
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory LocalInteractionPreferences.fromJson(Map<String, Object?> json) {
    return LocalInteractionPreferences(
      localInteractionEnabled: json['localInteractionEnabled'] as bool? ?? false,
      localInteractionUserName: json['localInteractionUserName'] as String? ?? '',
      localInteractionColor: (json['localInteractionColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      localInteractionExperience: (json['localInteractionExperience'] as num?)?.toInt() ?? 0,
      localInteractionPreset: json['localInteractionPreset'] as String? ?? 'clean',
      localInteractionGiftBanner: json['localInteractionGiftBanner'] as bool? ?? true,
    );
  }

  /// Whether the room's local-interaction composer and bus are live — the
  /// reference's `localInteraction.enabled` gate on the same feature.
  final bool localInteractionEnabled;

  /// The name the local messages carry. Empty draws the localized "me".
  final String localInteractionUserName;

  /// The colour local messages are drawn in, packed ARGB.
  final int localInteractionColor;

  /// The local experience the viewer's own lines and gifts accumulate; the
  /// level in the badge is this figure's arithmetic (500 per level).
  final int localInteractionExperience;

  /// The local danmaku preset the viewer's own lines draw with — the
  /// catalogue's id, `clean` for the shipping look.
  final String localInteractionPreset;

  /// Whether a gift the viewer sends raises the banner over the picture.
  final bool localInteractionGiftBanner;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'localInteractionEnabled': localInteractionEnabled,
    'localInteractionUserName': localInteractionUserName,
    'localInteractionColor': localInteractionColor,
    'localInteractionExperience': localInteractionExperience,
    'localInteractionPreset': localInteractionPreset,
    'localInteractionGiftBanner': localInteractionGiftBanner,
  };

  /// Returns a copy with the given fields replaced.
  LocalInteractionPreferences copyWith({
    bool? localInteractionEnabled,
    String? localInteractionUserName,
    int? localInteractionColor,
    int? localInteractionExperience,
    String? localInteractionPreset,
    bool? localInteractionGiftBanner,
  }) => LocalInteractionPreferences(
    localInteractionEnabled: localInteractionEnabled ?? this.localInteractionEnabled,
    localInteractionUserName: localInteractionUserName ?? this.localInteractionUserName,
    localInteractionColor: localInteractionColor ?? this.localInteractionColor,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [
    localInteractionEnabled,
    localInteractionUserName,
    localInteractionColor,
    localInteractionExperience,
    localInteractionPreset,
    localInteractionGiftBanner,
  ];
}
