import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// How much of the picture the comments may cover — the reference's 密度.
enum HongguoDanmakuDensity {
  /// A third of the rows the picture holds.
  sparse('sparse', 1 / 3),

  /// Two thirds.
  normal('normal', 2 / 3),

  /// Every row that fits.
  dense('dense', 1);

  HongguoDanmakuDensity(this.wire, this.share);

  /// The name the preference keeps.
  final String wire;

  /// The share of the rows this density uses.
  final double share;

  /// The name the settings row shows.
  String label(Translations t) => switch (this) {
    HongguoDanmakuDensity.sparse => t.hongguo.danmakuDensitySparse,
    HongguoDanmakuDensity.normal => t.hongguo.danmakuDensityNormal,
    HongguoDanmakuDensity.dense => t.hongguo.danmakuDensityDense,
  };
}

/// How the comments look and where they fly.
@immutable
final class HongguoDanmakuSettings {
  /// Creates the settings.
  const HongguoDanmakuSettings({
    this.enabled = true,
    this.fontSize = 24,
    this.opacity = 0.9,
    this.speed = 1,
    this.density = HongguoDanmakuDensity.normal,
  });

  /// Reads a stored value, clamping whatever a hand-edited file says.
  factory HongguoDanmakuSettings.fromJson(Map<String, Object?> json) {
    final size = (json['fontSize'] as num?)?.toDouble();
    final opacity = (json['opacity'] as num?)?.toDouble();
    final speed = (json['speed'] as num?)?.toDouble();
    final wire = json['density'];
    return HongguoDanmakuSettings(
      enabled: json['enabled'] != false,
      fontSize: (size ?? 24).clamp(14, 40).toDouble(),
      opacity: (opacity ?? 0.9).clamp(0.2, 1).toDouble(),
      speed: (speed ?? 1).clamp(0.5, 2).toDouble(),
      density: HongguoDanmakuDensity.values.firstWhere(
        (density) => density.wire == wire,
        orElse: () => HongguoDanmakuDensity.normal,
      ),
    );
  }

  /// The reference's defaults: on, a readable size, nearly opaque, 1×.
  static const HongguoDanmakuSettings standard = HongguoDanmakuSettings();

  /// Whether comments are drawn at all.
  final bool enabled;

  /// The text size in logical pixels.
  final double fontSize;

  /// The text's opacity, 0.2..1.
  final double opacity;

  /// The flying speed, 0.5×..2×.
  final double speed;

  /// How much of the picture the comments may cover.
  final HongguoDanmakuDensity density;

  /// The row height the layout budgets for each comment.
  double get lineHeight => fontSize * 1.7;

  /// How many rows [height] holds at this size and density; at least one.
  int lanesFor(double height) {
    if (height <= 0) return 1;
    final fit = (height / lineHeight).floor();
    return (fit * density.share).round().clamp(1, 8);
  }

  /// A copy with selected fields replaced.
  HongguoDanmakuSettings copyWith({
    bool? enabled,
    double? fontSize,
    double? opacity,
    double? speed,
    HongguoDanmakuDensity? density,
  }) => HongguoDanmakuSettings(
    enabled: enabled ?? this.enabled,
    fontSize: fontSize ?? this.fontSize,
    opacity: opacity ?? this.opacity,
    speed: speed ?? this.speed,
    density: density ?? this.density,
  );

  /// The preference's own shape.
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'fontSize': fontSize,
    'opacity': opacity,
    'speed': speed,
    'density': density.wire,
  };
}

/// The key the comment settings are kept under.
const String kHongguoDanmakuPrefsKey = 'hongguo.danmaku';

/// Owns the comment settings.
final class HongguoDanmakuSettingsController extends Notifier<HongguoDanmakuSettings> {
  @override
  HongguoDanmakuSettings build() {
    try {
      final raw = StoragePrefs.getString(kHongguoDanmakuPrefsKey);
      if (raw == null || raw.isEmpty) return HongguoDanmakuSettings.standard;
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? HongguoDanmakuSettings.fromJson(json) : HongguoDanmakuSettings.standard;
    } on Object {
      return HongguoDanmakuSettings.standard;
    }
  }

  /// Turns the comments on or off.
  Future<void> setEnabled({required bool value}) async {
    state = state.copyWith(enabled: value);
    await _save();
  }

  /// Sets the text size; clamped to 14..40.
  Future<void> setFontSize(double value) async {
    state = state.copyWith(fontSize: value.clamp(14, 40).toDouble());
    await _save();
  }

  /// Sets the text opacity; clamped to 0.2..1.
  Future<void> setOpacity(double value) async {
    state = state.copyWith(opacity: value.clamp(0.2, 1).toDouble());
    await _save();
  }

  /// Sets the flying speed; clamped to 0.5×..2×.
  Future<void> setSpeed(double value) async {
    state = state.copyWith(speed: value.clamp(0.5, 2).toDouble());
    await _save();
  }

  /// Sets how much of the picture the comments may cover.
  Future<void> setDensity(HongguoDanmakuDensity value) async {
    state = state.copyWith(density: value);
    await _save();
  }

  Future<void> _save() async {
    try {
      unawaited(StoragePrefs.setString(kHongguoDanmakuPrefsKey, jsonEncode(state.toJson())));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The comment settings.
final hongguoDanmakuSettingsProvider = NotifierProvider<HongguoDanmakuSettingsController, HongguoDanmakuSettings>(
  HongguoDanmakuSettingsController.new,
);

/// Picks the row a comment flies in, so two comments never overlap on one
/// row. A row is free when its last comment started at least [minGapMs] ago;
/// when every row is busy the comment is dropped, as the reference does.
final class HongguoDanmakuPlanner {
  /// Creates a planner; [minGapMs] is the headway between two comments on
  /// one row.
  HongguoDanmakuPlanner({this.minGapMs = 700});

  /// The headway between two comments on one row.
  final int minGapMs;

  static const int _never = -(1 << 40);
  final List<int> _lastSpawn = [];

  /// Forgets every row, as a seek does.
  void reset() => _lastSpawn.clear();

  /// The row to use at [positionMs], or null when every row is busy.
  int? laneFor(int positionMs, {required int lanes}) {
    if (lanes <= 0) return null;
    var best = -1;
    var oldest = 0;
    for (var lane = 0; lane < lanes; lane++) {
      final last = lane < _lastSpawn.length ? _lastSpawn[lane] : _never;
      if (best < 0 || last < oldest) {
        best = lane;
        oldest = last;
      }
    }
    if (positionMs - oldest < minGapMs) return null;
    while (_lastSpawn.length <= best) {
      _lastSpawn.add(_never);
    }
    _lastSpawn[best] = positionMs;
    return best;
  }
}
