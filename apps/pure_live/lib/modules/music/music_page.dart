import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart'
    show musicDownloadsActive, musicDownloadsProvider;
import 'package:pure_live/modules/music/controller/music_hotkeys.dart' show musicHotkeyBindings;
import 'package:pure_live/modules/music/controller/music_open_api.dart' show musicOpenApiProvider;
import 'package:pure_live/modules/music/controller/music_sources.dart' show musicSourcesProvider;
import 'package:pure_live/modules/music/controller/music_sync_server.dart' show musicSyncServerProvider;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart' show MusicPlaylistInfo;
import 'package:pure_live/modules/music/pages/music_charts_view.dart';
import 'package:pure_live/modules/music/pages/music_downloads_view.dart';
import 'package:pure_live/modules/music/pages/music_featured_view.dart';
import 'package:pure_live/modules/music/pages/music_library_view.dart';
import 'package:pure_live/modules/music/pages/music_local_view.dart';
import 'package:pure_live/modules/music/pages/music_mine_view.dart';
import 'package:pure_live/modules/music/pages/music_recommend_view.dart';
import 'package:pure_live/modules/music/pages/music_songlists_view.dart';

/// The music module's views. The reference's rail — 推荐 / 精选 / 搜索 / 歌单 /
/// 排行榜 / 我的列表 — is what the module's menu lists, and the app's own
/// surfaces sit beside them: the device's files and the download centre.
enum MusicView {
  /// The module's picks, the reference's 推荐: the source's playlists and
  /// boards beside the songs this app already knows the viewer likes.
  recommend,

  /// The source's curated playlists, the reference's 精选.
  featured,

  /// The library: a search, its history, its songs, and the player that
  /// answers them.
  library,

  /// The viewer's playlists, the reference's 歌单.
  songlists,

  /// Charts: the source's own leaderboards, the reference's 排行榜.
  toplists,

  /// The viewer's own lists — collected and recently played songs.
  mine,

  /// The device's own music files, the reference's 本地音乐.
  local,

  /// The download queue and its tasks, the reference's 下载管理.
  downloads;

  /// The view's icon, on its empty state.
  DsIconData get icon => switch (this) {
    MusicView.recommend => DsIcons.sparkles,
    MusicView.featured => DsIcons.compass,
    MusicView.library => DsIcons.discAlbum,
    MusicView.songlists => DsIcons.listMusic,
    MusicView.toplists => DsIcons.chartColumn,
    MusicView.mine => DsIcons.library,
    MusicView.local => DsIcons.folderOpen,
    MusicView.downloads => DsIcons.download,
  };
}

/// The music module's entry: a real player over the module's source.
///
/// 推荐 gathers what the source suggests and what this app already knows the
/// viewer likes, 精选 browses the plaza's own playlists, the library searches
/// and plays, the charts are the source's own boards, 歌单 keeps the viewer's
/// own lists, 我的列表 keeps the songs this module collected and played,
/// 本地音乐 plays the device's files, and 下载 keeps the queue.
final class MusicPage extends ConsumerStatefulWidget {
  /// The music module's entry page, opening on [view].
  const MusicPage({this.view = MusicView.library, super.key});

  /// The view the page opens on; the module's menu names it.
  final MusicView view;

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

final class _MusicPageState extends ConsumerState<MusicPage> {
  /// The view the page is showing.
  late MusicView _view = widget.view;

  /// The online playlist the library's 歌单 search asked to open, handed to
  /// the songlists view when it next mounts.
  MusicPlaylistInfo? _openSonglist;

  /// The library's search field, kept across view switches so a query is not
  /// lost by looking at the charts.
  final TextEditingController _search = TextEditingController();

  /// The word the 推荐 page's hot chip asked for, handed to the library when
  /// it next mounts; the library clears it as it takes it.
  String? _pendingSearch;

  /// The playlist the 推荐 page asked to open, handed to 精选 when it next
  /// mounts; the featured view clears it as it takes it.
  MusicPlaylistInfo? _openFeatured;

  /// The board the charts view has open; null takes the first one.
  String? _catalogId;

  @override
  void didUpdateWidget(MusicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the module's
    // entries, so a new entry has to move the page to its view.
    if (widget.view != _view) setState(() => _view = widget.view);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The open API and the sync server boot with the module: the keepAlive
    // providers start their endpoints when the gates are on and keep them
    // answering for the session.
    ref
      ..watch(musicOpenApiProvider)
      ..watch(musicSyncServerProvider);
    return CallbackShortcuts(
      bindings: musicHotkeyBindings(ref),
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
              child: _ModuleHeader(),
            ),
            Expanded(
              child: switch (_view) {
                MusicView.recommend => MusicRecommendView(
                  onSearch: (word) => setState(() {
                    _pendingSearch = word;
                    _view = MusicView.library;
                  }),
                  onOpenPlaylist: (info) => setState(() {
                    _openFeatured = info;
                    _view = MusicView.featured;
                  }),
                  onOpenFeatured: () => setState(() => _view = MusicView.featured),
                  onOpenBoard: (id) => setState(() {
                    _catalogId = id;
                    _view = MusicView.toplists;
                  }),
                ),
                MusicView.featured => MusicFeaturedView(
                  initialOnlineOpen: _openFeatured,
                  onOpened: () => _openFeatured = null,
                ),
                MusicView.library => MusicLibraryView(
                  search: _search,
                  initialQuery: _pendingSearch,
                  onQueryUsed: () => _pendingSearch = null,
                  onOpenSonglist: (info) => setState(() {
                    _view = MusicView.songlists;
                    _openSonglist = info;
                  }),
                ),
                MusicView.songlists => MusicPlaylistsView(initialOnlineOpen: _openSonglist),
                MusicView.toplists => MusicChartsView(
                  catalogId: _catalogId,
                  onCatalog: (id) => setState(() => _catalogId = id),
                ),
                MusicView.mine => const MusicMineView(),
                MusicView.local => const MusicLocalView(),
                MusicView.downloads => const MusicDownloadsView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The module's mark: the music note in a tinted tile, the module's name,
/// and one line on what feeds it — the imported lx sources, or the built-in
/// lx-music channel when none are imported.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final sources = ref.watch(musicSourcesProvider).where((source) => source.enabled).length;
    final active = musicDownloadsActive(ref.watch(musicDownloadsProvider));
    return Row(
      spacing: DsSpace.s12,
      children: [
        Container(
          width: theme.sizes.md,
          height: theme.sizes.md,
          decoration: DsBoxDecoration(
            color: colors.accentTint,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Center(
            child: DsIcon(DsIcons.music, size: theme.sizes.iconMd, color: colors.accentText),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                t.music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Text(
                active > 0
                    ? t.music.downloadsActive(count: active)
                    : sources == 0
                    ? t.music.tagline
                    : t.music.sourcesReady(count: sources),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
