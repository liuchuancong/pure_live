import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

void main() {
  test('keeps plausible live FFmpeg progress', () {
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: 12000, wallSeconds: 13), 12);
  });

  test('uses wall time for source PTS or INT32 sentinel', () {
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: 2147483648000, wallSeconds: 9), 9);
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: 180000, wallSeconds: 4), 4);
  });

  test('does not expose negative progress', () {
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: -1, wallSeconds: 5), 0);
  });
}
