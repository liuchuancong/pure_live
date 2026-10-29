import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart' show musicEqProvider;
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_downloads.dart' show musicDownloadsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_local.dart' show musicLocalProvider;
import 'package:pure_live/modules/music/controller/music_online_playlists.dart' show musicOnlineHotTagsProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_search.dart'
    show musicCatalogsProvider, musicHotSearchesProvider, musicSearchHistoryProvider, musicSearchProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/music_sources.dart' show musicSourcesProvider;
import 'package:pure_live/modules/music/controller/music_sync.dart' show musicSyncProvider;


void main() {
  setUpAll(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  test('the providers the music pages watch all build', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The settings and lists every view and pane watches.
    container
      ..read(musicSettingsProvider)
      ..read(musicSourcesProvider)
      ..read(musicPlaylistsProvider)
      ..read(musicDownloadsProvider)
      ..read(musicFavouritesProvider)
      ..read(musicRecentProvider)
      ..read(musicDislikesProvider)
      ..read(musicSearchProvider)
      ..read(musicSearchHistoryProvider)
      ..read(musicLocalProvider)
      ..read(musicSyncProvider)
      ..read(musicEqProvider);

    // The default source answers without an imported script: the pages'
    // capability providers start against it and may only fail honestly.
    final source = container.read(musicSourceProvider);
    expect(source.id, isNotEmpty);
    container
      ..read(musicOnlineHotTagsProvider)
      ..read(musicCatalogsProvider)
      ..read(musicHotSearchesProvider);
  });
}
