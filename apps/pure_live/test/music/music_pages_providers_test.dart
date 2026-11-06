import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart' show musicEqProvider;
import 'package:pure_live/modules/music/controller/music_desktop_lyric_settings.dart'
    show musicDesktopLyricsSettingsProvider;
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_download_settings.dart' show musicDownloadSettingsProvider;
import 'package:pure_live/modules/music/controller/music_downloads.dart' show musicDownloadsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_lyric_settings.dart' show musicLyricsSettingsProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart' show musicPlaybackSettingsProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_search.dart'
    show musicSearchHistoryProvider, musicSearchProvider;
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
      ..read(musicPlaybackSettingsProvider)
      ..read(musicLyricsSettingsProvider)
      ..read(musicDesktopLyricsSettingsProvider)
      ..read(musicDownloadSettingsProvider)
      ..read(musicSourcesProvider)
      ..read(musicPlaylistsProvider)
      ..read(musicDownloadsProvider)
      ..read(musicFavouritesProvider)
      ..read(musicRecentProvider)
      ..read(musicDislikesProvider)
      ..read(musicSearchProvider)
      ..read(musicSearchHistoryProvider)
      ..read(musicSyncProvider)
      ..read(musicEqProvider);
    // `musicLocalProvider` is deliberately not in this list: the local library
    // takes the app's download folder as one of its roots, so it reads
    // `appPathsProvider`, which only exists once boot has resolved the storage
    // layout (`storagePathsProvider` throws until then by design). A bare
    // container cannot build it, and inventing a fake layout here would test
    // the fake rather than the page.

    // The default source answers without an imported script: the pages'
    // capability providers start against it and may only fail honestly.
    final source = container.read(musicSourceProvider);
    expect(source.id, isNotEmpty);
    // `musicOnlineHotTagsProvider`, `musicCatalogsProvider` and
    // `musicHotSearchesProvider` are not read here: each one asks a platform
    // over the shared transport the moment it is watched, and the transport
    // this container gets is the app's real one — `networkFactoryProvider` is
    // a concrete factory with no seam for a replay transport. A test that
    // reaches the live API on every run answers to the network, not to the
    // module, so the three are left to a round that first gives the container
    // a fake transport.
  });
}
