// What "defaults" means for the recorder: every tunable goes back, and the one
// choice that is not a tunable stays. A reset that cleared the CA path in memory
// while the preference kept it would show "bundled store" now and the viewer's
// own bundle after the next launch — the kind of split state this test exists to
// catch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/modules/live/recorder/data/recording_settings.dart';

void main() {
  test('a reset returns every tunable and keeps the chosen CA bundle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recordingSettingsProvider.notifier)
      ..customCaPath = r'D:\certs\corp.pem'
      ..segmentSeconds = 900
      ..combineAfterStop = false
      ..transcodeAfterCombine = true
      ..recordDanmakuGifts = true;

    await notifier.reset();

    final settings = container.read(recordingSettingsProvider);
    expect(settings.network.customCaPath, r'D:\certs\corp.pem', reason: 'a picked file is not a tunable');
    expect(settings.segmentSeconds, RecordingSettings.defaults.segmentSeconds);
    expect(settings.combineAfterStop, RecordingSettings.defaults.combineAfterStop);
    expect(settings.transcodeAfterCombine, RecordingSettings.defaults.transcodeAfterCombine);
    expect(settings.recordDanmakuGifts, RecordingSettings.defaults.recordDanmakuGifts);
  });
}
