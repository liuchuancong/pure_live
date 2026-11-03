import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/features/settings/room/room_card_settings.dart' show kRoomCardInfoExtent;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_covers.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/shared/shared.dart';

/// "1:02:03" for an episode's length, mirroring the station pages' clock.
String hongguoDurationText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${duration.inMinutes}:$seconds';
}

/// The information block under a poster card: the name on one line and the
/// listing line on the next, at the height the room card's information area
/// keeps. Held at a fixed height so a row of cards ends at the same line
/// whatever its column width, and so a poster wall — whose tiles the grid
/// fixes — never pushes the two lines over the card's edge.
const double kHongguoSeriesCardInfoExtent = kRoomCardInfoExtent;

/// The poster card's width over height: the one measure both of its homes use,
/// the card grids' tiles and [HongguoShelf]'s row. The 3:4 cover is a preference
/// under it and takes the height the name block leaves.
const double kHongguoSeriesTileAspect = 0.62;

/// Where the head's 续播 puts the viewer, in seconds — null when the shelf has
/// no place to go back to: an unfinished title, stopped partway inside, on an
/// episode it can name. The head's verb reads the same answer, so the word on
/// the button and the position it opens at cannot disagree.
double? hongguoResumeSeconds(HongguoWatchProgress? seen) =>
    seen != null && !seen.completed && seen.positionMs > 0 && seen.episodeVid.isNotEmpty
    ? seen.positionMs / 1000
    : null;

/// What the local shelf says about a title: 已看完 once this device finished it,
/// the episode it stopped at otherwise. One wording for the board's row, the
/// poster card and the list row — the viewer's own state is said the same way
/// wherever it appears.
String hongguoWatchedLabel(Translations t, HongguoWatchProgress watched) =>
    watched.completed ? t.hongguo.watchedBadge : t.hongguo.favoriteWatchedTo(index: watched.episodeIndex);

/// One series' subtitle line: the viewer's own progress where the listing knows
/// it, then the episode count, the play figure and the shelf categories,
/// whichever the listing carries. [totalInHot] says the
/// figure line already names the series' own total — a history row's
/// 「12集/80集」, a favorite's 「共 80 集（+3）」 — and then the leading count
/// is the same number printed twice in one row, which a row does not do.
String hongguoSeriesSubtitle(
  Translations t,
  HongguoSeries series, {
  bool totalInHot = false,
  HongguoWatchProgress? watched,
}) {
  final parts = <String>[
    // The viewer's own state leads the line, as it leads the board row's marks.
    if (watched case final seen?) hongguoWatchedLabel(t, seen),
    if (!totalInHot && series.episodeCount > 0) t.hongguo.episodesCount(count: series.episodeCount),
    if (series.hot.isNotEmpty)
      series.hot
    else if (series.playCount > 0)
      '${t.hongguo.plays} ${AudienceFormat.format(series.playCount)}',
    if (series.category.isNotEmpty) series.category,
  ];
  return parts.join(' · ');
}

/// One favorite's own line: the reference's two readings — the episode
/// total with what the check found it gained, or the pending note when the
/// platform has not said — and where the viewer stopped.
String hongguoFavoriteLine(Translations t, HongguoLibraryState library, HongguoSeries series) {
  final update = library.updates[series.seriesId];
  final total = update?.total ?? series.episodeCount;
  final progress = library.progressOf(series.seriesId);
  final parts = <String>[
    if (update != null && update.added > 0)
      t.hongguo.favoriteTotalAdded(total: update.total, added: update.added)
    else if (total > 0)
      t.hongguo.favoriteTotal(total: total)
    else
      t.hongguo.favoriteTotalPending,
    if (progress != null) t.hongguo.favoriteWatchedTo(index: progress.episodeIndex),
  ];
  return parts.join(' · ');
}

/// What a poster card prints under its name: the categories, plus the heat or
/// play figure only when [withFigure] asks for it — the cover's foot already
/// carries the heat when its own switch is on, and a card says a figure once.
String hongguoSeriesMetaLine(HongguoSeries series, {required bool withFigure}) {
  final parts = <String>[
    if (withFigure && series.hot.isNotEmpty)
      series.hot
    else if (withFigure && series.playCount > 0)
      AudienceFormat.format(series.playCount),
    if (series.category.isNotEmpty) series.category,
  ];
  return parts.join(' · ');
}

/// One series as a poster card, drawn in the room card's manner: the cover
/// carries a soft scrim with its badges as translucent chips — the board
/// position, the source tags, the episode count, the 今日 marker, the score,
/// the heat along the foot, and where the viewer's own shelf stands on this
/// title — then the title and the listing line, and, on a shelf that asks for
/// it, the local bookmark. Which of the station's pieces appear is the card
/// visibility setting's to say; the viewer's own progress is not one of them,
/// the way it is not on the board's row.
final class HongguoSeriesCard extends ConsumerWidget {
  /// The card for [series]; [onOpen] opens its page. [watched] is the local
  /// shelf's row for the same series, drawn as the first of the cover's marks.
  const HongguoSeriesCard({required this.series, this.onOpen, this.favoritable = false, this.watched, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the card inert.
  final VoidCallback? onOpen;

  /// Whether the card carries the local-shelf bookmark under its title.
  final bool favoritable;

  /// Where this device left the series; null when it never opened it.
  final HongguoWatchProgress? watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final visibility = ref.watch(hongguoCardSettingsProvider);
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
    final rank = series.rank;
    final showsRank = visibility.shows(HongguoCardElement.rank) && rank != null;
    final showsTags = visibility.shows(HongguoCardElement.coverTags) && rank == null && series.coverTags.isNotEmpty;
    final showsEpisodes = visibility.shows(HongguoCardElement.episodes) && series.episodeCount > 0;
    final showsToday = visibility.shows(HongguoCardElement.today) && series.today;
    final showsScore = visibility.shows(HongguoCardElement.score) && series.score.isNotEmpty;
    final showsHot = visibility.shows(HongguoCardElement.hot) && series.hot.isNotEmpty;
    final metaLine = visibility.shows(HongguoCardElement.meta)
        ? hongguoSeriesMetaLine(series, withFigure: !showsHot)
        : '';
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: DsCardStyle(
        padding: EdgeInsets.zero,
        hovered: DsCardStyle(
          background: colors.hover,
          shadows: [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Both of the card's homes bound its height — a poster wall's
            // tile, the shelf's own measure — so the cover takes the height
            // the fixed name block leaves instead of asking for a 3:4 a
            // narrow column cannot pay for.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (series.cover.isEmpty)
                    fallback
                  else
                    DsImage(
                      image: hongguoCoverImage(series.cover),
                      aspectRatio: 3 / 4,
                      semanticLabel: series.title,
                      fallback: fallback,
                    ),
                  // Darkens the cover's edges so the chips keep their contrast
                  // over a bright picture — the room cover's scrim.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  if (showsRank)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
                      child: _RankFlag(rank: rank),
                    )
                  else if (showsTags)
                    // The source's own corner tags (爆剧 / 新剧 / 独播), where
                    // the app stamps them; a ranked card keeps the place for
                    // its flag instead.
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s4,
                        children: [for (final tag in series.coverTags.take(2)) _CoverTag(label: tag)],
                      ),
                    ),
                  // The viewer's own progress leads the cover's marks at its
                  // end: the shelf's state is what decides whether to open a
                  // title again, and the station's chips follow it — the same
                  // order the board's row keeps.
                  if (watched != null || showsEpisodes || showsToday || showsScore)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        spacing: DsSpace.s4,
                        children: [
                          if (watched case final seen?)
                            RoomCoverChip(compact: true, text: hongguoWatchedLabel(t, seen)),
                          if (showsEpisodes)
                            RoomCoverChip(compact: true, text: t.hongguo.allEpisodesCount(count: series.episodeCount)),
                          if (showsToday) DsBadge(label: Text(t.hongguo.todayTag), status: DsStatus.success),
                          if (showsScore)
                            RoomCoverChip(
                              text: series.score,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(
                                  color: const Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (showsHot)
                    PositionedDirectional(
                      bottom: DsSpace.s8,
                      start: DsSpace.s8,
                      end: DsSpace.s8,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: RoomCoverChip(text: series.hot),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: kHongguoSeriesCardInfoExtent,
              child: Padding(
                // The name sits close under the poster and the listing line
                // under it, both on one line — the room card's information
                // area, at its height.
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s3,
                        children: [
                          Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.bodyStrong.copyWith(color: colors.text),
                          ),
                          if (metaLine.isNotEmpty)
                            Text(
                              metaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    if (favoritable) _FavoriteBookmark(series: series),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The station's home opens with one title drawn at head size — the shelf's
/// first pick, its poster at the head's start and its name, where this device
/// stands on it, its intro and the way in at its end — instead of starting
/// mid-row like every shelf under it.
///
/// The head says its figures in words rather than as ink over the poster: the
/// wall's card stamps chips on a cover because it has nowhere else to put
/// them, and this has the column beside it. The poster keeps the station's own
/// 3:4, so a head never crops a picture that was drawn for four thirds of its
/// height, and that width is what sets the head's height.
final class HongguoFeedHero extends StatelessWidget {
  /// The head for [series]; [onOpen] opens its page, [onPlay] puts the picture
  /// on screen, [onSave] keeps it on the device's shelf or takes it off, and
  /// [eyebrow] is the shelf it was read from rather than an invented caption.
  const HongguoFeedHero({
    required this.series,
    required this.eyebrow,
    required this.onOpen,
    required this.onPlay,
    required this.saved,
    required this.onSave,
    this.watched,
    super.key,
  });

  /// The title the shelf puts first.
  final HongguoSeries series;

  /// The shelf this head belongs to, in the app's own words.
  final String eyebrow;

  /// Opens the series' page, as the card under it does.
  final VoidCallback onOpen;

  /// Starts the picture — where this device stopped, when it stopped inside.
  final VoidCallback onPlay;

  /// Whether the series already sits on this device's shelf.
  final bool saved;

  /// Keeps the series, or drops it when it is kept.
  final VoidCallback onSave;

  /// Where this device left the series; null when it never opened it.
  final HongguoWatchProgress? watched;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final line = hongguoSeriesSubtitle(t, series, watched: watched);
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
    // A title this device stopped inside is offered where it stopped, the way
    // the reference separates 继续观看 from 播放.
    final resume = hongguoResumeSeconds(watched) != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = (constraints.maxWidth * .3).clamp(112.0, 180.0);
        return DsCard(
          onPressed: onOpen,
          semanticLabel: series.title,
          style: DsCardStyle(
            padding: EdgeInsets.zero,
            hovered: DsCardStyle(
              background: colors.hover,
              shadows: [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: coverWidth,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: series.cover.isEmpty
                        ? fallback
                        : DsImage(
                            image: hongguoCoverImage(series.cover),
                            aspectRatio: 3 / 4,
                            semanticLabel: series.title,
                            fallback: fallback,
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s4,
                      children: [
                        Text(eyebrow, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
                        Text(
                          series.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                        ),
                        if (line.isNotEmpty)
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                        if (series.intro.isNotEmpty)
                          Text(
                            series.intro,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.s4),
                          child: Wrap(
                            spacing: DsSpace.s8,
                            runSpacing: DsSpace.s8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DsButton(
                                variant: DsButtonVariant.primary,
                                size: DsSize.sm,
                                leading: const DsIcon(DsIcons.play, size: 16),
                                onPressed: onPlay,
                                child: Text(resume ? t.hongguo.continueWatching : t.hongguo.play),
                              ),
                              DsButton(
                                // The same two verbs the series' own head uses,
                                // and the same fill once the title is kept: one
                                // action, one shape, wherever it is offered.
                                variant: saved ? DsButtonVariant.primary : DsButtonVariant.secondary,
                                size: DsSize.sm,
                                leading: DsIcon(saved ? DsIcons.heart : DsIcons.heartOff, size: 16),
                                onPressed: onSave,
                                child: Text(saved ? t.hongguo.favorited : t.hongguo.favorite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The board position on a cover: the top three carry the station's accent.
final class _RankFlag extends StatelessWidget {
  const _RankFlag({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final leading = rank <= 3;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: DsSpace.s3),
      alignment: Alignment.center,
      decoration: DsBoxDecoration(
        color: leading ? colors.accent : const Color(0xB3000000),
        borderRadius: BorderRadius.circular(theme.radii.control(24)),
      ),
      child: Text(
        '$rank',
        style: theme.typography.numeric(
          theme.typography.caption.copyWith(
            color: leading ? colors.onAccent : const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A short label laid over the cover's corner.
final class _CoverTag extends StatelessWidget {
  const _CoverTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: DsSpace.s3),
      decoration: DsBoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(theme.radii.control(22)),
      ),
      child: Text(
        label,
        style: theme.typography.numeric(
          theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF), fontSize: 11),
        ),
      ),
    );
  }
}

/// The card's way onto the local shelf — the bookmark beside its title.
final class _FavoriteBookmark extends ConsumerWidget {
  const _FavoriteBookmark({required this.series});

  final HongguoSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final favored = ref.watch(hongguoLibraryProvider).isFavorite(series.seriesId);
    final label = favored ? t.hongguo.unfavorite : t.hongguo.favorite;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: () {
          final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(series);
          showDsToast(context: context, title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff);
        },
        builder: (context, states, _) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: DsBoxDecoration(
            color: (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.control(28)),
          ),
          child: DsIcon(
            favored ? DsIcons.bookmarkCheck : DsIcons.bookmark,
            size: 14,
            color: favored ? colors.accentText : colors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// One series as a full-width row: the poster beside the title and the
/// listing line — the list layout of the same feed.
final class HongguoSeriesRow extends StatelessWidget {
  /// The row for [series]; [onOpen] opens its page. [totalInHot] tells this
  /// row that [HongguoSeries.hot] already carries the episode total, so the
  /// listing line must not say it a second time. [watched] is the local
  /// shelf's row for the same series, where the listing is one the viewer
  /// browses rather than one read by progress (收藏 and 历史 say it themselves).
  const HongguoSeriesRow({
    required this.series,
    this.onOpen,
    this.trailing,
    this.totalInHot = false,
    this.watched,
    super.key,
  });

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  /// Whether the row's own figure line already names the episode total.
  final bool totalInHot;

  /// Where this device left the series; null when it never opened it.
  final HongguoWatchProgress? watched;

  /// The row's own action, drawn at the row's end — the ✕ that drops the
  /// series from the page showing it, the box that picks it for a batch, the
  /// button that reserves it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 104,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(84)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: series.cover.isEmpty
                    ? fallback
                    : DsImage(
                        image: hongguoCoverImage(series.cover),
                        aspectRatio: 3 / 4,
                        semanticLabel: series.title,
                        fallback: fallback,
                      ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: DsSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  Text(
                    hongguoSeriesSubtitle(context.t, series, totalInHot: totalInHot, watched: watched),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                  if (series.intro.isNotEmpty)
                    Text(
                      series.intro,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One board as the station's app lists it: the place, the poster, the name
/// with its heat, the tags, the blurb and the listing's badges — a
/// full-width row rather than a poster, so the board's readings stay beside
/// each title. The viewer's own progress joins those badges when the library
/// has one, so a hundred-title board can be scanned for what is still unseen.
final class HongguoRankRow extends StatelessWidget {
  /// The row for [series] at [position], used when the listing carries no
  /// place of its own. [watched] is the local shelf's row for the same
  /// series, when there is one.
  const HongguoRankRow({required this.series, this.position = 1, this.watched, this.onOpen, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// The fallback place.
  final int position;

  /// Where this device left the series: the mark says 已看完 or the episode it
  /// stopped at. Null when nothing of it has been watched.
  final HongguoWatchProgress? watched;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final rank = series.rank ?? position;
    final leading = rank <= 3;
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s6));
    // The board's own tags lead, as the station prints them beside the score,
    // and they carry their own tone rather than the score badge's.
    final statusTags = series.coverTags.take(2).toList();
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        hovered: DsCardStyle(background: colors.hover),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: DsSpace.s4),
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: theme.typography.numeric(
                  theme.typography.title.copyWith(
                    color: leading ? colors.accentText : colors.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(72)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: series.cover.isEmpty
                    ? fallback
                    : DsImage(
                        image: hongguoCoverImage(series.cover),
                        aspectRatio: 3 / 4,
                        semanticLabel: series.title,
                        fallback: fallback,
                      ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        series.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    if (series.hot.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s3,
                        children: [
                          DsIcon(DsIcons.flame, size: theme.sizes.iconXs, color: colors.accentText),
                          Text(
                            series.hot,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.accentText),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (series.category.isNotEmpty || series.episodeCount > 0)
                  Text(
                    [
                      if (series.category.isNotEmpty) series.category,
                      if (series.episodeCount > 0) t.hongguo.allEpisodesCount(count: series.episodeCount),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                if (series.favoriteText.isNotEmpty || series.likeText.isNotEmpty)
                  Wrap(
                    spacing: DsSpace.s12,
                    runSpacing: DsSpace.s4,
                    children: [
                      if (series.favoriteText.isNotEmpty) _RankFigure(icon: DsIcons.heart, label: series.favoriteText),
                      if (series.likeText.isNotEmpty) _RankFigure(icon: DsIcons.thumbsUp, label: series.likeText),
                    ],
                  ),
                if (statusTags.isNotEmpty || series.score.isNotEmpty || series.today || watched != null)
                  Wrap(
                    spacing: DsSpace.s4,
                    runSpacing: DsSpace.s4,
                    children: [
                      // The viewer's own state leads the marks: what the board
                      // says about a title matters less here than whether this
                      // device has already opened it.
                      if (watched case final seen?)
                        DsBadge(label: Text(hongguoWatchedLabel(t, seen)), icon: const DsIcon(DsIcons.check)),
                      for (final tag in statusTags) DsBadge(label: Text(tag), status: DsStatus.info),
                      if (series.score.isNotEmpty) DsBadge(label: Text(series.score)),
                      if (series.today) DsBadge(label: Text(t.hongguo.todayTag)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One social figure of a board row: the glyph and the source's own count.
final class _RankFigure extends StatelessWidget {
  const _RankFigure({required this.icon, required this.label});

  final DsIconData icon;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        DsIcon(icon, size: theme.sizes.iconXs, color: colors.textSubtle),
        Text(label, style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted))),
      ],
    );
  }
}

/// One dimension of a shelf's selector panel: the dimension's name over a
/// wrapping row of chips — "全部" first, then the panel's own options. The
/// chips are single-choice; choosing the lit one clears the dimension. The
/// name heads the group rather than sitting beside it, as the station app
/// stacks its filter groups.
final class HongguoFilterRowView extends StatelessWidget {
  /// The row for [row] under [selection]; [onSelect] carries the chosen
  /// option's id, or null for "全部".
  const HongguoFilterRowView({required this.row, required this.selection, required this.onSelect, super.key});

  /// The panel's row.
  final HongguoFilterRow row;

  /// The selection this row's dimension holds.
  final Map<String, String> selection;

  /// Chooses an option of this row's dimension.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final chosen = selection[row.type];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s6,
        children: [
          Text(
            row.rowName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              DsChip(label: Text(t.hongguo.filterAll), selected: chosen == null, onChanged: (_) => onSelect(null)),
              for (final option in row.items)
                DsChip(
                  label: Text(option.name),
                  selected: chosen == option.id,
                  onChanged: (value) => onSelect(value ? option.id : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A thin watched-fraction bar, the reference's history marker.
final class HongguoProgressStripe extends StatelessWidget {
  /// The stripe for [fraction] (0..1).
  const HongguoProgressStripe({required this.fraction, super.key});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: colors.border,
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: fraction.clamp(0.0, 1.0),
          child: ColoredBox(color: colors.accent),
        ),
      ),
    );
  }
}

/// One shelf of the station's home: its name with the way to the whole list
/// beside it, and as many posters as a single row holds. The station's own
/// page is built this way — a row per subject, the rest one click away.
final class HongguoShelf extends ConsumerWidget {
  /// The shelf for [items].
  const HongguoShelf({
    required this.title,
    required this.items,
    required this.cardBuilder,
    this.actions = const <Widget>[],
    this.toolbar = const <Widget>[],
    this.loading = false,
    this.error,
    this.onRetry,
    super.key,
  });

  /// The shelf's name.
  final String title;

  /// The series the row draws, from its head.
  final List<HongguoSeries> items;

  /// Draws one poster.
  final Widget Function(BuildContext context, HongguoSeries series) cardBuilder;

  /// The controls beside the title.
  final List<Widget> actions;

  /// The controls under the title, above the posters — the shelf's own
  /// switches. They wrap instead of squeezing beside the name: the window's
  /// floor is 300 px and a header row of chips cannot hold it.
  final List<Widget> toolbar;

  /// Whether the shelf's own list is being read.
  final bool loading;

  /// The failure to show when nothing loaded.
  final String? error;

  /// Reads the shelf again.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final browse = ref.watch(browseSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Semantics(
          header: true,
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
              ),
              ...actions,
            ],
          ),
        ),
        if (toolbar.isNotEmpty) Wrap(spacing: DsSpace.s8, runSpacing: DsSpace.s8, children: toolbar),
        LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
            if (content <= 0) return const SizedBox.shrink();
            final spacing = browse.crossSpacing;
            final extent = browseCardExtentForWidth(content, crossSpacing: spacing);
            var columns = math.max(1, (content / (extent + spacing)).ceil());
            final ceiling = cappedColumnsForWidth(
              content,
              spacing: spacing,
              ceiling: browse.gridColumns,
              minWidth: kBrowseCardMinWidth,
            );
            if (ceiling > 0 && columns > ceiling) columns = ceiling;
            final cardWidth = columnExtentForWidth(content, columns, spacing) - .01;
            // The shelf's posters take the poster walls' measure, so the same
            // card never draws two shapes; the height is stated because the
            // cover takes whatever the fixed name block leaves it.
            final cardHeight = cardWidth / kHongguoSeriesTileAspect;
            if (error != null && items.isEmpty) {
              return Row(
                spacing: DsSpace.s12,
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  if (onRetry != null)
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      onPressed: onRetry,
                      child: Text(t.common.retry),
                    ),
                ],
              );
            }
            final shown = items.take(columns).toList();
            if (shown.isEmpty) {
              if (!loading) return const SizedBox.shrink();
              return Wrap(
                spacing: spacing,
                children: [
                  for (var row = 0; row < columns; row++)
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: DsSkeleton.block(width: cardWidth, height: cardHeight),
                    ),
                ],
              );
            }
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final series in shown)
                  SizedBox(width: cardWidth, height: cardHeight, child: cardBuilder(context, series)),
              ],
            );
          },
        ),
      ],
    );
  }
}
