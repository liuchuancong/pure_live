// 打开时继续播放 is the config that brings the last song back: it now restores
// the song, its saved position and keeps playing, and it starts on rather than
// off so a fresh install answers the way the label promises.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/music/controller/music_playback_settings.dart' show musicPlaybackSettingsProvider;

void main() {
  setUpAll(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  test('a store without the key resumes on open', () async {
    await StoragePrefs.remove('music.play.autoplay');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(musicPlaybackSettingsProvider).autoplay, isTrue);
  });

  test('a stored off is the viewer\u2019s own choice and stays off', () async {
    await StoragePrefs.setBool('music.play.autoplay', false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(musicPlaybackSettingsProvider).autoplay, isFalse);
  });
}
