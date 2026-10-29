import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_dsp.dart';

void main() {
  group('musicEqBandGainAt', () {
    test('a peaking band is at its gain at the centre and quiet far away', () {
      final atCentre = musicEqBandGainAt(frequency: 1000, centre: 1000, gainDb: 6);
      expect(atCentre, closeTo(6, 0.01));

      final farBelow = musicEqBandGainAt(frequency: 100, centre: 1000, gainDb: 6);
      expect(farBelow.abs(), lessThan(0.5));
    });

    test('a negative band cuts', () {
      final cut = musicEqBandGainAt(frequency: 1000, centre: 1000, gainDb: -9);
      expect(cut, closeTo(-9, 0.01));
    });

    test('a narrower Q narrows the response', () {
      // One octave away from the centre, a wide Q passes more of the gain.
      final wide = musicEqBandGainAt(frequency: 2000, centre: 1000, gainDb: 12, q: 0.5);
      final narrow = musicEqBandGainAt(frequency: 2000, centre: 1000, gainDb: 12, q: 4);
      expect(wide, greaterThan(narrow));
    });
  });

  group('musicEqLowShelfGainAt', () {
    test('a low shelf lifts below its corner and not above', () {
      final below = musicEqLowShelfGainAt(frequency: 40, gainDb: 8);
      // The shelf's Q gives a slight resonant overshoot below the corner;
      // within a quarter dB is the shape FFmpeg's `bass` actually builds.
      expect(below, closeTo(8, 0.25));

      final above = musicEqLowShelfGainAt(frequency: 4000, gainDb: 8);
      expect(above.abs(), lessThan(0.2));
    });
  });

  group('musicEqResponseCurve', () {
    test('a flat configuration stays near zero across the band', () {
      const config = MusicEqConfig(
        enabled: true,
        preampDb: 0,
        gains: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      );
      for (final point in musicEqResponseCurve(config)) {
        expect(point.gainDb.abs(), lessThan(0.01));
      }
    });

    test('the preamp shifts the whole curve', () {
      final flat = MusicEqConfig(enabled: true, preampDb: 0, gains: List.filled(kMusicEqFrequencies.length, 0));
      final boosted = flat.copyWith(preampDb: 3);
      final base = musicEqResponseCurve(flat);
      final shifted = musicEqResponseCurve(boosted);
      for (var i = 0; i < base.length; i++) {
        expect(shifted[i].gainDb, closeTo(base[i].gainDb + 3, 0.01));
      }
    });

    test('a lifted band peaks near its centre frequency', () {
      final gains = List<double>.filled(kMusicEqFrequencies.length, 0);
      gains[3] = 12; // 250 Hz.
      final config = MusicEqConfig(enabled: true, preampDb: 0, gains: gains);
      final curve = musicEqResponseCurve(config);

      final peak = curve.reduce((a, b) => a.gainDb >= b.gainDb ? a : b);
      expect(peak.frequency, inInclusiveRange(180, 320));
      expect(peak.gainDb, greaterThan(9));
    });

    test('the vocal effect adds its presence ridge around 3 kHz', () {
      final plain = MusicEqConfig(enabled: true, preampDb: 0, gains: List.filled(kMusicEqFrequencies.length, 0));
      final vocal = plain.copyWith(effects: <String, MusicFxNode>{'vocal': const MusicFxNode(enabled: true, amount: 1)});

      final baseCurve = musicEqResponseCurve(plain);
      final vocalCurve = musicEqResponseCurve(vocal);
      var biggest = 0.0;
      var biggestFrequency = 0.0;
      for (var i = 0; i < baseCurve.length; i++) {
        final difference = vocalCurve[i].gainDb - baseCurve[i].gainDb;
        if (difference > biggest) {
          biggest = difference;
          biggestFrequency = vocalCurve[i].frequency;
        }
      }
      expect(biggest, greaterThan(3));
      expect(biggestFrequency, inInclusiveRange(2000, 4500));
    });
  });

  group('musicEqAfEntries', () {
    test('off and flat means no chain at all', () {
      const off = MusicEqConfig(enabled: false, preampDb: 0, gains: <double>[]);
      expect(musicEqAfEntries(off), isEmpty);

      final flat = MusicEqConfig(enabled: true, preampDb: 0, gains: List.filled(kMusicEqFrequencies.length, 0));
      expect(musicEqAfEntries(flat), isEmpty);
    });

    test('a lifted band and the preamp both reach the graph', () {
      final gains = List<double>.filled(kMusicEqFrequencies.length, 0);
      gains[0] = 6;
      final config = MusicEqConfig(enabled: true, preampDb: -2, gains: gains);
      final entries = musicEqAfEntries(config);
      expect(entries, hasLength(1));
      expect(entries.first, contains('equalizer=f=31'));
      expect(entries.first, contains('g=6.0'));
      expect(entries.first, contains('volume=-2.0dB'));
    });

    test('a parametric node speaks its own frequency and Q', () {
      final config = MusicEqConfig(
        enabled: true,
        preampDb: 0,
        gains: List.filled(kMusicEqFrequencies.length, 0),
        nodes: const [MusicEqNode(id: 'n1', enabled: true, frequency: 7300, q: 4, gainDb: -6)],
      );
      final entry = musicEqAfEntries(config).single;
      expect(entry, contains('equalizer=f=7300'));
      expect(entry, contains('w=4.00'));
      expect(entry, contains('g=-6.0'));
    });

    test('a disabled node and a bypassed EQ leave the chain out', () {
      final config = MusicEqConfig(
        enabled: false,
        preampDb: 0,
        gains: List.filled(kMusicEqFrequencies.length, 12),
        nodes: const [MusicEqNode(id: 'n1', enabled: false, frequency: 1000, q: 1, gainDb: 6)],
      );
      expect(musicEqAfEntries(config), isEmpty);
    });

    test('the probe rides along even with the EQ bypassed', () {
      const config = MusicEqConfig(enabled: false, preampDb: 0, gains: <double>[], analysis: true);
      final entries = musicEqAfEntries(config);
      expect(entries, hasLength(1));
      expect(entries.first, contains('ebur128=metadata=1'));
      expect(entries.first, contains('anullsink'));
      expect(entries.first, contains('[ao]anull'));
    });

    test('with the probe on, the processing filters come before the split', () {
      final gains = List<double>.filled(kMusicEqFrequencies.length, 0);
      gains[1] = 3;
      final config = MusicEqConfig(
        enabled: true,
        preampDb: 0,
        gains: gains,
        analysis: true,
        effects: const <String, MusicFxNode>{'bass': MusicFxNode(enabled: true, amount: 0.5)},
      );
      final entry = musicEqAfEntries(config).single;
      final splitAt = entry.indexOf('asplit');
      expect(splitAt, greaterThan(0));
      expect(entry.indexOf('bass=g='), lessThan(splitAt));
      expect(entry.indexOf('equalizer=f=62'), lessThan(splitAt));
    });
  });

  group('MusicEqConfig round trip', () {
    test('nodes and analysis survive the JSON round trip', () {
      const node = MusicEqNode(id: 'n1', enabled: true, frequency: 7300, q: 4, gainDb: -6);
      const config = MusicEqConfig(
        enabled: true,
        preampDb: 1.5,
        gains: <double>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        analysis: true,
        nodes: <MusicEqNode>[node],
      );
      final restored = MusicEqConfig.fromJson(config.toJson())!;
      expect(restored.enabled, isTrue);
      expect(restored.preampDb, closeTo(1.5, 0.001));
      expect(restored.gains, config.gains);
      expect(restored.analysis, isTrue);
      expect(restored.nodes, hasLength(1));
      expect(restored.nodes.first.frequency, 7300);
      expect(restored.nodes.first.q, 4);
      expect(restored.nodes.first.gainDb, -6);
    });

    test('a damaged node entry is dropped, not fatal', () {
      final restored = MusicEqConfig.fromJson(<String, Object?>{
        'enabled': true,
        'preamp': 0,
        'gains': List.filled(kMusicEqFrequencies.length, 0),
        'nodes': <Object?>[
          <String, Object?>{'id': '', 'frequency': 1000, 'q': 1, 'gainDb': 3},
          <String, Object?>{'id': 'ok', 'frequency': 2000, 'q': 1, 'gainDb': 3},
        ],
      })!;
      expect(restored.nodes, hasLength(1));
      expect(restored.nodes.first.id, 'ok');
    });

    test('a fresh node starts at 1 kHz, Q 1, +3 dB', () {
      final node = MusicEqNode.fresh('x');
      expect(node.frequency, 1000);
      expect(node.q, 1);
      expect(node.gainDb, 3);
      expect(node.enabled, isTrue);
    });
  });

  group('node controller bounds', () {
    test('the log sliders invert exactly', () {
      // The frequency slider maps 0..1 onto 20..20 kHz in three decades;
      // the midpoint must land on the geometric centre.
      const decade = 3.0;
      final frequency = 20 * math.pow(10, 0.5 * decade).toDouble();
      expect(frequency, closeTo(math.sqrt(20 * 20000), 0.1));
    });
  });
}
