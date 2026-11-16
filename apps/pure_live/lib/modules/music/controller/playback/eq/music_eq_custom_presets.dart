import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';

/// The preference the viewer's own presets are kept under.
const String kMusicCustomPresetsKey = 'music.eq.customPresets';

/// The `presetId` prefix that marks the configuration as riding one of the
/// viewer's own presets — `custom:<id>`, never colliding with the built-ins.
const String kMusicCustomPresetPrefix = 'custom:';

/// Whether [presetId] points at one of the viewer's own presets, and if so
/// which one.
(String, String)? customPresetIdOf(String? presetId) {
  if (presetId == null || !presetId.startsWith(kMusicCustomPresetPrefix)) return null;
  final id = presetId.substring(kMusicCustomPresetPrefix.length);
  return id.isEmpty ? null : (kMusicCustomPresetPrefix, id);
}

/// One preset the viewer saved themselves: a name and the curve — the ten
/// bands, the preamp, the enhancement effects — they were hearing when they
/// named it. Same contract as a built-in, plus the effects a built-in
/// doesn't carry.
@immutable
final class MusicCustomEqPreset {
  /// Creates a preset.
  const MusicCustomEqPreset({
    required this.id,
    required this.name,
    required this.gains,
    required this.preampDb,
    this.effects = const <String, MusicFxNode>{},
  });

  /// Reads a stored preset; null when the entry is damaged.
  static MusicCustomEqPreset? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final gains = json['gains'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) return null;
    if (gains is! List || gains.length != kMusicEqFrequencies.length) return null;
    final parsed = <double>[];
    for (final gain in gains) {
      final value = (gain as num?)?.toDouble();
      if (value == null) return null;
      parsed.add(value.clamp(kMusicEqMinGain, kMusicEqMaxGain));
    }
    final rawEffects = json['effects'];
    final effects = <String, MusicFxNode>{};
    if (rawEffects is Map) {
      for (final entry in rawEffects.entries) {
        final node = MusicFxNode.fromJson(entry.value);
        final known = kMusicFxOrder.contains('${entry.key}') || kMusicFxSpatialOrder.contains('${entry.key}');
        if (node != null && known) effects['${entry.key}'] = node;
      }
    }
    return MusicCustomEqPreset(
      id: id,
      name: name,
      gains: parsed,
      preampDb: ((json['preamp'] as num?)?.toDouble() ?? 0).clamp(kMusicEqMinPreamp, kMusicEqMaxPreamp),
      effects: effects,
    );
  }

  /// Stable within one storage lifetime.
  final String id;

  /// The name the viewer typed.
  final String name;

  /// One gain per [kMusicEqFrequencies] entry, in dB.
  final List<double> gains;

  /// The preamp that rode the curve, in dB.
  final double preampDb;

  /// The enhancement effects that rode the curve.
  final Map<String, MusicFxNode> effects;

  /// The stored shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'gains': gains,
    'preamp': preampDb,
    if (effects.isNotEmpty)
      'effects': <String, Object?>{for (final entry in effects.entries) entry.key: entry.value.toJson()},
  };
}

/// The viewer's saved presets, persisted under [kMusicCustomPresetsKey].
final class MusicCustomPresetController extends Notifier<List<MusicCustomEqPreset>> {
  @override
  List<MusicCustomEqPreset> build() {
    try {
      final raw = StoragePrefs.getString(kMusicCustomPresetsKey);
      if (raw == null || raw.isEmpty) return const <MusicCustomEqPreset>[];
      final list = jsonDecode(raw);
      if (list is! List) return const <MusicCustomEqPreset>[];
      return [for (final entry in list) ?MusicCustomEqPreset.fromJson(entry)];
    } on Object {
      return const <MusicCustomEqPreset>[];
    }
  }

  /// Snapshots the configuration in force as a new preset.
  Future<MusicCustomEqPreset> save(String name) async {
    final eq = ref.read(musicEqProvider);
    final preset = MusicCustomEqPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      gains: List<double>.of(eq.gains),
      preampDb: eq.preampDb,
      effects: Map.of(eq.effects),
    );
    await _write([preset, ...state]);
    return preset;
  }

  /// Forgets the preset with [id]; the configuration itself is untouched —
  /// it keeps its curve and simply stops being a preset's.
  Future<void> remove(String id) async {
    await _write([
      for (final preset in state)
        if (preset.id != id) preset,
    ]);
  }

  Future<void> _write(List<MusicCustomEqPreset> presets) async {
    state = presets;
    try {
      await StoragePrefs.setString(
        kMusicCustomPresetsKey,
        jsonEncode(<Object?>[for (final preset in presets) preset.toJson()]),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's saved presets the module edits.
final musicCustomPresetsProvider = NotifierProvider<MusicCustomPresetController, List<MusicCustomEqPreset>>(
  MusicCustomPresetController.new,
);
