import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show kHongguoSite;
import 'package:pure_live/modules/hongguo/official/hongguo_related.dart' show HongguoRelatedWork;
import 'package:pure_live/modules/hongguo/widgets/hongguo_card_menu.dart' show HongguoCardMenu;
import 'package:pure_live/modules/hongguo/widgets/hongguo_comment_panel.dart' show HongguoCommentPanel;
import 'package:pure_live/modules/hongguo/widgets/hongguo_episode_shelf.dart' show HongguoEpisodeShelf;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart'
    show HongguoProgressStripe, HongguoSeriesCard, HongguoShelf, hongguoDurationText;
import 'package:pure_live/shared/shared.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: detail?.meta.title ?? t.hongguo.opening),
          Expanded(
            child: _loading && detail == null
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
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HongguoSeriesDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final row = _checkpoint();
    final resume = _resumeEpisode(detail, row);
    final window = MediaQuery.sizeOf(context).width;
    final head = HongguoSeriesHead(
      detail: detail,
      seriesId: widget.seriesId,
      posterWidth: LiveWindow.isCompact(window) ? 116 : 200,
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
        // place in the flow at every width. The column itself ends where the
        // season page's ends, the family's reading width, so a wide window
        // does not stretch the words past what a head can hold.
        // The detail page keeps one wider margin than a list at reading
        // width; below that it is the app's own page inset, not this module's
        // number — a phone must not see two different left edges under one
        // menu.
        final side = constraints.maxWidth >= 1000 ? DsSpace.s24 : LiveWindow.pageInset(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, DsSpace.s12, side, DsSpace.s24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s16,
                children: [
                  head,
                  // The one rule the season page draws: between the head and
                  // everything that follows it.
                  const DsDivider(),
                  shelf,
                  related,
                  comments,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The series' own head: the poster at its 3:4 reading size with the
/// station's score stamped on its corner, the name, the rank and the
/// categories as chips, the counts demoted to one gray line, the stripe
/// saying where the viewer stopped, and one primary way into the player
/// beside the bookmarks — the season page's own composition, tuned to a
/// drama's words.
///
/// Before it sat in a card with a small cover and every verb speaking at
/// the same volume; the poster now carries the first read and the row of
/// actions keeps one primary among quiet ghosts.
final class HongguoSeriesHead extends ConsumerStatefulWidget {
  /// The head for [detail]; [onPlay] opens the chosen episode.
  const HongguoSeriesHead({
    required this.detail,
    required this.seriesId,
    required this.posterWidth,
    required this.onPlay,
    super.key,
  });

  /// The series as the detail page answered it.
  final HongguoSeriesDetail detail;

  /// The series' id, the key the library's progress and bookmark hang on.
  final String seriesId;

  /// The poster's width: the wide head's 200, the phone's 116.
  final double posterWidth;

  /// Opens the player: the checkpoint's episode when `resume` is set, another
  /// one when the viewer picks it from the head.
  final void Function({bool resume, HongguoEpisode? episode}) onPlay;

  @override
  ConsumerState<HongguoSeriesHead> createState() => _HongguoSeriesHeadState();
}

final class _HongguoSeriesHeadState extends ConsumerState<HongguoSeriesHead> {
  bool _introExpanded = false;

  /// Hands the series' public page to the system share sheet where the
  /// platform has one — the vod season's share, pointed at a hongguo title —
  /// with the link the station itself answers for; where the sheet will not
  /// run, the link goes to the clipboard with a word of thanks, the player's
  /// own share.
  Future<void> _share() async {
    final title = widget.detail.meta.title.trim();
    final link = '$kHongguoSite/detail?series_id=${Uri.encodeComponent(widget.seriesId)}';
    final platform = defaultTargetPlatform;
    final sheet =
        !kIsWeb &&
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows);
    if (sheet) {
      try {
        final text = title.isEmpty ? link : '$title\n$link';
        await SharePlus.instance.share(ShareParams(text: text, subject: title.isEmpty ? null : title));
        return;
      } on Object {
        // A platform without a usable sheet falls through to the clipboard.
      }
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showDsToast(context: context, title: context.t.hongguo.shareCopied);
  }

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
    final rating = meta.rating > 0 ? meta.rating.toStringAsFixed(1) : '';
    // The weak line: the state, the heat and the counts in one gray caption.
    // The score and the rank live on the poster and the chips row, where
    // they are read first; the station's own status line says the total in
    // words — 全102集 / 更新至第6集 — so the bare count only speaks when
    // that line is absent.
    final facts = <String>[
      if (meta.statusText.isNotEmpty) meta.statusText,
      if (meta.hot.isNotEmpty) meta.hot,
      if (meta.playCount > 0) '${t.hongguo.plays} ${AudienceFormat.format(meta.playCount)}',
      if (meta.followedCount > 0) '${t.hongguo.followers} ${AudienceFormat.format(meta.followedCount)}',
      if (meta.likeCount > 0) '${t.hongguo.likes} ${AudienceFormat.format(meta.likeCount)}',
      if (meta.episodeCount > 0 && meta.statusText.isEmpty) t.hongguo.episodesCount(count: meta.episodeCount),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        SizedBox(
          width: widget.posterWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (meta.cover.isEmpty)
                    fallback
                  else
                    DsImage(
                      image: hongguoCoverImage(meta.cover),
                      aspectRatio: 3 / 4,
                      semanticLabel: meta.title,
                      fallback: fallback,
                    ),
                  // The soft band under the cover's bottom edge, so anything
                  // riding the picture stays legible over a bright one.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  // The score on the poster's corner, the season page's
                  // accent stamp: the one figure worth reading before the
                  // words.
                  if (rating.isNotEmpty)
                    PositionedDirectional(top: DsSpace.s6, end: DsSpace.s6, child: _scoreBadge(context, rating)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              Text(
                meta.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.heading.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
              // The chips row leads with the rank's trophy — the station's
              // own billboard — then the categories, then the score in its
              // stamp: the corner and the row each say the figure once, in
              // their own place.
              if (meta.rankLabel.isNotEmpty || meta.categories.isNotEmpty || rating.isNotEmpty)
                Wrap(
                  spacing: DsSpace.s6,
                  runSpacing: DsSpace.s6,
                  children: [
                    if (meta.rankLabel.isNotEmpty)
                      DsBadge(
                        label: Text(meta.rankLabel),
                        status: DsStatus.warning,
                        icon: const DsIcon(DsIcons.trophy),
                      ),
                    for (final category in meta.categories) DsBadge(label: Text(category), dot: false),
                    if (rating.isNotEmpty) _scoreBadge(context, t.hongguo.rating(score: rating)),
                  ],
                ),
              if (facts.isNotEmpty)
                Text(
                  facts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              // The one place the page says where the viewer stopped, set
              // above the actions as its own strip — the stripe is the
              // history row's own reading of it.
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
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DsButton(
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.play, size: 14),
                    onPressed: hasEpisode ? () => widget.onPlay(resume: true) : null,
                    child: Text(row == null ? t.hongguo.play : t.hongguo.continueWatching),
                  ),
                  if (row != null && hasEpisode)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => widget.onPlay(episode: detail.episodes.first),
                      child: Text(t.hongguo.playFromStart),
                    ),
                  // The bookmark stays a quiet ghost whether it is on or off —
                  // only the heart and the word change, so the row keeps one
                  // primary voice.
                  DsButton(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    leading: DsIcon(favored ? DsIcons.heart : DsIcons.heartOff, size: 14),
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
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.cloudUpload, size: 14),
                      onPressed: () => unawaited(
                        ref.read(hongguoAccountFavoritesProvider.notifier).setFavorite(snapshot, add: true),
                      ),
                      child: Text(t.hongguo.cloudFavoriteOn),
                    ),
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.hongguo.share,
                    onPressed: () => unawaited(_share()),
                    icon: const DsIcon(DsIcons.share),
                  ),
                ],
              ),
              if (meta.intro.isNotEmpty) _intro(context, meta.intro, theme, colors, t),
            ],
          ),
        ),
      ],
    );
  }

  /// The score in the accent stamp: white digits on the accent fill, the
  /// poster corner and the chips row saying the same figure once each in
  /// their own place.
  Widget _scoreBadge(BuildContext context, String text) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsBadge(
      label: Text(text),
      dot: false,
      style: DsBadgeStyle(
        background: colors.accent,
        foreground: colors.onAccent,
        borderRadius: BorderRadius.circular(theme.radii.control(18)),
        textStyle: theme.typography.numeric(
          theme.typography.caption.copyWith(color: colors.onAccent, fontWeight: FontWeight.w700),
        ),
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

/// The series' related works: one row of the home shelves' poster cards, a
/// season to a card, live ones open, waiting ones reservable from the card's
/// own menu on the signed-in account.
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
    // The row's figure line — the season, and whether the work runs or is yet
    // to come — is what the card stamps on its cover, so the same words ride
    // the series into the shelf and the card says its state where the row
    // used to.
    final works = <HongguoRelatedWork, HongguoSeries>{
      for (final work in state.items)
        work: work.series.copyWith(
          hot: [
            work.season,
            if (work.upcoming) t.hongguo.relatedReserve else t.hongguo.relatedLive,
          ].where((line) => line.isNotEmpty).join(' · '),
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        HongguoShelf(
          title: t.hongguo.related,
          items: works.values.toList(),
          loading: state.loading,
          error: state.error,
          onRetry: () => unawaited(ref.read(hongguoRelatedProvider.notifier).open(widget.seriesId)),
          cardBuilder: (context, series) {
            final work = works.entries.where((entry) => entry.value.seriesId == series.seriesId).first.key;
            return _relatedCard(context, series, work, reservable: work.upcoming && account.signedIn);
          },
        ),
        if (!state.loading && state.items.isEmpty && state.error == null)
          Text(t.hongguo.relatedNone, style: theme.typography.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }

  /// One related title as the shelf's poster card, inside the card's menu:
  /// an upcoming title keeps its reserve verb but no open one — a poster card
  /// has no trailing button to hold the action, and the menu is where a page
  /// hangs its own, so the signed-in viewer reserves from there while the
  /// cover's line still says 预约. The menu reads the same answer, so it
  /// offers nothing this card cannot do.
  Widget _relatedCard(BuildContext context, HongguoSeries series, HongguoRelatedWork work, {required bool reservable}) {
    final open = work.upcoming ? null : () => _openRelated(context, work.series);
    return HongguoCardMenu(
      series: series,
      onOpen: open,
      items: [
        if (reservable)
          DsMenuItem(
            leading: const DsIcon(DsIcons.bell),
            label: Text(context.t.hongguo.relatedReserve),
            onPressed: () {
              final credentials = ref.read(hongguoAccountProvider).credentials;
              if (credentials == null) return;
              unawaited(_reserve(context, credentials, work));
            },
          ),
      ],
      child: HongguoSeriesCard(series: series, onOpen: open, preview: true),
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
