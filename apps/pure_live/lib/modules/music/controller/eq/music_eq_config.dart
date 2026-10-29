import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The preference the sound-effect configuration is kept under.
const String kMusicEqKey = 'music.eq';

/// The graphic equalizer's band centre frequencies, in Hz.
///
/// The sound-effect spec fixes ten bands: 31 Hz … 16 kHz, one octave apart.
const List<double> kMusicEqFrequencies = <double>[31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

/// One band's gain bounds, in dB.
const double kMusicEqMinGain = -12;
const double kMusicEqMaxGain = 12;

/// The preamp's bounds, in dB.
const double kMusicEqMinPreamp = -12;
const double kMusicEqMaxPreamp = 6;

/// Every band's Q — the spec's default, spoken to FFmpeg as `t=q:w=1`.
const double kMusicEqBandQ = 1;

/// The parametric nodes' bounds: centre frequency in Hz, Q, gain in dB.
const double kMusicEqNodeMinFrequency = 20;
const double kMusicEqNodeMaxFrequency = 20000;
const double kMusicEqNodeMinQ = 0.1;
const double kMusicEqNodeMaxQ = 10;
const int kMusicEqMaxNodes = 8;

/// One sound-effect configuration: the ten-band graphic EQ plus its preamp.
///
/// The stored shape is the structured model, never the FFmpeg string — the
/// filter chain is derived, so a version upgrade re-derives instead of
/// parsing what mpv was last sent.
@immutable
final class MusicEqConfig {
  /// Creates a configuration.
  const MusicEqConfig({
    required this.enabled,
    required this.preampDb,
    required this.gains,
    this.presetId,
    this.effects = const <String, MusicFxNode>{},
    this.analysis = false,
    this.nodes = const <MusicEqNode>[],
  });

  /// Reads a stored configuration; null when the entry is damaged.
  static MusicEqConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final gains = json['gains'];
    if (gains is! List || gains.length != kMusicEqFrequencies.length) return null;
    final parsed = <double>[];
    for (final gain in gains) {
      final value = (gain as num?)?.toDouble();
      if (value == null) return null;
      parsed.add(value.clamp(kMusicEqMinGain, kMusicEqMaxGain));
    }
    final nodes = <MusicEqNode>[];
    final rawNodes = json['nodes'];
    if (rawNodes is List) {
      for (final raw in rawNodes) {
        final node = MusicEqNode.fromJson(raw);
        if (node != null) nodes.add(node);
      }
    }
    final rawEffects = json['effects'];
    final effects = <String, MusicFxNode>{};
    if (rawEffects is Map) {
      for (final entry in rawEffects.entries) {
        final node = MusicFxNode.fromJson(entry.value);
        if (node != null && kMusicFxOrder.contains('${entry.key}')) effects['${entry.key}'] = node;
      }
    }
    return MusicEqConfig(
      enabled: json['enabled'] == true,
      preampDb: ((json['preamp'] as num?)?.toDouble() ?? 0).clamp(kMusicEqMinPreamp, kMusicEqMaxPreamp),
      gains: parsed,
      presetId: json['presetId'] is String ? json['presetId'] as String : null,
      effects: effects,
      analysis: json['analysis'] == true,
      nodes: nodes,
    );
  }

  /// Whether the chain reaches mpv at all — the master bypass.
  final bool enabled;

  /// The pre-adjustment gain applied before the bands, in dB.
  final double preampDb;

  /// One gain per [kMusicEqFrequencies] entry, in dB.
  final List<double> gains;

  /// The preset these gains came from, for the picker's highlight; null for
  /// a hand-tuned curve.
  final String? presetId;

  /// The enhancement effects, keyed by [kMusicFxOrder] ids; an absent id is
  /// off. The structured form travels in the stored JSON, never the filters.
  final Map<String, MusicFxNode> effects;

  /// Whether the loudness probe rides in the chain: an `ebur128` filter
  /// measures the mix and reports levels for the meter. It changes no
  /// sound — it is analysis, not processing.
  final bool analysis;

  /// The parametric EQ nodes — free frequency/Q/gain peaks stacked on top
  /// of the graphic bands. Order is the chain order; at most
  /// [kMusicEqMaxNodes].
  final List<MusicEqNode> nodes;

  /// The stored shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': 2,
    'enabled': enabled,
    'preamp': preampDb,
    'gains': gains,
    if (presetId != null) 'presetId': presetId,
    if (effects.isNotEmpty)
      'effects': <String, Object?>{
        for (final entry in effects.entries) entry.key: entry.value.toJson(),
      },
    'analysis': analysis,
    if (nodes.isNotEmpty)
      'nodes': <Object?>[for (final node in nodes) node.toJson()],
  };

  /// A copy with selected fields replaced.
  MusicEqConfig copyWith({
    bool? enabled,
    double? preampDb,
    List<double>? gains,
    String? presetId,
    Map<String, MusicFxNode>? effects,
    bool? analysis,
    List<MusicEqNode>? nodes,
    bool clearPreset = false,
  }) => MusicEqConfig(
    enabled: enabled ?? this.enabled,
    preampDb: preampDb ?? this.preampDb,
    gains: gains ?? this.gains,
    presetId: clearPreset ? null : (presetId ?? this.presetId),
    effects: effects ?? this.effects,
    analysis: analysis ?? this.analysis,
    nodes: nodes ?? this.nodes,
  );

  /// [id]'s node, or an off node when the effect was never touched.
  MusicFxNode effectOf(String id) => effects[id] ?? kMusicFxOff;

  /// Whether [id] is switched on with a usable amount.
  bool effectOn(String id) {
    final node = effectOf(id);
    return node.enabled && node.amount > 0.01;
  }

  /// Whether every band sits at zero — a flat response, whatever the preamp.
  bool get isFlat => gains.every((gain) => gain.abs() < 0.05);
}

/// The enhancement effects, in the order their filters enter the chain.
///
/// Each id maps to a real FFmpeg filter in `music_eq_dsp.dart` — the switch
/// never claims an effect the engine cannot run.
const List<String> kMusicFxOrder = <String>['loudness', 'bass', 'vocal', 'width', 'surround', 'dynamics'];

/// One effect's saved state: its switch and how hard it works (0–1).
@immutable
final class MusicFxNode {
  /// Creates a node.
  const MusicFxNode({required this.enabled, required this.amount});

  /// Reads a stored node; null when the entry is damaged.
  static MusicFxNode? fromJson(Object? json) {
    if (json is! Map) return null;
    final amount = (json['amount'] as num?)?.toDouble();
    if (amount == null) return null;
    return MusicFxNode(enabled: json['enabled'] == true, amount: amount.clamp(0, 1));
  }

  /// The effect's switch.
  final bool enabled;

  /// How strong the effect works, 0–1; the DSP layer turns it into the
  /// filter's own units.
  final double amount;

  /// The stored shape.
  Map<String, Object?> toJson() => <String, Object?>{'enabled': enabled, 'amount': amount};

  /// A copy with selected fields replaced.
  MusicFxNode copyWith({bool? enabled, double? amount}) =>
      MusicFxNode(enabled: enabled ?? this.enabled, amount: amount ?? this.amount);
}

/// The off node every effect starts as.
const MusicFxNode kMusicFxOff = MusicFxNode(enabled: false, amount: 0.5);

/// One parametric EQ node: a free-frequency peaking filter.
///
/// The graphic bands sit on fixed octave centres; these let the viewer
/// reach whatever the recording actually needs — a 7.3 kHz whistle, a
/// 55 Hz wool blanket — with its own Q. The structured values travel in
/// storage; the filter string is derived, never kept.
@immutable
final class MusicEqNode {
  /// Creates a node.
  const MusicEqNode({
    required this.id,
    required this.enabled,
    required this.frequency,
    required this.q,
    required this.gainDb,
  });

  /// A fresh node at 1 kHz, Q 1, +3 dB.
  factory MusicEqNode.fresh(String id) =>
      const MusicEqNode(id: '', enabled: true, frequency: 1000, q: 1, gainDb: 3).copyWith(id: id);

  /// Reads a stored node; null when the entry is damaged.
  static MusicEqNode? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final frequency = (json['frequency'] as num?)?.toDouble();
    final q = (json['q'] as num?)?.toDouble();
    final gainDb = (json['gainDb'] as num?)?.toDouble();
    if (id is! String || id.isEmpty || frequency == null || q == null || gainDb == null) return null;
    return MusicEqNode(
      id: id,
      enabled: json['enabled'] != false,
      frequency: frequency.clamp(kMusicEqNodeMinFrequency, kMusicEqNodeMaxFrequency),
      q: q.clamp(kMusicEqNodeMinQ, kMusicEqNodeMaxQ),
      gainDb: gainDb.clamp(kMusicEqMinGain, kMusicEqMaxGain),
    );
  }

  /// Stable within one storage lifetime; only the UI needs it.
  final String id;

  /// The node's bypass switch.
  final bool enabled;

  /// Centre frequency in Hz, 20–20k.
  final double frequency;

  /// Bandwidth sharpness, 0.1–10.
  final double q;

  /// Peak gain in dB, -12…+12.
  final double gainDb;

  /// The stored shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'enabled': enabled,
    'frequency': frequency,
    'q': q,
    'gainDb': gainDb,
  };

  /// A copy with selected fields replaced.
  MusicEqNode copyWith({String? id, bool? enabled, double? frequency, double? q, double? gainDb}) => MusicEqNode(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    q: q ?? this.q,
    gainDb: gainDb ?? this.gainDb,
  );
}

/// A built-in sound effect: a name key and the gains the viewer hears.
///
/// The name speaks a target character, not a promise — a preset cannot know
/// the headphone or speaker it lands on.
@immutable
final class MusicEqPreset {
  /// Creates a preset.
  const MusicEqPreset({required this.id, required this.gains});

  /// The stable id the configuration remembers.
  final String id;

  /// One gain per band, in dB.
  final List<double> gains;
}

/// The built-in presets, ordered as the sound-effect centre lists them.
final List<MusicEqPreset> kMusicEqPresets = <MusicEqPreset>[
  const MusicEqPreset(id: 'pop', gains: <double>[-1, 1, 3, 4, 3, 1, -1, -1, -1, -1]),
  const MusicEqPreset(id: 'rock', gains: <double>[5, 4, 2, -1, -2, 0, 3, 5, 5, 4]),
  const MusicEqPreset(id: 'classical', gains: <double>[3, 3, 2, 1, -1, -1, 0, 2, 3, 3]),
  const MusicEqPreset(id: 'jazz', gains: <double>[3, 2, 1, 2, -1, -1, 0, 1, 2, 3]),
  const MusicEqPreset(id: 'electronic', gains: <double>[5, 4, 1, 0, -2, 1, 1, 3, 4, 5]),
  const MusicEqPreset(id: 'bass', gains: <double>[7, 6, 5, 3, 1, 0, 0, 0, 1, 1]),
  const MusicEqPreset(id: 'vocal', gains: <double>[-2, -1, 0, 2, 4, 5, 4, 2, 0, -1]),
  const MusicEqPreset(id: 'live', gains: <double>[-1, 0, 1, 2, 3, 3, 2, 1, 1, 0]),
  const MusicEqPreset(id: 'flat', gains: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
];

/// The viewer's sound-effect configuration, persisted under `music.eq`.
final class MusicEqController extends Notifier<MusicEqConfig> {
  @override
  MusicEqConfig build() {
    try {
      final raw = StoragePrefs.getString(kMusicEqKey);
      if (raw == null || raw.isEmpty) return kMusicEqPresets.last.enabledFlat;
      final parsed = MusicEqConfig.fromJson(jsonDecode(raw));
      return parsed ?? kMusicEqPresets.last.enabledFlat;
    } on Object {
      return kMusicEqPresets.last.enabledFlat;
    }
  }

  /// Replaces the whole configuration and persists it.
  Future<void> update(MusicEqConfig next) async {
    state = next;
    await _save();
  }

  /// Sets one band's gain; the curve stops being a preset's.
  Future<void> setGain(int band, double gain) async {
    final gains = List<double>.of(state.gains);
    gains[band] = gain.clamp(kMusicEqMinGain, kMusicEqMaxGain);
    await update(state.copyWith(gains: gains, clearPreset: true));
  }

  /// Sets the preamp gain.
  Future<void> setPreamp(double preampDb) async {
    await update(state.copyWith(preampDb: preampDb.clamp(kMusicEqMinPreamp, kMusicEqMaxPreamp)));
  }

  /// Applies a preset's gains, remembering which one the curve came from.
  Future<void> applyPreset(MusicEqPreset preset) async {
    await update(state.copyWith(gains: List<double>.of(preset.gains), presetId: preset.id));
  }

  /// Turns the loudness probe on or off.
  Future<void> setAnalysis({required bool value}) async {
    await update(state.copyWith(analysis: value));
  }

  /// Adds a fresh parametric node at 1 kHz; silently no-op at the cap.
  Future<void> addNode() async {
    if (state.nodes.length >= kMusicEqMaxNodes) return;
    final node = MusicEqNode.fresh(DateTime.now().microsecondsSinceEpoch.toString());
    await update(state.copyWith(nodes: [...state.nodes, node]));
  }

  /// Removes the parametric node with [id].
  Future<void> removeNode(String id) async {
    await update(state.copyWith(nodes: state.nodes.where((node) => node.id != id).toList()));
  }

  /// Rewrites one parametric node's fields.
  Future<void> updateNode(String id, {bool? enabled, double? frequency, double? q, double? gainDb}) async {
    await update(
      state.copyWith(
        nodes: [
          for (final node in state.nodes)
            if (node.id == id) node.copyWith(enabled: enabled, frequency: frequency, q: q, gainDb: gainDb) else node,
        ],
      ),
    );
  }

  Future<void> setEffect(String id, {bool? enabled, double? amount}) async {
    final next = state.effectOf(id).copyWith(enabled: enabled, amount: amount);
    await update(state.copyWith(effects: {...state.effects, id: next}));
  }

  /// Zeroes every band and the preamp — the spec's reset.
  Future<void> reset() async {
    await update(kMusicEqPresets.last.enabledFlat.copyWith(enabled: state.enabled));
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kMusicEqKey, jsonEncode(state.toJson()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

extension on MusicEqPreset {
  MusicEqConfig get enabledFlat =>
      MusicEqConfig(enabled: true, preampDb: 0, gains: List<double>.of(gains), presetId: id);
}

/// The sound-effect configuration the module edits.
final musicEqProvider = NotifierProvider<MusicEqController, MusicEqConfig>(MusicEqController.new);

/// Whether the engine refused the last chain this player tried to apply.
///
/// The sound-effect spec's honesty rule: a filter that did not take effect
/// says so, instead of the switch sitting on and the sound staying plain.
final musicEqApplyFailedProvider = StateProvider<bool>((ref) => false);
