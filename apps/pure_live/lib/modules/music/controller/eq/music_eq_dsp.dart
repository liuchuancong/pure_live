import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';

/// The sample rate the theoretical response assumes.
///
/// A peaking biquad's magnitude only shifts slightly with the sample rate in
/// the audible band, and the graph is a prediction — the spec keeps the
/// predicted curve and any real FFT analysis separate, so a fixed rate is
/// honest here.
const double kMusicEqSampleRate = 48000;

/// One point of the predicted response curve.
@immutable
final class MusicEqResponsePoint {
  /// Creates a point.
  const MusicEqResponsePoint({required this.frequency, required this.gainDb});

  /// The frequency, in Hz.
  final double frequency;

  /// The summed band gains plus preamp, in dB.
  final double gainDb;
}

/// The predicted magnitude response of one peaking band, in dB at [frequency].
///
/// The RBJ cookbook's peaking EQ: `A = 10^(gain/40)`, `α = sin(ω₀)/(2Q)`,
/// and the transfer function evaluated on the unit circle. This is the same
/// filter FFmpeg's `equalizer=t=q:w=Q` builds, so the curve shows what the
/// chain will do rather than a drawn approximation.
double musicEqBandGainAt({
  required double frequency,
  required double centre,
  required double gainDb,
  double q = kMusicEqBandQ,
}) {
  if (gainDb.abs() < 0.001) return 0;
  final omega = 2 * math.pi * frequency / kMusicEqSampleRate;
  final omega0 = 2 * math.pi * centre / kMusicEqSampleRate;
  final alpha = math.sin(omega0) / (2 * q);
  final a = math.pow(10, gainDb / 40).toDouble();

  final b0 = 1 + alpha * a;
  final b1 = -2 * math.cos(omega0);
  final b2 = 1 - alpha * a;
  final a0 = 1 + alpha / a;
  final a1 = -2 * math.cos(omega0);
  final a2 = 1 - alpha / a;

  // |H(e^jω)|² = |B(e^jω)|² / |A(e^jω)|², each numerator term expanded into
  // cosines — cheaper and numerically kinder than complex arithmetic.
  final cosOmega = math.cos(omega);
  final cosTwo = math.cos(2 * omega);
  final numerator = b0 * b0 + b1 * b1 + b2 * b2 + 2 * (b0 * b1 + b1 * b2) * cosOmega + 2 * b0 * b2 * cosTwo;
  final denominator = a0 * a0 + a1 * a1 + a2 * a2 + 2 * (a0 * a1 + a1 * a2) * cosOmega + 2 * a0 * a2 * cosTwo;
  if (denominator <= 0 || numerator <= 0) return 0;
  return 10 * math.log(numerator / denominator) / math.ln10;
}

/// The predicted magnitude of a low shelf, in dB at [frequency] — the
/// shape FFmpeg's `bass=t=q` builds and the 低音增强 effect rides.
double musicEqLowShelfGainAt({required double frequency, required double gainDb, double q = 0.85}) {
  if (gainDb.abs() < 0.001) return 0;
  final omega = 2 * math.pi * frequency / kMusicEqSampleRate;
  const omega0 = 2 * math.pi * 105 / kMusicEqSampleRate;
  final alpha = math.sin(omega0) / (2 * q);
  final a = math.pow(10, gainDb / 40).toDouble();
  final twoSqrtAAlpha = 2 * math.sqrt(a) * alpha;

  final b0 = a * ((a + 1) - (a - 1) * math.cos(omega0) + twoSqrtAAlpha);
  final b1 = 2 * a * ((a - 1) - (a + 1) * math.cos(omega0));
  final b2 = a * ((a + 1) - (a - 1) * math.cos(omega0) - twoSqrtAAlpha);
  final a0 = (a + 1) + (a - 1) * math.cos(omega0) + twoSqrtAAlpha;
  final a1 = -2 * ((a - 1) + (a + 1) * math.cos(omega0));
  final a2 = (a + 1) + (a - 1) * math.cos(omega0) - twoSqrtAAlpha;

  final cosOmega = math.cos(omega);
  final cosTwo = math.cos(2 * omega);
  final numerator = b0 * b0 + b1 * b1 + b2 * b2 + 2 * (b0 * b1 + b1 * b2) * cosOmega + 2 * b0 * b2 * cosTwo;
  final denominator = a0 * a0 + a1 * a1 + a2 * a2 + 2 * (a0 * a1 + a1 * a2) * cosOmega + 2 * a0 * a2 * cosTwo;
  if (denominator <= 0 || numerator <= 0) return 0;
  return 10 * math.log(numerator / denominator) / math.ln10;
}

/// The predicted curve over the audible band, log-spaced so the octave-wide
/// bands spread evenly across the graph's horizontal axis.
List<MusicEqResponsePoint> musicEqResponseCurve(MusicEqConfig config, {int points = 160}) {
  final curve = <MusicEqResponsePoint>[];
  for (var step = 0; step < points; step++) {
    final t = step / (points - 1);
    final frequency = 20 * math.pow(1000, t * (math.log(20000 / 20) / math.log(1000))).toDouble();
    var gain = config.preampDb;
    for (var band = 0; band < kMusicEqFrequencies.length; band++) {
      gain += musicEqBandGainAt(
        frequency: frequency,
        centre: kMusicEqFrequencies[band],
        gainDb: config.gains[band],
      );
    }
    for (final node in config.nodes) {
      if (!node.enabled) continue;
      gain += musicEqBandGainAt(frequency: frequency, centre: node.frequency, gainDb: node.gainDb, q: node.q);
    }
    // The tonal enhancement shapes are part of what the listener hears, so
    // the prediction includes them; the stereo-field and dynamics effects
    // have no magnitude curve and stay out.
    if (config.effectOn('bass')) {
      gain += musicEqLowShelfGainAt(
        frequency: frequency,
        gainDb: config.effectOf('bass').amount * 8,
      );
    }
    if (config.effectOn('vocal')) {
      final amount = config.effectOf('vocal').amount;
      gain += musicEqBandGainAt(frequency: frequency, centre: 300, gainDb: -amount * 2.5);
      gain += musicEqBandGainAt(frequency: frequency, centre: 3000, gainDb: amount * 4, q: 1.0 / 1.4);
    }
    curve.add(MusicEqResponsePoint(frequency: frequency, gainDb: gain));
  }
  return curve;
}

/// The mpv `af` entries for [config]: one `lavfi=[…]` graph when there is
/// work to do, nothing when the chain is off and no probe is wanted.
///
/// The graph speaks the spec's dialect — `equalizer=f=…:t=q:w=1:g=…` per
/// non-zero band, then `volume=…` for the preamp. Zero bands are left out
/// rather than sent as identity filters, keeping the chain short and the
/// processing cheap.
///
/// With [MusicEqConfig.analysis] on, the chain ends in an `ebur128`
/// metering branch: the audio is split, the probe reads it and is sunk,
/// and the untouched branch keeps playing. The probe measures the mix
/// after every effect above it, which is exactly what the meter shows.
List<String> musicEqAfEntries(MusicEqConfig config) {
  final probe = config.analysis;
  if (!config.enabled && !probe) return const <String>[];

  final filters = <String>[...musicFxAfFilters(config)];
  if (config.enabled) {
    // The parametric nodes come first: free-frequency corrections shape
    // the problem spots before the graphic bands lay down the character.
    for (final node in config.nodes) {
      if (!node.enabled || node.gainDb.abs() < 0.05) continue;
      filters.add(
        'equalizer=f=${node.frequency.toStringAsFixed(0)}'
        ':t=q:w=${node.q.toStringAsFixed(2)}:g=${node.gainDb.toStringAsFixed(1)}',
      );
    }
    for (var band = 0; band < kMusicEqFrequencies.length; band++) {
      final gain = config.gains[band];
      if (gain.abs() < 0.05) continue;
      filters.add(
        'equalizer=f=${kMusicEqFrequencies[band].toStringAsFixed(0)}'
        ':t=q:w=${kMusicEqBandQ.toStringAsFixed(1)}:g=${gain.toStringAsFixed(1)}',
      );
    }

    if (config.preampDb.abs() >= 0.05) {
      filters.add('volume=${config.preampDb >= 0 ? '+' : ''}${config.preampDb.toStringAsFixed(1)}dB');
    }
  }

  if (filters.isEmpty && !probe) return const <String>[];

  if (probe) {
    // Analysis, not processing: the split branch reads loudness and is
    // sunk; the listener's branch ends in a plain `anull` so the graph
    // still has one unlabeled output for the speakers.
    final prefix = filters.isEmpty ? '' : '${filters.join(',')},';
    final graph = '${prefix}asplit=2[ao][probe];'
        '[probe]ebur128=metadata=1[ebur128];anullsink[ebur128];[ao]anull';
    return <String>['lavfi=[$graph]'];
  }

  return <String>['lavfi=[${filters.join(',')}]'];
}

/// The enhancement effects' filters, ahead of the tonal bands.
///
/// Every entry is a real FFmpeg filter the strength feeds real parameters
/// into; nothing here fakes a switch. The order is the processing order:
/// loudness first so later filters work on a settled level, the tonal
/// shapes next, the stereo-field ones after (they must see the finished
/// mix), dynamics last as the safety stage. Known costs are declared in
/// [kMusicFxCosts] and shown in the UI rather than hidden.
List<String> musicFxAfFilters(MusicEqConfig config) {
  final filters = <String>[];

  if (config.effectOn('loudness')) {
    filters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
  }
  if (config.effectOn('bass')) {
    final amount = config.effectOf('bass').amount;
    filters.add('bass=g=${(amount * 8).toStringAsFixed(1)}:f=105:t=q:w=0.85');
  }
  if (config.effectOn('vocal')) {
    final amount = config.effectOf('vocal').amount;
    // The classic presence shape: lift the 3 kHz presence ridge, pull the
    // 300 Hz mud that buries speech under it.
    filters
      ..add('equalizer=f=300:t=q:w=1.0:g=-${(amount * 2.5).toStringAsFixed(1)}')
      ..add('equalizer=f=3000:t=q:w=1.4:g=${(amount * 4).toStringAsFixed(1)}');
  }
  if (config.effectOn('width')) {
    final amount = config.effectOf('width').amount;
    // Side level up: widening keeps the mono centre and pushes the
    // difference signal, the same lever a studio widener pulls.
    filters.add('stereotools=slev=${(1 + amount * 1.5).toStringAsFixed(2)}');
  }
  if (config.effectOn('surround')) {
    filters.add('haas');
  }
  if (config.effectOn('dynamics')) {
    final amount = config.effectOf('dynamics').amount;
    filters
      ..add('acompressor=threshold=-24dB:ratio=${(2 + amount * 2).toStringAsFixed(1)}:attack=25:release=250')
      ..add('alimiter=limit=${(0.75 + amount * 0.15).toStringAsFixed(2)}:level=false');
  }

  return filters;
}

/// The declared costs the UI owes the viewer, per the sound-effect spec: an
/// effect that adds latency or only suits stereo says so here.
const Map<String, String> kMusicFxCosts = <String, String>{
  'loudness': 'lookahead',
  'surround': 'stereoOnly, latency',
  'dynamics': 'lookahead',
};
