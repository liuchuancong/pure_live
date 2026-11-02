import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart'
    show hongguoAccountFavoritesProvider, hongguoAccountProvider, hongguoReservationsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoFailureText;
import 'package:pure_live/modules/hongguo/controller/hongguo_covers.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart'
    show hongguoRelatedClientProvider, hongguoRelatedProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_related.dart' show HongguoRelatedWork;
import 'package:pure_live/modules/hongguo/widgets/hongguo_comment_panel.dart' show HongguoCommentPanel;
import 'package:pure_live/modules/hongguo/widgets/hongguo_episode_shelf.dart' show HongguoEpisodeShelf;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart'
    show HongguoProgressStripe, HongguoSeriesRow, hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// One series' page: the series' own head, the episode shelf, its reviews and
/// related works.
///
/// The picture itself lives on its own page (`RouteNames.hongguoPlayer`), so
/// this page never holds a player handle: it reads the shelf's checkpoint,
/// offers it, and hands the chosen episode over.
final class HongguoSeriesPage extends ConsumerStatefulWidget {
  /// The series behind [seriesId].
  const HongguoSeriesPage({required this.seriesId, super.key});

  /// The series' id.
  final String seriesId;

  @override
  ConsumerState<HongguoSeriesPage> createState() => _HongguoSeriesPageState();
}

final class _HongguoSeriesPageState extends ConsumerState<HongguoSeriesPage> {
  HongguoSeriesDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref.read(hongguoClientProvider).detail(widget.seriesId);
      if (!mounted) return;
      // Opening the series is the shelf's acknowledgement: the `新增 N 集`
      // line on the card stops at what was read.
      ref.read(hongguoLibraryProvider.notifier).acknowledgeUpdates(widget.seriesId);
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = hongguoFailureText(error);
      });
    }
  }

  /// The checkpoint the shelf holds for this series, when one is worth
  /// resuming — a finished series keeps its row but is not resumed.
  HongguoWatchProgress? _checkpoint() {
    final row = ref.watch(hongguoLibraryProvider).progressOf(widget.seriesId);
    if (row == null || row.completed || row.positionMs <= 0) return null;
    return row;
  }

  /// The detail's episode at the checkpoint, matched by vid then by index.
  HongguoEpisode? _resumeEpisode(HongguoSeriesDetail detail, HongguoWatchProgress? row) {
    if (row == null) return null;
    final episodes = detail.episodes;
    if (episodes.isEmpty) return null;
    if (row.episodeVid.isNotEmpty) {
      final byVid = episodes.where((episode) => episode.vid == row.episodeVid);
      if (byVid.isNotEmpty) return byVid.first;
    }
    final byIndex = episodes.where((episode) => episode.index == row.episodeIndex);
    return byIndex.isEmpty ? null : byIndex.first;
  }

  /// Pushes the player at [episode]; the checkpoint passed as `row` rides
  /// along only for the episode it was written on, as the head asks for one
  /// and the shelf for another.
  void _play(HongguoSeriesDetail detail, HongguoEpisode? episode, {HongguoWatchProgress? row}) {
    final chosen = episode ?? _resumeEpisode(detail, row) ?? detail.episodes.first;
    final resume = row != null && row.episodeVid == chosen.vid ? row.positionMs / 1000 : null;
    unawaited(context.push(RouteNames.hongguoPlayerFor(widget.seriesId, vid: chosen.vid, resumeSeconds: resume)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final detail = _detail;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(detail?.meta.title ?? t.hongguo.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading && detail == null
          ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
          : _error != null && detail == null
          ? Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.cloudOff),
                title: Text(t.hongguo.loadFailed),
                description: Text(_error!),
                actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.common.retry))],
              ),
            )
          : _body(context, detail, t),
    );
  }

  Widget _body(BuildContext context, HongguoSeriesDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final row = _checkpoint();
    final resume = _resumeEpisode(detail, row);
    final head = HongguoSeriesHead(
      detail: detail,
      seriesId: widget.seriesId,
      onPlay: ({resume = false, episode}) => _play(detail, episode, row: resume ? row : null),
    );
    final shelf = HongguoEpisodeShelf(
      detail: detail,
      current: resume,
      onOpen: (episode) => _play(detail, episode, row: row),
    );
    final episodeVid = resume?.vid ?? '';
    final comments = HongguoCommentPanel(seriesId: widget.seriesId, episodeVid: episodeVid);
    final related = _RelatedSection(seriesId: widget.seriesId);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The episode shelf used to sit in a 320px column of its own on a wide
        // window; the reference lays the detail page out as one reading column
        // — head, then the selection, then the rest — so the shelf keeps its
        // place in the flow at every width.
        // The detail page keeps one wider margin than a list at reading
        // width; below that it is the app's own page inset, not this module's
        // number — a phone must not see two different left edges under one
        // menu.
        final side = constraints.maxWidth >= 1000 ? DsSpace.s24 : LiveWindow.pageInset(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, DsSpace.s12, side, DsSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
            children: [head, shelf, related, comments],
          ),
        );
      },
    );
  }
}

/// The series' own head: the cover, the name, the update and the figures,
/// where the viewer stopped, every way into the player and the shelf's own
/// bookmark — all in one block, the way the station's detail pages open.
///
/// Before it was two: a small card with the cover, the name and the play
/// button, then a block repeating the name as the page's title with the
/// figures, the badges and the favourite under it. The head says each of
/// those once and keeps every action of the series beside its name.
final class HongguoSeriesHead extends ConsumerStatefulWidget {
  /// The head for [detail]; [onPlay] opens the chosen episode.
  const HongguoSeriesHead({required this.detail, required this.seriesId, required this.onPlay, super.key});

  /// The series as the detail page answered it.
  final HongguoSeriesDetail detail;

  /// The series' id, the key the library's progress and bookmark hang on.
  final String seriesId;

  /// Opens the player: the checkpoint's episode when `resume` is set, another
  /// one when the viewer picks it from the head.
  final void Function({bool resume, HongguoEpisode? episode}) onPlay;

  @override
  ConsumerState<HongguoSeriesHead> createState() => _HongguoSeriesHeadState();
}

final class _HongguoSeriesHeadState extends ConsumerState<HongguoSeriesHead> {
  bool _introExpanded = false;

  /// The checkpoint worth resuming — a finished series keeps its row in the
  /// history but is not resumed here.
  HongguoWatchProgress? _checkpoint() {
    final row = ref.watch(hongguoLibraryProvider).progressOf(widget.seriesId);
    if (row == null || row.completed || row.positionMs <= 0) return null;
    return row;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = widget.detail;
    final meta = detail.meta;
    final row = _checkpoint();
    final fallback = CoverFallback(title: meta.title, padding: const EdgeInsets.all(DsSpace.s8));
    final figures = <String>[
      if (meta.statusText.isNotEmpty) meta.statusText,
      if (meta.hot.isNotEmpty) meta.hot,
      if (meta.playCount > 0) '${t.hongguo.plays} ${AudienceFormat.format(meta.playCount)}',
      if (meta.rating > 0) t.hongguo.rating(score: meta.rating.toStringAsFixed(1)),
      if (meta.followedCount > 0) '${t.hongguo.followers} ${AudienceFormat.format(meta.followedCount)}',
      if (meta.likeCount > 0) '${t.hongguo.likes} ${AudienceFormat.format(meta.likeCount)}',
      if (meta.episodeCount > 0) t.hongguo.episodesCount(count: meta.episodeCount),
    ];
    final library = ref.watch(hongguoLibraryProvider);
    final account = ref.watch(hongguoAccountProvider);
    final snapshot = HongguoSeries(
      seriesId: meta.seriesId,
      title: meta.title,
      cover: meta.cover,
      intro: meta.intro,
      episodeCount: meta.episodeCount,
    );
    final favored = library.isFavorite(meta.seriesId);
    final hasEpisode = detail.episodes.isNotEmpty;
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s12,
            children: [
              SizedBox(
                width: 88,
                height: 118,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  child: meta.cover.isEmpty
                      ? fallback
                      : DsImage(
                          image: hongguoCoverImage(meta.cover),
                          aspectRatio: 88 / 118,
                          semanticLabel: meta.title,
                          fallback: fallback,
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s6,
                  children: [
                    Text(
                      meta.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.heading.copyWith(color: colors.text),
                    ),
                    if (figures.isNotEmpty)
                      Text(figures.join(' · '), style: theme.typography.caption.copyWith(color: colors.textMuted)),
                    if (meta.rankLabel.isNotEmpty || meta.categories.isNotEmpty)
                      Wrap(
                        spacing: DsSpace.s8,
                        runSpacing: DsSpace.s4,
                        children: [
                          if (meta.rankLabel.isNotEmpty)
                            DsBadge(
                              label: Text(meta.rankLabel),
                              status: DsStatus.warning,
                              icon: const DsIcon(DsIcons.trophy),
                            ),
                          for (final category in meta.categories) DsBadge(label: Text(category), dot: false),
                        ],
                      ),
                    // The one place the page says where the viewer stopped;
                    // the stripe is the history row's own reading of it.
                    if (row != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s6,
                        children: [
                          Text(
                            '${t.hongguo.episodeLabel(index: row.episodeIndex)} · '
                            '${hongguoDurationText(Duration(milliseconds: row.positionMs))}',
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                          HongguoProgressStripe(fraction: row.fraction),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              DsButton(
                leading: const DsIcon(DsIcons.play, size: 16),
                onPressed: hasEpisode ? () => widget.onPlay(resume: true) : null,
                child: Text(row == null ? t.hongguo.play : t.hongguo.continueWatching),
              ),
              if (row != null && hasEpisode)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  onPressed: () => widget.onPlay(episode: detail.episodes.first),
                  child: Text(t.hongguo.playFromStart),
                ),
              DsButton(
                variant: favored ? DsButtonVariant.primary : DsButtonVariant.secondary,
                leading: DsIcon(favored ? DsIcons.heart : DsIcons.heartOff, size: 16),
                onPressed: () {
                  final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(snapshot);
                  showDsToast(
                    context: context,
                    title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff,
                  );
                },
                child: Text(favored ? t.hongguo.favorited : t.hongguo.favorite),
              ),
              if (account.signedIn)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  leading: const DsIcon(DsIcons.cloudUpload, size: 16),
                  onPressed: () =>
                      unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).setFavorite(snapshot, add: true)),
                  child: Text(t.hongguo.cloudFavoriteOn),
                ),
            ],
          ),
          if (meta.intro.isNotEmpty) _intro(context, meta.intro, theme, colors, t),
        ],
      ),
    );
  }

  /// The story blurb: three lines until the viewer asks for the rest, and the
  /// switch only appears when the words actually run past three lines.
  Widget _intro(BuildContext context, String text, DsThemeData theme, DsColors colors, Translations t) {
    final style = theme.typography.body.copyWith(color: colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 3,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s4,
          children: [
            Text(
              text,
              maxLines: _introExpanded ? null : 3,
              overflow: _introExpanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              DsLink(
                label: _introExpanded ? t.hongguo.collapse : t.hongguo.expand,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
              ),
          ],
        );
      },
    );
  }
}

/// The series' related works: a row per season, live ones open, waiting
/// ones reservable on the signed-in account.
final class _RelatedSection extends ConsumerStatefulWidget {
  const _RelatedSection({required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<_RelatedSection> createState() => _RelatedSectionState();
}

final class _RelatedSectionState extends ConsumerState<_RelatedSection> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoRelatedProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoRelatedProvider.notifier).open(widget.seriesId));
    });
    final account = ref.watch(hongguoAccountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.hongguo.related, style: theme.typography.title.copyWith(color: colors.text)),
        if (state.loading && state.items.isEmpty) const Center(child: DsSpinner()),
        if (state.error != null && state.items.isEmpty)
          Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (!state.loading && state.items.isEmpty && state.error == null)
          Text(t.hongguo.relatedNone, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final work in state.items)
          HongguoSeriesRow(
            series: work.series.copyWith(
              hot: [
                work.season,
                if (work.upcoming) t.hongguo.relatedReserve else t.hongguo.relatedLive,
              ].where((line) => line.isNotEmpty).join(' · '),
            ),
            onOpen: work.upcoming ? null : () => _openRelated(context, work.series),
            trailing: work.upcoming && account.signedIn
                ? DsButton(
                    size: DsSize.sm,
                    variant: DsButtonVariant.secondary,
                    onPressed: () {
                      final credentials = ref.read(hongguoAccountProvider).credentials;
                      if (credentials == null) return;
                      unawaited(_reserve(context, credentials, work));
                    },
                    child: Text(t.hongguo.relatedReserve),
                  )
                : null,
          ),
      ],
    );
  }
}

/// Pushes another series' page.
void _openRelated(BuildContext context, HongguoSeries series) {
  unawaited(context.push(RouteNames.hongguoSeries.replaceFirst(':seriesId', series.seriesId)));
}

/// The related section's reserve action, on the state above it.
extension _ReserveAction on _RelatedSectionState {
  Future<void> _reserve(BuildContext context, HongguoCredentials credentials, HongguoRelatedWork work) async {
    final t = context.t;
    try {
      await ref.read(hongguoRelatedClientProvider).reserve(credentials, work);
      unawaited(ref.read(hongguoReservationsProvider.notifier).refresh());
      if (!mounted) return;
      showDsToast(context: this.context, title: t.hongguo.reserved);
    } on Object {
      if (!mounted) return;
      // The transport's own words are noise here; the toast names what the
      // viewer was trying to do and stays openable on a retry.
      showDsToast(context: this.context, title: t.hongguo.reserveFailed, status: DsStatus.danger);
    }
  }
}
