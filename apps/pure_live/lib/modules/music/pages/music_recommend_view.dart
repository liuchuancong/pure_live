import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/background/glass/live_glass.dart' show kLiveGlassCoverFrostSigma;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_browse.dart'
    show musicHistoryAlbumsProvider, musicHistoryArtistsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_online_playlists.dart'
    show
        musicOnlineHotTagsProvider,
        musicOnlinePlaylistDetailProvider,
        musicOnlinePlaylistsProvider,
        musicPlaylistSortsProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart' show musicPlaybackSettingsProvider;
import 'package:pure_live/modules/music/controller/music_search.dart'
    show musicCatalogsProvider, musicHotSearchesProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/music_ui_settings.dart' show MusicUiElement, musicUiSettingsProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicCapabilityOf;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistTag, OnlinePlaylists;
import 'package:pure_live/modules/music/pages/music_playlist_card.dart'
    show MusicPlaylistCard, kMusicPlaylistInfoHeight;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_browse_links.dart' show openMusicAlbum, openMusicArtist;
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart'
    show MusicAlbumCard, MusicArtistCard, musicBrowseSourceLabel;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, LiveWindow, buildDsRefreshIndicator, cachedImage;

/// 推荐: the module's own home. Nothing here is invented — the strip of
/// playlists is the plaza's first page, the boards are the source's own, the
/// hot words are its search tips, and the songs are the ones this app has
/// already seen the viewer play. A source that serves none of them leaves the
/// page to whatever it does answer.
final class MusicRecommendView extends ConsumerWidget {
  const MusicRecommendView({
    required this.onSearch,
    required this.onOpenPlaylist,
    required this.onOpenFeatured,
    required this.onOpenBoard,
    super.key,
  });

  /// Runs one hot word in the library's search.
  final ValueChanged<String> onSearch;

  /// Opens one of the plaza's playlists in 精选.
  final ValueChanged<MusicPlaylistInfo> onOpenPlaylist;

  /// Opens 精选, where the whole plaza lives.
  final VoidCallback onOpenFeatured;

  /// Opens the charts view on the board's own id.
  final ValueChanged<String> onOpenBoard;

  /// How many cards the strip, songs the list, boards the table and words the
  /// chip row show: the page is a taste of each, not a browser.
  static const int _stripCount = 12;
  static const int _songCount = 8;
  static const int _boardCount = 6;
  static const int _wordCount = 14;

  /// The cover measure the strip draws at; the card's own text block sits
  /// under it, so one row of covers needs no wrapping.
  static const double _cardWidth = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    // The page's gutter is the window's, the same measure the live module's
    // pages keep: a narrow window gets the tighter of the two.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final settings = ref.watch(musicPlaybackSettingsProvider);
    final ui = ref.watch(musicUiSettingsProvider);
    final plaza = musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider)) != null;
    final hotTags = ref.watch(musicOnlineHotTagsProvider).value ?? const <MusicPlaylistTag>[];
    final order = ref.watch(musicPlaylistSortsProvider).firstOrNull?.id ?? '';
    final firstTag = hotTags.firstOrNull;
    final firstPage = plaza && firstTag != null
        ? ref.watch(musicOnlinePlaylistsProvider((tag: firstTag.id, order: order, page: 1)))
        : null;
    final playlists = (firstPage?.value?.items ?? const <MusicPlaylistInfo>[]).take(_stripCount).toList();
    // The banner takes the plaza's hottest entry out of the strip rather than
    // above it: the page then opens with one large visual and its first row
    // carries the rest, with nothing shown twice.
    final hero = ui.shows(MusicUiElement.recommendBanner) ? playlists.firstOrNull : null;
    final strip = hero == null ? playlists : playlists.skip(1).toList();
    final boards = (ref.watch(musicCatalogsProvider).value ?? const <audio.MusicCatalog>[]).take(_boardCount).toList();
    // The hot words follow the search page's own switch: a viewer who hid
    // them there does not want them here either.
    final words = settings.showHotSearches
        ? (ref.watch(musicHotSearchesProvider).value ?? const <String>[]).take(_wordCount).toList()
        : const <String>[];
    final recent = ref.watch(musicRecentProvider).take(_songCount).toList();
    final favourites = ref.watch(musicFavouritesProvider);
    // The album and artist rails are the history's own credits — a platform
    // that serves no album or artist page contributes nothing here.
    final albums = ref.watch(musicHistoryAlbumsProvider);
    final artists = ref.watch(musicHistoryArtistsProvider);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    // The strip is asked in two steps — the hot tags, then the first page
    // under the tag they name — so a plaza with no tag yet is still on its
    // way, and one whose tags or page refused gets the retry row.
    final hotTagsState = ref.watch(musicOnlineHotTagsProvider);
    final waitingForPlaza = plaza && (hotTagsState.isLoading || (firstPage?.isLoading ?? false));
    final plazaFailed = plaza && (hotTagsState.hasError || (firstPage?.hasError ?? false));

    if (playlists.isEmpty &&
        boards.isEmpty &&
        words.isEmpty &&
        recent.isEmpty &&
        albums.isEmpty &&
        artists.isEmpty &&
        !waitingForPlaza) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.sparkles),
          title: Text(t.music.recEmptyTitle),
          description: Text(t.music.recEmptyDescription),
          actions: [
            if (plaza)
              DsButton(variant: DsButtonVariant.secondary, onPressed: onOpenFeatured, child: Text(t.music.recMore)),
          ],
        ),
      );
    }

    Widget head(String title, {Widget? trailing}) => Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: Text(title, style: theme.typography.title.copyWith(color: colors.text)),
          ),
          ?trailing,
        ],
      ),
    );

    // Pull to refresh, the gesture the feeds already use: every ask this page
    // draws on is asked again, and the spinner ends when the strip is whole.
    return CustomRefreshIndicator(
      onRefresh: () => _refresh(ref),
      builder: buildDsRefreshIndicator,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            if (plaza) ...[
              if (hero != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, 0),
                  child: MusicRecommendHero(info: hero, tag: firstTag?.name, onOpen: () => onOpenPlaylist(hero)),
                ),
              if (strip.isNotEmpty || waitingForPlaza || plazaFailed) ...[
                head(
                  t.music.recPlaylists,
                  trailing: DsButton(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    trailing: const DsIcon(DsIcons.chevronRight, size: 14),
                    onPressed: onOpenFeatured,
                    child: Text(t.music.recMore),
                  ),
                ),
                if (strip.isNotEmpty)
                  SizedBox(
                    height: _cardWidth + kMusicPlaylistInfoHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      itemCount: strip.length,
                      separatorBuilder: (context, _) => const SizedBox(width: DsSpace.s12),
                      itemBuilder: (context, index) => SizedBox(
                        width: _cardWidth,
                        child: MusicPlaylistCard.online(info: strip[index], onOpen: () => onOpenPlaylist(strip[index])),
                      ),
                    ),
                  )
                else if (waitingForPlaza)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DsSpace.s24),
                    child: Center(child: DsSpinner(style: DsSpinnerStyle(size: 24))),
                  )
                else
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s4),
                    child: Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(
                          child: Text(
                            t.music.onlineLoadFailed,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                        ),
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          onPressed: () {
                            final tag = firstTag;
                            ref.invalidate(musicOnlineHotTagsProvider);
                            if (tag != null) {
                              ref.invalidate(musicOnlinePlaylistsProvider((tag: tag.id, order: order, page: 1)));
                            }
                          },
                          child: Text(t.common.retry),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
            if (recent.isNotEmpty) ...[
              head(
                t.music.recRecent,
                trailing: DsButton(
                  variant: DsButtonVariant.primary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.play, size: 16),
                  onPressed: () => unawaited(playerController.playAll(recent)),
                  child: Text(t.music.playAll),
                ),
              ),
              DsListSection(
                children: [
                  const MusicSongTableHeader(),
                  for (final (index, song) in recent.indexed)
                    MusicSongRow(
                      track: song,
                      number: index + 1,
                      playing: playingId == song.id,
                      favourite: favourites.contains(song),
                      onPlay: () => unawaited(playerController.playAll(recent, index: index)),
                      onFavourite: () => unawaited(favouriteController.toggle(song)),
                      onPlayNext: () => unawaited(playerController.playNext(song)),
                      onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                      onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
                      onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
                    ),
                ],
              ),
            ],
            if (albums.isNotEmpty) ...[
              head(t.music.recAlbums),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s12,
                  children: [
                    for (final link in albums)
                      MusicAlbumCard(
                        album: link.album,
                        onPressed: () => openMusicAlbum(context, sourceId: link.sourceId, albumId: link.album.id),
                      ),
                  ],
                ),
              ),
            ],
            if (artists.isNotEmpty) ...[
              head(t.music.recArtists),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s12,
                  children: [
                    for (final link in artists)
                      MusicArtistCard(
                        name: link.name,
                        sourceLabel: musicBrowseSourceLabel(ref, t, link.sourceId),
                        onPressed: () => openMusicArtist(
                          context,
                          sourceId: link.sourceId,
                          artist: link.name,
                          artistId: link.artistId,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (words.isNotEmpty) ...[
              head(t.music.searchHot),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s4),
                child: Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    for (final word in words)
                      DsChip(
                        label: Text(word),
                        selected: false,
                        onChanged: (on) {
                          if (on) onSearch(word);
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (boards.isNotEmpty) ...[
              head(t.music.recBoards),
              DsListSection(
                children: [
                  for (final board in boards)
                    DsListRow(
                      leading: const DsIcon(DsIcons.chartColumn),
                      title: Text(board.name),
                      showChevron: true,
                      onPressed: () => onOpenBoard(board.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Re-asks every source this page draws on — the plaza's tags and their
  /// first page, the hot words and the boards — and waits for the strip so the
  /// pull's spinner ends when the page is whole again.
  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(musicOnlineHotTagsProvider)
      ..invalidate(musicHotSearchesProvider)
      ..invalidate(musicCatalogsProvider);
    try {
      final tag = (await ref.read(musicOnlineHotTagsProvider.future)).firstOrNull;
      if (tag == null) return;
      final order = ref.read(musicPlaylistSortsProvider).firstOrNull?.id ?? '';
      await ref.read(musicOnlinePlaylistsProvider((tag: tag.id, order: order, page: 1)).future);
    } on Object {
      // The plaza's own row explains a refusal; the pull ends either way.
    }
  }
}

/// 推荐's banner: the plaza's hottest entry given the one large visual the
/// video sites open their home with — the cover whole beside its name in
/// large type, blurred again behind the card for the colour, the credits on
/// one line, and both verbs written out rather than left as icons. The strip
/// under it skips this entry, so the page never shows the same playlist
/// twice.
final class MusicRecommendHero extends ConsumerWidget {
  const MusicRecommendHero({required this.info, required this.onOpen, this.tag, super.key});

  /// The playlist the plaza puts first.
  final MusicPlaylistInfo info;

  /// The plaza tag the entry was read under; the source's own words.
  final String? tag;

  /// Opens it where the whole plaza lives.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final cover = info.cover.isEmpty ? null : info.cover;
    final facts = [
      if (info.author.isNotEmpty) info.author,
      if (info.trackCount > 0) t.music.songsCount(count: info.trackCount),
    ].join(' · ');
    final eyebrow = (tag ?? '').isEmpty ? t.music.recPlaylists : tag!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final coverSize = wide ? 152.0 : 104.0;
        final coverRadius = BorderRadius.circular(theme.radii.overlay);
        return DsCard(
          onPressed: onOpen,
          style: const DsCardStyle(padding: EdgeInsets.zero),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [colors.accent.withValues(alpha: 0.24), colors.surface],
                      ),
                    ),
                  ),
                ),
                if (cover != null)
                  Positioned.fill(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: kLiveGlassCoverFrostSigma,
                          sigmaY: kLiveGlassCoverFrostSigma,
                        ),
                        child: Opacity(
                          opacity: 0.35,
                          child: Transform.scale(
                            scale: 1.5,
                            child: Image(
                              image: cachedImage(cover, policy: ImageCachePolicies.albumCover),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(wide ? DsSpace.s20 : DsSpace.s16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s16,
                    children: [
                      ClipRRect(
                        borderRadius: coverRadius,
                        child: DsImage(
                          image: cover == null ? null : cachedImage(cover, policy: ImageCachePolicies.albumCover),
                          width: coverSize,
                          height: coverSize,
                          semanticLabel: info.name,
                          fallback: CoverFallback(title: info.name),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: DsSpace.s4,
                          children: [
                            Text(
                              eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.accentText),
                            ),
                            Text(
                              info.name.isEmpty ? t.music.recPlaylists : info.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.heading.copyWith(color: colors.text),
                            ),
                            if (facts.isNotEmpty)
                              Text(
                                facts,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: DsSpace.s8),
                              child: Wrap(
                                spacing: DsSpace.s8,
                                runSpacing: DsSpace.s8,
                                children: [
                                  DsButton(
                                    size: DsSize.sm,
                                    leading: const DsIcon(DsIcons.play, size: 16),
                                    onPressed: () => unawaited(_play(context, ref)),
                                    child: Text(t.music.playAll),
                                  ),
                                  DsButton(
                                    variant: DsButtonVariant.secondary,
                                    size: DsSize.sm,
                                    trailing: const DsIcon(DsIcons.chevronRight, size: 14),
                                    onPressed: onOpen,
                                    child: Text(t.music.openPlaylistTitle),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Plays the banner's playlist from its first song: the plaza's card only
  /// names the list, so its tracks are asked for here and a refusal is said
  /// out rather than left as a dead button.
  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final (_, tracks) = await ref.read(musicOnlinePlaylistDetailProvider(info.id).future);
      if (tracks.isEmpty) return;
      await ref.read(musicPlayerProvider.notifier).playAll(tracks);
    } on Object {
      if (!context.mounted) return;
      showDsToast(context: context, title: t.music.onlineLoadFailed, status: DsStatus.danger);
    }
  }
}
