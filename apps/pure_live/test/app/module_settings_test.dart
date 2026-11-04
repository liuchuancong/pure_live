// The sandbox's storage rule: a player setting written in one module is that
// module's, and a module that never wrote one still answers the shared value
// the app stored before the split.
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/app/providers/settings/module_settings.dart' show ModuleSettings;
import 'package:pure_live/shared/shared.dart' show AppModule;

void main() {
  setUp(() async {
    await StoragePrefs.initSeeded(const <String, Object?>{});
  });

  test('a write lands in the module that made it, not the other one', () async {
    const live = ModuleSettings(AppModule.live);
    const music = ModuleSettings(AppModule.music);

    await live.setBool('playback.muted', true);

    expect(live.getBool('playback.muted'), isTrue);
    expect(music.getBool('playback.muted'), isNull);
  });

  test('a module without its own copy answers the shared legacy value', () async {
    await StoragePrefs.initSeeded(const <String, Object?>{'player.backend': 'ijk'});
    const live = ModuleSettings(AppModule.live);
    const vod = ModuleSettings(AppModule.vod);

    expect(live.getString('player.backend'), 'ijk');
    expect(vod.getString('player.backend'), 'ijk');

    // Live moves its own engine; VOD keeps the shared answer until it writes.
    await live.setString('player.backend', 'mpv');
    expect(live.getString('player.backend'), 'mpv');
    expect(vod.getString('player.backend'), 'ijk');
  });

  test('numbers and doubles keep their own namespaces too', () async {
    const live = ModuleSettings(AppModule.live);
    const hongguo = ModuleSettings(AppModule.hongguo);

    await live.setDouble('playback.mobileVolume', 0.25);
    await hongguo.setDouble('playback.mobileVolume', 0.8);

    expect(live.getDouble('playback.mobileVolume'), 0.25);
    expect(hongguo.getDouble('playback.mobileVolume'), 0.8);
  });

  test('removing a module copy uncovers the shared value again', () async {
    await StoragePrefs.initSeeded(const <String, Object?>{'playback.fit': 'contain'});
    const live = ModuleSettings(AppModule.live);

    await live.setString('playback.fit', 'cover');
    expect(live.getString('playback.fit'), 'cover');

    await live.remove('playback.fit');
    expect(live.getString('playback.fit'), 'contain');
  });
}
