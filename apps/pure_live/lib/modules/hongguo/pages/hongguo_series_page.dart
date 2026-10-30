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
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show HongguoSeriesRow, hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// One series' page: its metadata, the episode shelf, its reviews and related
/// works, and the card that starts playback.
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
  bool _introExpanded = false;

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

  /// Pushes the player at [episode]; the checkpoint rides along only for the
  /// episode it was written on.
  void _play(HongguoSeriesDetail detail, HongguoEpisode? episode, HongguoWatchProgress? row) {
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
    final play = _playCard(context, detail, row, t);
    final shelf = HongguoEpisodeShelf(
      detail: detail,
      current: resume,
      onOpen: (episode) => _play(detail, episode, row),
    );
    final info = _info(context, detail, t);
    final episodeVid = resume?.vid ?? '';
    final comments = HongguoCommentPanel(seriesId: widget.seriesId, episodeVid: episodeVid);
    final related = _RelatedSection(seriesId: widget.seriesId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [play, shelf, info, related, comments],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s16,
                  children: [play, info, related, comments],
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: shelf,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The way into the player: the cover, where the viewer stopped, and the
  /// two ways on — from the checkpoint or from the first episode.
  Widget _playCard(BuildContext context, HongguoSeriesDetail detail, HongguoWatchProgress? row, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = detail.meta;
    final fallback = CoverFallback(title: meta.title, padding: const EdgeInsets.all(DsSpace.s8));
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
                width: 56,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  child: meta.cover.isEmpty
                      ? fallback
                      : DsImage(
                          image: hongguoCoverImage(meta.cover),
                          aspectRatio: 56 / 76,
                          semanticLabel: meta.title,
                          fallback: fallback,
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      meta.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(
                      row == null
                          ? t.hongguo.notWatchedYet
                          : '${t.hongguo.episodeLabel(index: row.episodeIndex)} · '
                                '${hongguoDurationText(Duration(milliseconds: row.positionMs))}',
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
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
                onPressed: detail.episodes.isEmpty ? null : () => _play(detail, null, row),
                child: Text(row == null ? t.hongguo.play : t.hongguo.continueWatching),
              ),
              if (row != null && detail.episodes.isNotEmpty)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  onPressed: () => _play(detail, detail.episodes.first, null),
                  child: Text(t.hongguo.playFromStart),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The series' own metadata: the status, the heat and figures, the board
  /// it sits on, the shelf categories, and the story blurb with its way to
  /// read all of it.
  Widget _info(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = detail.meta;
    final figures = <String>[
      if (meta.statusText.isNotEmpty) meta.statusText,
      if (meta.hot.isNotEmpty) meta.hot,
      if (meta.playCount > 0) '${t.hongguo.plays} ${AudienceFormat.format(meta.playCount)}',
      if (meta.rating > 0) t.hongguo.rating(score: meta.rating.toStringAsFixed(1)),
      if (meta.followedCount > 0) '${t.hongguo.followers} ${AudienceFormat.format(meta.followedCount)}',
      if (meta.likeCount > 0) '${t.hongguo.likes} ${AudienceFormat.format(meta.likeCount)}',
      if (meta.episodeCount > 0) t.hongguo.episodesCount(count: meta.episodeCount),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(meta.title, style: theme.typography.title.copyWith(color: colors.text)),
        if (figures.isNotEmpty)
          Text(figures.join(' · '), style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (meta.rankLabel.isNotEmpty || meta.categories.isNotEmpty)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              if (meta.rankLabel.isNotEmpty)
                DsBadge(label: Text(meta.rankLabel), status: DsStatus.warning, icon: const DsIcon(DsIcons.trophy)),
              for (final category in meta.categories) DsBadge(label: Text(category), dot: false),
            ],
          ),
        Consumer(
          builder: (context, ref, _) {
            final t = context.t;
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
            return Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              children: [
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
            );
          },
        ),
        if (meta.intro.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              GestureDetector(
                onTap: () => setState(() => _introExpanded = !_introExpanded),
                child: Text(
                  meta.intro,
                  maxLines: _introExpanded ? null : 3,
                  overflow: _introExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.textMuted),
                ),
              ),
              DsLink(
                label: _introExpanded ? t.hongguo.collapse : t.hongguo.expand,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
              ),
            ],
          ),
      ],
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
    } on Object catch (error) {
      if (!mounted) return;
      showDsToast(context: this.context, title: '$error');
    }
  }
}
