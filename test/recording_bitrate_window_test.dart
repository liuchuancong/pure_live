import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/recording_bitrate_window.dart';

void main() {
  final start = DateTime(2026, 9, 26, 21, 35);
  DateTime at(int ms) => start.add(Duration(milliseconds: ms));

  test('reports kbit/s from file growth and smooths bursty writes', () {
    final window = RecordingBitrateWindow();
    expect(window.add(0, at(0)), isNull);
    // 8 Mbps = 1,000,000 bytes/s, written in alternating bursts.
    final rates = <double>[];
    var bytes = 0;
    for (var second = 1; second <= 10; second++) {
      bytes += second.isOdd ? 1600000 : 400000;
      rates.add(window.add(bytes, at(second * 1000))!);
    }
    expect(rates.last, closeTo(8000, 1200));
    expect(rates.skip(5).every((rate) => rate > 6000 && rate < 10000), isTrue);
  });

  test('keeps only the configured span and restarts after the byte count drops', () {
    final window = RecordingBitrateWindow(span: const Duration(seconds: 2));
    window.add(0, at(0));
    window.add(10000000, at(1000)); // an early burst
    window.add(10125000, at(2000));
    expect(window.add(10250000, at(3000)), closeTo(1000, 1), reason: 'the burst left the 2 s window');

    expect(window.add(1000, at(4000)), isNull, reason: 'a new attempt restarts the window');
    expect(window.add(126000, at(5000)), closeTo(1000, 1));
  });
}
