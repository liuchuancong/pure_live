import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The portrait-stream adaptation: whether it applies, its height and layout policies, its danmaku mode, and the per-room overrides.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class PortraitPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.portraitAdapt = true,
    this.portraitAdaptiveHeight = true,
    this.portraitLayoutMode = 'balanced',
    this.portraitFullscreenPolicy = 'followSource',
    this.portraitDisplayMode = 'ambient',
    this.portraitDanmakuMode = 'followGlobal',
    this.rememberPortraitRoomOverride = true,
    this.showPortraitDiagnostics = false,
    this.portraitRoomOverrides = const {},
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory PortraitPreferences.fromJson(Map<String, Object?> json) {
    return PortraitPreferences(
      portraitAdapt: json['portraitAdapt'] as bool? ?? true,
      portraitAdaptiveHeight: json['portraitAdaptiveHeight'] as bool? ?? true,
      portraitLayoutMode: json['portraitLayoutMode'] as String? ?? 'balanced',
      portraitFullscreenPolicy: json['portraitFullscreenPolicy'] as String? ?? 'followSource',
      portraitDisplayMode: json['portraitDisplayMode'] as String? ?? 'ambient',
      portraitDanmakuMode: json['portraitDanmakuMode'] as String? ?? 'followGlobal',
      rememberPortraitRoomOverride: json['rememberPortraitRoomOverride'] as bool? ?? true,
      showPortraitDiagnostics: json['showPortraitDiagnostics'] as bool? ?? false,
      portraitRoomOverrides:
          (json['portraitRoomOverrides'] as Map<Object?, Object?>?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
  }

  /// Whether a decoded tall frame re-dresses the room for a vertical stream
  /// (the reference's 智能识别竖屏直播源); off, every source plays in the
  /// plain landscape stack.
  final bool portraitAdapt;

  /// Whether the sheet's ceiling follows the body — a tall source gets the
  /// bigger watch area while the chat list keeps its room (the reference's
  /// portraitAdaptiveHeight). Off, the panel sits fixed at the middle stop.
  final bool portraitAdaptiveHeight;

  /// The normal-page shape for a vertical source: `balanced` (sheet over the
  /// full-bleed picture), `immersive` (same, opening at the lowest panel),
  /// `compatibility` (the plain letterboxed stack, like landscape rooms).
  final String portraitLayoutMode;

  /// Which direction a fullscreen entry takes for a vertical source:
  /// `followSource` keeps the picture upright (portrait fullscreen),
  /// `followSystem` defers to the device, `landscape` always turns the
  /// sideways room.
  final String portraitFullscreenPolicy;

  /// The portrait-fullscreen canvas: `complete` (no backdrop, the fitted
  /// picture), `ambient` (blurred cover behind it — the reference's own
  /// default), `balanced` (ambient, lighter veil), `cover` (cropped to fill).
  final String portraitDisplayMode;

  /// How the flying barrage is bounded over a vertical source's picture:
  /// `followGlobal`, `upperQuarter` (top quarter only), `reduced` (half the
  /// rows), `hidden`; it bounds the overlay, never the global style numbers.
  final String portraitDanmakuMode;

  /// Whether a direction picked by hand in the player is remembered for the
  /// room (the reference's portraitRoomOverrides).
  final bool rememberPortraitRoomOverride;

  /// Whether the picture shows the detection read-out — source size, ratio
  /// and the rule in force (the reference's 显示识别状态).
  final bool showPortraitDiagnostics;

  /// The per-room direction overrides: room key to `portrait`/`landscape`.
  final Map<String, String> portraitRoomOverrides;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'portraitAdapt': portraitAdapt,
    'portraitAdaptiveHeight': portraitAdaptiveHeight,
    'portraitLayoutMode': portraitLayoutMode,
    'portraitFullscreenPolicy': portraitFullscreenPolicy,
    'portraitDisplayMode': portraitDisplayMode,
    'portraitDanmakuMode': portraitDanmakuMode,
    'rememberPortraitRoomOverride': rememberPortraitRoomOverride,
    'showPortraitDiagnostics': showPortraitDiagnostics,
    'portraitRoomOverrides': portraitRoomOverrides,
  };

  /// Returns a copy with the given fields replaced.
  PortraitPreferences copyWith({
    bool? portraitAdapt,
    bool? portraitAdaptiveHeight,
    String? portraitLayoutMode,
    String? portraitFullscreenPolicy,
    String? portraitDisplayMode,
    String? portraitDanmakuMode,
    bool? rememberPortraitRoomOverride,
    bool? showPortraitDiagnostics,
    Map<String, String>? portraitRoomOverrides,
  }) => PortraitPreferences(
    portraitAdapt: portraitAdapt ?? this.portraitAdapt,
    portraitAdaptiveHeight: portraitAdaptiveHeight ?? this.portraitAdaptiveHeight,
    portraitLayoutMode: portraitLayoutMode ?? this.portraitLayoutMode,
    portraitFullscreenPolicy: portraitFullscreenPolicy ?? this.portraitFullscreenPolicy,
    portraitDisplayMode: portraitDisplayMode ?? this.portraitDisplayMode,
    portraitDanmakuMode: portraitDanmakuMode ?? this.portraitDanmakuMode,
    rememberPortraitRoomOverride: rememberPortraitRoomOverride ?? this.rememberPortraitRoomOverride,
    showPortraitDiagnostics: showPortraitDiagnostics ?? this.showPortraitDiagnostics,
    portraitRoomOverrides: portraitRoomOverrides ?? this.portraitRoomOverrides,
  );

  @override
  List<Object?> get props => [
    portraitAdapt,
    portraitAdaptiveHeight,
    portraitLayoutMode,
    portraitFullscreenPolicy,
    portraitDisplayMode,
    portraitDanmakuMode,
    rememberPortraitRoomOverride,
    showPortraitDiagnostics,
    portraitRoomOverrides,
  ];
}
