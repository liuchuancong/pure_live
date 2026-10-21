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
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory LocalInteractionPreferences.fromJson(Map<String, Object?> json) {
    return LocalInteractionPreferences(
      localInteractionEnabled: json['localInteractionEnabled'] as bool? ?? false,
      localInteractionUserName: json['localInteractionUserName'] as String? ?? '',
      localInteractionColor: (json['localInteractionColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
    );
  }

  /// Whether the room's local-interaction composer and bus are live — the
  /// reference's `localInteraction.enabled` gate on the same feature.
  final bool localInteractionEnabled;

  /// The name the local messages carry. Empty draws the localized "me".
  final String localInteractionUserName;

  /// The colour local messages are drawn in, packed ARGB.
  final int localInteractionColor;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'localInteractionEnabled': localInteractionEnabled,
    'localInteractionUserName': localInteractionUserName,
    'localInteractionColor': localInteractionColor,
  };

  /// Returns a copy with the given fields replaced.
  LocalInteractionPreferences copyWith({
    bool? localInteractionEnabled,
    String? localInteractionUserName,
    int? localInteractionColor,
  }) => LocalInteractionPreferences(
    localInteractionEnabled: localInteractionEnabled ?? this.localInteractionEnabled,
    localInteractionUserName: localInteractionUserName ?? this.localInteractionUserName,
    localInteractionColor: localInteractionColor ?? this.localInteractionColor,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [localInteractionEnabled, localInteractionUserName, localInteractionColor];
}
