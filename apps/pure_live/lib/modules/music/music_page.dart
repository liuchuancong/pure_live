import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/music_sources.dart' show musicSourcesProvider;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

/// The music module's views. The reference's rail — 搜索 / 歌单 / 排行榜 /
/// 我的列表 — is what the module's menu lists, so each view is one entry and
/// the page opens on the one the entry names.
enum MusicView {
  /// The library: a search, its songs, and the player that answers them.
  library,

  /// Songlists: lx-music's lists, which need a script runtime.
  songlists,

  /// Charts: the source's own leaderboards, the reference's 排行榜.
  toplists,

  /// The viewer's own lists — collected and recently played songs.
  mine;

  /// The view's icon, on its empty state.
  DsIconData get icon => switch (this) {
    MusicView.library => DsIcons.discAlbum,
    MusicView.songlists => DsIcons.listMusic,
    MusicView.toplists => DsIcons.chartColumn,
    MusicView.mine => DsIcons.library,
  };
}

/// The music module's entry: a real player over the module's source.
///
/// The library searches and plays, the charts are the source's own boards,
/// and 我的列表 keeps the songs this module collected and played. Playlists
/// stay an honest empty state: lx-music's lists come from its JavaScript
/// sources, and this build does not execute scripts.
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

  /// The library's search field, kept across view switches so a query is not
  /// lost by looking at the charts.
  final TextEditingController _search = TextEditingController();

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Expanded(
          child: switch (_view) {
            MusicView.library => _LibraryView(search: _search),
            MusicView.songlists => const _SonglistsView(),
            MusicView.toplists => _ChartsView(
              catalogId: _catalogId,
              onCatalog: (id) => setState(() => _catalogId = id),
            ),
            MusicView.mine => const _MineView(),
          },
        ),
        const _MiniPlayer(),
      ],
    );
  }
}

/// The module's mark: the music note in a tinted tile, the module's name,
/// and one line on what feeds it — the imported lx sources, or the built-in
/// Bilibili audio source when none are imported.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final sources = ref.watch(musicSourcesProvider).length;
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
                sources == 0 ? t.music.tagline : t.music.sourcesReady(count: sources),
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

/// The library: a search and the songs it answers, each row playing the
/// answer from that song on.
final class _LibraryView extends ConsumerWidget {
  const _LibraryView({required this.search});

  final TextEditingController search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicSearchProvider);
    final controller = ref.read(musicSearchProvider.notifier);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final showSource = ref.watch(musicSettingsProvider).showSource;
    final sourceName = ref.watch(musicSourceProvider).name;
    void play(int index) => unawaited(playerController.playAll(state.songs, index: index));
    Widget songAt(int index) {
      final song = state.songs[index];
      final subtitle = [song.artist, if (showSource) sourceName].where((part) => part.isNotEmpty).join(' · ');
      return MusicSongRow(
        track: song,
        playing: playingId == song.id,
        favourite: favourites.contains(song),
        subtitle: subtitle.isEmpty ? null : subtitle,
        onPlay: () => play(index),
        onFavourite: () => unawaited(favouriteController.toggle(song)),
      );
    }

    final Widget body;
    if (state.query.isEmpty) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.music),
          title: Text(t.music.searchIdleTitle),
          description: Text(t.music.searchIdleDescription),
        ),
      );
    } else if (state.songs.isEmpty && state.loading) {
      body = const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    } else if (state.songs.isEmpty && state.error != null) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.searchFailed),
          description: Text(state.error!),
          actions: [DsButton(onPressed: () => unawaited(controller.retry()), child: Text(t.common.retry))],
        ),
      );
    } else if (state.songs.isEmpty) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.music.noResultsTitle),
          description: Text(t.music.noResultsDescription),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
            child: Text(
              t.music.songsCount(count: state.songs.length),
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
          ),
          Expanded(
            child: ListView.builder(itemCount: state.songs.length, itemBuilder: (context, index) => songAt(index)),
          ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(DsSpace.s12),
              child: Center(
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: state.loading ? null : () => unawaited(controller.loadMore()),
                  child: Text(t.music.loadMore),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSearchField(
            controller: search,
            autofocus: true,
            placeholder: t.music.searchHint,
            onSubmitted: (value) => unawaited(controller.search(value)),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Playlists: lx-music's lists need its script runtime, so this view says so
/// rather than drawing lists nobody can open.
final class _SonglistsView extends StatelessWidget {
  const _SonglistsView();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.listMusic),
        title: Text(t.music.playlistsEmptyTitle),
        description: Text(t.music.playlistsEmptyDescription),
      ),
    );
  }
}

/// The charts: the source's own boards, each one answer rather than a feed.
final class _ChartsView extends ConsumerWidget {
  const _ChartsView({required this.catalogId, required this.onCatalog});

  final String? catalogId;
  final ValueChanged<String> onCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final catalogs = ref.watch(musicCatalogsProvider);
    return catalogs.when(
      loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.chartsFailed),
          description: Text('$error'),
          actions: [DsButton(onPressed: () => ref.invalidate(musicCatalogsProvider), child: Text(t.common.retry))],
        ),
      ),
      data: (boards) {
        if (boards.isEmpty) {
          return Center(
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.chartColumn),
              title: Text(t.music.chartsEmptyTitle),
              description: Text(t.music.chartsEmptyDescription),
            ),
          );
        }
        final selected = boards.firstWhere((board) => board.id == catalogId, orElse: () => boards.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: SizedBox(
                height: 40,
                child: DsTopNav<String>(
                  value: selected.id,
                  onChanged: onCatalog,
                  items: [for (final board in boards) DsTopNavItem(value: board.id, label: Text(board.name))],
                ),
              ),
            ),
            Expanded(child: _ChartItems(catalog: selected)),
          ],
        );
      },
    );
  }
}

/// One board's songs, playing the whole board from the chosen row.
final class _ChartItems extends ConsumerWidget {
  const _ChartItems({required this.catalog});

  final audio.MusicCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final items = ref.watch(musicCatalogItemsProvider(catalog));
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    return items.when(
      loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.chartsFailed),
          description: Text('$error'),
          actions: [
            DsButton(onPressed: () => ref.invalidate(musicCatalogItemsProvider(catalog)), child: Text(t.common.retry)),
          ],
        ),
      ),
      data: (songs) => songs.isEmpty
          ? Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.chartColumn),
                title: Text(t.music.chartsEmptyTitle),
                description: Text(t.music.chartsEmptyDescription),
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return MusicSongRow(
                  track: song,
                  playing: playingId == song.id,
                  favourite: favourites.contains(song),
                  onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                  onFavourite: () => unawaited(favouriteController.toggle(song)),
                );
              },
            ),
    );
  }
}

/// 我的列表: the songs this module collected and played, each section playing
/// its own list from the chosen row.
final class _MineView extends ConsumerWidget {
  const _MineView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final favourites = ref.watch(musicFavouritesProvider);
    final recent = ref.watch(musicRecentProvider);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final recentController = ref.read(musicRecentProvider.notifier);
    if (favourites.isEmpty && recent.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.library),
          title: Text(t.music.mineEmptyTitle),
          description: Text(t.music.mineEmptyDescription),
        ),
      );
    }
    Widget section(
      String title,
      List<audio.MusicTrack> songs, {
      required Future<void> Function(audio.MusicTrack track) remove,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Text(
            '$title · ${t.music.songsCount(count: songs.length)}',
            style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
          ),
        ),
        DsListSection(
          children: [
            for (final (index, song) in songs.indexed)
              MusicSongRow(
                track: song,
                playing: playingId == song.id,
                favourite: favourites.contains(song),
                onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                onFavourite: () => unawaited(favouriteController.toggle(song)),
                onRemove: () => unawaited(remove(song)),
              ),
          ],
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          if (favourites.isNotEmpty) section(t.music.mineFavourites, favourites, remove: favouriteController.remove),
          if (recent.isNotEmpty) ...[
            section(t.music.mineRecent, recent, remove: recentController.remove),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => unawaited(recentController.clear()),
                  child: Text(t.music.clearRecent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The strip over the module's views while something plays: the song, its
/// transport and the way into the player page.
final class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider.select((state) => (track: state.track, playing: state.playing)));
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
      child: DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: DsListRow(
          leading: MusicArtwork(track: track),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          description: Text(
            track.artist.isEmpty ? t.music.nowPlaying : track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: state.playing ? t.music.pause : t.music.play,
                onPressed: () => unawaited(controller.toggle()),
                icon: DsIcon(state.playing ? DsIcons.pause : DsIcons.play),
              ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.music.next,
                onPressed: () => unawaited(controller.next()),
                icon: const DsIcon(DsIcons.skipForward),
              ),
            ],
          ),
          onPressed: () => unawaited(context.push(RouteNames.musicPlayer)),
        ),
      ),
    );
  }
}
