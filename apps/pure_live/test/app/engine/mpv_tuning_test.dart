import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/playback/mpv_tuning.dart';

void main() {
  group('MpvTuning.nativeOptions — 播放器代理', () {
    test('off writes no proxy keys', () {
      final options = MpvTuning.nativeOptions(
        const AppPreferences(),
        platform: TargetPlatform.windows,
        isDesktop: true,
      );
      expect(options.containsKey('proxy'), isFalse);
      expect(options.containsKey('https-proxy'), isFalse);
    });

    test('on writes both spellings with the stored endpoint', () {
      final options = MpvTuning.nativeOptions(
        const AppPreferences(playerProxyEnabled: true, playerProxyHost: '10.0.0.2', playerProxyPort: 10809),
        platform: TargetPlatform.windows,
        isDesktop: true,
      );
      expect(options['proxy'], 'http://10.0.0.2:10809');
      expect(options['https-proxy'], 'http://10.0.0.2:10809');
    });

    test('the proxy is a next-open change, not a live one', () {
      const before = AppPreferences();
      const after = AppPreferences(playerProxyEnabled: true);
      expect(MpvTuning.nextOpenOnlyChanged(before, after), isTrue);
    });
  });
}
