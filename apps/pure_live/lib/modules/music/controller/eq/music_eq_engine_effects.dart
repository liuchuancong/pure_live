import 'package:media_core_mpv_audio/media_core_mpv_audio.dart'
    show
        AcompressorEffect,
        AechoEffect,
        AlimiterEffect,
        ApulsatorEffect,
        ApulsatorMode,
        AudioEffect,
        BassEffect,
        BassWidthType,
        EqualizerEffect,
        EqualizerWidthType,
        HaasEffect,
        LoudnormEffect,
        StereotoolsEffect;

// The parameter values below restate FFmpeg defaults on purpose: the DSP
// layer's shape is written out in full so a reader compares it against the
// lavfi dialect it replaced, argument by argument.
// ignore_for_file: avoid_redundant_argument_values
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';

/// The typed-effects view of a sound-effect configuration, for the
/// mpv_audio engine.
///
/// The DSP layer still owns the shape — the same amounts, the same filter
/// parameters — but the dialect changes: instead of one `lavfi=[…]` string
/// sent through engine options (the route the old mpv build never had the
/// filters for), each band and effect becomes one typed [AudioEffect] the
/// engine applies as its own managed chain. What the filters do is
/// unchanged; only who writes the chain differs.
///
/// Two shapes stay out of this list on purpose:
///
/// - preamp: the engine has a native volume-gain property, which is the
///   honest pre-amplifier — `setVolumeGain` carries it.
/// - pitch: the engine's own `setPitch` is the first-class control; the
///   asetrate/atempo graph is what it does internally, better.
List<AudioEffect> musicEqAudioEffects(MusicEqConfig config) {
  if (!config.enabled) return const <AudioEffect>[];

  final effects = <AudioEffect>[];

  // The enhancement effects, in the chain order the DSP layer documents:
  // loudness settles the level first, tonal shapes next, the stereo-field
  // ones after the finished mix, dynamics last as the safety stage.
  if (config.effectOn('loudness')) {
    effects.add(const LoudnormEffect(i: -16, tp: -1.5, lra: 11));
  }
  if (config.effectOn('bass')) {
    final amount = config.effectOf('bass').amount;
    effects.add(BassEffect(gain: amount * 8, frequency: 105, width: 0.85, widthType: BassWidthType.q));
  }
  if (config.effectOn('vocal')) {
    final amount = config.effectOf('vocal').amount;
    // The classic presence shape: lift the 3 kHz ridge, pull the 300 Hz mud.
    effects
      ..add(const EqualizerEffect(frequency: 300, gain: -2.5, width: 1, widthType: EqualizerWidthType.q))
      ..add(EqualizerEffect(frequency: 3000, gain: amount * 4, width: 1.4, widthType: EqualizerWidthType.q));
  }
  if (config.effectOn('width')) {
    final amount = config.effectOf('width').amount;
    effects.add(StereotoolsEffect(slev: 1 + amount * 1.5));
  }
  if (config.effectOn('surround')) {
    effects.add(const HaasEffect());
  }
  if (config.effectOn('dynamics')) {
    final amount = config.effectOf('dynamics').amount;
    effects
      ..add(AcompressorEffect(threshold: -24, ratio: 2 + amount * 2, attack: 25, release: 250))
      ..add(AlimiterEffect(limit: 0.75 + amount * 0.15, level: false));
  }

  // The parametric nodes first, the graphic bands after — the same order
  // the lavfi chain built, so a correction shapes the problem spot before
  // the character goes down.
  for (final node in config.nodes) {
    if (!node.enabled || node.gainDb.abs() < 0.05) continue;
    effects.add(EqualizerEffect(frequency: node.frequency, gain: node.gainDb, width: node.q, widthType: EqualizerWidthType.q));
  }
  for (var band = 0; band < kMusicEqFrequencies.length; band++) {
    final gain = config.gains[band];
    if (gain.abs() < 0.05) continue;
    effects.add(
      EqualizerEffect(frequency: kMusicEqFrequencies[band], gain: gain, width: kMusicEqBandQ, widthType: EqualizerWidthType.q),
    );
  }

  // The spatial tail, after the finished tonal mix.
  if (config.effectOn('reverb')) {
    final amount = config.effectOf('reverb').amount;
    effects.add(
      AechoEffect(inGain: 0.8, outGain: 0.9, delays: '60|121', decays: '${(amount * 0.6).toStringAsFixed(2)}|${(amount * 0.35).toStringAsFixed(2)}'),
    );
  }
  if (config.effectOn('panner')) {
    final node = config.effectOf('panner');
    final speed = (1 + node.detail * 49).clamp(1, 50);
    final depth = (node.amount * 3).clamp(0.1, 2);
    effects.add(ApulsatorEffect(mode: ApulsatorMode.sine, hz: 1.389 / speed, amount: depth.toDouble()));
  }

  return effects;
}

/// The pitch the engine should run at for the configuration: the pitch
/// node's slider is 0–1 around the 0.5 centre, which the engine spells as
/// the 0.5–1.5 rate. 1.0 (no shift) when the node is off.
double musicEqPitchRate(MusicEqConfig config) {
  // The A/B bypass rides `enabled: false` through here too: a held bypass
  // must lift the pitch shift along with the chain, or the comparison
  // listens to a shifted original.
  if (!config.enabled || !config.effectOn('pitch')) return 1;
  return 0.5 + config.effectOf('pitch').amount;
}
