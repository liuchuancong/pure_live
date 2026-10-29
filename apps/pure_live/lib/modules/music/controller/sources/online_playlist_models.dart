import 'package:media_core_audio/media_core_audio.dart' as audio;

/// One online playlist as the viewer sees it in the 在线歌单 lists.
final class MusicPlaylistInfo {
  /// A playlist summary.
  const MusicPlaylistInfo({
    required this.id,
    required this.name,
    required this.cover,
    required this.author,
    required this.trackCount,
  });

  /// The playlist id the detail call takes.
  final String id;

  /// Display name.
  final String name;

  /// Cover image url.
  final String cover;

  /// Creator nickname.
  final String author;

  /// How many tracks it holds.
  final int trackCount;
}

/// One page of the online playlist lists.
final class MusicPlaylistPage {
  /// A page.
  const MusicPlaylistPage({required this.items, required this.total});

  /// The playlists on this page.
  final List<MusicPlaylistInfo> items;

  /// The total across pages.
  final int total;
}

/// The online-playlist capability (在线歌单) a platform source can carry:
/// the hot tags, the pages under one tag, and a playlist's tracks.
abstract mixin class OnlinePlaylists {
  /// The hot tags; the tag set the browser starts from.
  Future<List<String>> hotTags();

  /// One page of playlists under [tag].
  Future<MusicPlaylistPage> playlists({String tag, String order, int page, int pageSize});

  /// The playlist's summary and tracks.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String id);
}

/// The songlist-search capability (搜索类型=歌单) a platform source can
/// carry: keyword search over its own online playlists.
mixin SonglistSearch {
  /// One page of playlists matching [keyword].
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20});
}

/// One tag of a plaza's category tree.
final class MusicPlaylistTag {
  /// Creates a tag.
  const MusicPlaylistTag({required this.id, required this.name});

  /// The id the plaza's listing endpoint asks under.
  final String id;

  /// The words the tag is shown under.
  final String name;
}

/// One category of the plaza's tag tree — the reference's `getTags` groups.
final class MusicPlaylistTagGroup {
  /// Creates a group.
  const MusicPlaylistTagGroup({required this.name, required this.tags});

  /// The category's words.
  final String name;

  /// The tags filed under it.
  final List<MusicPlaylistTag> tags;
}

/// The plaza's category-tree capability (歌单分类) a platform source can
/// carry: the groups of tags beside the hot ones [OnlinePlaylists] shows.
mixin PlaylistTagTree {
  /// The plaza's categories, each with its tags.
  Future<List<MusicPlaylistTagGroup>> tagGroups();
}
