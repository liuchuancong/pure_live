import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/l10n/translations.dart';

import 'package:pure_live/modules/music/controller/music_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicCapabilityOf;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show
        MusicPlaylistInfo,
        MusicPlaylistPage,
        MusicPlaylistTagGroup,
        MusicPlazaSort,
        OnlinePlaylists,
        PlaylistTagTree,
        SonglistSearch;

/// One online playlist opened to its tracks.
typedef MusicOnlinePlaylistDetail = (MusicPlaylistInfo, List<audio.MusicTrack>);

/// The online-playlist browsers' data (在线歌单): tag listings, the pages
/// under a tag and one playlist's tracks. Platforms carry the capability as
/// an [OnlinePlaylists] mixin; the Netease and QQ channels implement it.
///
/// Every one of these asks [musicCapabilityOf] rather than testing the active
/// source directly: `musicSourceProvider` hands out the platform under its
/// lyric wrappers, which carry the [audio.MusicSource] contract and nothing
/// beside it — read directly, a full plaza would look like a source with none.
final musicOnlineHotTagsProvider = FutureProvider<List<String>>((ref) async {
  final plaza = musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider));
  if (plaza == null) return const <String>[];
  return await plaza.hotTags();
});

/// The plaza's sort tabs; a source without them shows none.
final musicPlaylistSortsProvider = Provider<List<MusicPlazaSort>>((ref) {
  return musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider))?.sorts ?? const <MusicPlazaSort>[];
});

/// The words a plaza's sort tab is shown under — the reference's `sortList`
/// names; an unknown id falls back to its own words.
String musicPlaylistSortLabel(Translations t, MusicPlazaSort sort) => switch (sort.id) {
  'recommend' => t.music.sortRecommend,
  'hot' => t.music.sortHot,
  'new' => t.music.sortNew,
  'hot_collect' => t.music.sortHotCollect,
  'rise' => t.music.sortRise,
  _ => sort.name,
};

typedef MusicOnlinePlaylistKey = ({String tag, String order, int page});

/// The plaza's category tree (歌单分类): one group per category, its tags
/// inside. A source without the tree has none and the browser keeps to the
/// hot tags.
final musicPlaylistTagGroupsProvider = FutureProvider<List<MusicPlaylistTagGroup>>((ref) async {
  final tree = musicCapabilityOf<PlaylistTagTree>(ref.watch(musicSourceProvider));
  if (tree == null) return const <MusicPlaylistTagGroup>[];
  return await tree.tagGroups();
});

final FutureProviderFamily<MusicPlaylistPage, MusicOnlinePlaylistKey> musicOnlinePlaylistsProvider =
    FutureProvider.family<MusicPlaylistPage, MusicOnlinePlaylistKey>((ref, key) async {
      final plaza = musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider));
      if (plaza == null) return const MusicPlaylistPage(items: [], total: 0);
      return await plaza.playlists(tag: key.tag, order: key.order, page: key.page);
    });

final FutureProviderFamily<MusicOnlinePlaylistDetail, String> musicOnlinePlaylistDetailProvider =
    FutureProvider.family<MusicOnlinePlaylistDetail, String>((ref, id) {
      final plaza = musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider));
      if (plaza == null) return Future.error(StateError('online playlists are not served by $id'));
      return plaza.playlistDetail(id);
    });

/// The 歌单 search type's answers: the keyword's playlists on the active
/// source, page by page. A source without the capability refuses honestly.
typedef MusicSonglistSearchKey = ({String keyword, int page});

final FutureProviderFamily<MusicPlaylistPage, MusicSonglistSearchKey> musicSonglistSearchProvider =
    FutureProvider.family<MusicPlaylistPage, MusicSonglistSearchKey>((ref, key) {
      final source = ref.watch(musicSourceProvider);
      final songlist = musicCapabilityOf<SonglistSearch>(source);
      if (songlist == null) return Future.error(StateError('songlist search is not served by ${source.id}'));
      return songlist.searchPlaylists(key.keyword, page: key.page);
    });
