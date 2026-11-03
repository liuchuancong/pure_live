import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/features/settings/room/room_card_settings.dart'
    show kRoomCardInfoExtent, kRoomCardListDesignHeight;
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

/// The list layout's row height: the room card's own list measure, which this
/// module's rows keep and the grids that host them hand them. A row built by
/// hand — the shelf's, the board's — lands on it through [kHongguoSeriesRowPosterHeight]
/// rather than by being told, so one change moves every list of titles.
const double kHongguoSeriesRowExtent = kRoomCardListDesignHeight;

/// The poster a list row leads with: as tall as that measure keeps once the
/// row's own s8 band is off, so an intrinsic row is exactly the tile a grid
/// gives it, and the two layouts of one feed cannot disagree by a few pixels.
const double kHongguoSeriesRowPosterHeight = kHongguoSeriesRowExtent - 2 * DsSpace.s8;

/// The widest a poster tile gets: the app's own poster measure — what the area
/// catalogue keeps — rather than the room feed's card width. A 16:9 cover can
/// spend 340 pixels of width because it asks for 191 of height; the station's
/// 0.62 tile asks for 548 at that same width, so a wall measured by the room
/// feed shows one poster the height of a phone screen instead of a wall.
const double kHongguoPosterCardWidth = 176;

/// The narrowest a poster tile may get: the share a row of [kHongguoPosterCardWidth]
/// tiles leaves when the window cannot pay for another whole one. Below it the
/// row takes a column back rather than thinning the posters into slivers.
const double kHongguoPosterMinWidth = 140;

/// Below this tile width the cover stops carrying two sayings: the viewer's own
/// place in the title and the category phrase join the listing line, which says
/// both wherever a row draws the title. At a phone's width the corner's mark,
/// its pill and its heart cannot all fit between the cover's edges — they meet
/// in the middle of the picture — while the station's short markers (今日, its
/// score) still have room to stay on the cover.
const double kHongguoCoverChipFloor = 190;

/// The columns a poster wall of [content] pixels takes: as many tiles of
/// [kHongguoPosterCardWidth] as the row holds, less one when that would thin
/// them past [kHongguoPosterMinWidth], the viewer's [ceiling] lowering the
/// count further when it asks for fewer. 0 — no ceiling — leaves the width to say.
int hongguoPosterColumns(double content, {double spacing = DsSpace.s16, int ceiling = 0}) {
  if (content <= 0) return 1;
  double width(int columns) => (content - spacing * (columns - 1)) / columns;
  var columns = math.max(1, ((content + spacing) / (kHongguoPosterCardWidth + spacing)).ceil());
  if (columns > 1 && width(columns) < kHongguoPosterMinWidth) columns--;
  if (ceiling > 0 && columns > ceiling) columns = ceiling;
  return math.max(1, columns);
}

/// The card width a poster wall of [content] pixels gives itself: one even
/// share of the row at the columns [hongguoPosterColumns] counts — the number
/// a card grid hands its delegate as its own measure.
double hongguoPosterExtentForWidth(double content, {double spacing = DsSpace.s16, int ceiling = 0}) => content <= 0
    ? kHongguoPosterCardWidth
    : columnExtentForWidth(content, hongguoPosterColumns(content, spacing: spacing, ceiling: ceiling), spacing);

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

/// The one listing line a title gets, wherever it is listed: the poster card's
/// line under its name, a list row's, a board row's, the shelf head's and the
/// card menu's hover label. It joins the viewer's own progress — where the
/// shelf knows it — with the episode total, the heat and the category, and the
/// caller says which of those it has already drawn somewhere else.
///
/// [withEpisodeCount] is false where a figure the line would sit beside already
/// names the series' own total — a favorite's 「共 80 集（+3）」 — and on the
/// poster card, whose cover corners carry the reading and whose line is kept to
/// one. Printing the count again in front of the number that is the count says
/// one thing twice in a line, which a line does not do. [withFigure] and
/// [withCategory] are false where the cover's foot holds the heat or the
/// categories chip. [note] is the page's own reading of this title — the clock
/// playback stood on — said once, at the line's end, the way the room card's row
/// ends its meta line with the watch time.
String hongguoSeriesListingLine(
  Translations t,
  HongguoSeries series, {
  bool withEpisodeCount = true,
  HongguoWatchProgress? watched,
  bool withFigure = true,
  bool withCategory = true,
  String? note,
}) {
  final figure = series.hot.isNotEmpty
      ? series.hot
      : series.playCount > 0
      ? '${t.hongguo.plays} ${AudienceFormat.format(series.playCount)}'
      : '';
  final parts = <String>[
    // The viewer's own state leads the line, as it leads the board row's marks.
    if (watched case final seen?) hongguoWatchedLabel(t, seen),
    if (withEpisodeCount && series.episodeCount > 0) t.hongguo.episodesCount(count: series.episodeCount),
    if (withFigure && figure.isNotEmpty) figure,
    if (withCategory && series.category.isNotEmpty) series.category,
    if (note != null && note.isNotEmpty) note,
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

/// One series as a poster card, in the room card's corner structure: the
/// cover carries the scrim with one mark in each corner — the board place or
/// the source's tag at its start, one state pill and the kept heart at its
/// end, the category and the heat along its foot — then the title and the
/// listing line under it. Which of the station's pieces appear is the card
/// visibility setting's to say; the viewer's own progress is not one of them,
/// the way it is not on the board's row.
final class HongguoSeriesCard extends ConsumerWidget {
  /// The card for [series]; [onOpen] opens its page. [watched] is the local
  /// shelf's row for the same series, drawn as the cover's state.
  const HongguoSeriesCard({required this.series, this.onOpen, this.favoritable = false, this.watched, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the card inert.
  final VoidCallback? onOpen;

  /// Whether the card offers the local shelf: the title kept is the red heart
  /// at the cover's end, the way a followed room is.
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
    final firstTag = series.coverTags.isEmpty ? '' : series.coverTags.first;
    // The corner's one mark: the board place where it is drawn and ranked,
    // the source's tag wherever the corner is free — including where the
    // board place is switched off.
    final showsTag = visibility.shows(HongguoCardElement.coverTags) && !showsRank && firstTag.isNotEmpty;
    final showsToday = visibility.shows(HongguoCardElement.today) && series.today;
    final showsScore = visibility.shows(HongguoCardElement.score) && series.score.isNotEmpty;
    final showsEpisodes = visibility.shows(HongguoCardElement.episodes) && series.episodeCount > 0;
    final showsHot = visibility.shows(HongguoCardElement.hot) && series.hot.isNotEmpty;
    final showsCategory = visibility.shows(HongguoCardElement.category) && series.category.isNotEmpty;
    // The corner holds the one state a wall of posters cannot show: where this
    // device stopped, else the newest marker, else the listing's own reading.
    final stateText = watched != null
        ? hongguoWatchedLabel(t, watched!)
        : showsToday
        ? t.hongguo.todayTag
        : showsScore
        ? series.score
        : showsEpisodes
        ? t.hongguo.allEpisodesCount(count: series.episodeCount)
        : null;
    final favored =
        visibility.shows(HongguoCardElement.favorite) &&
        favoritable &&
        ref.watch(hongguoLibraryProvider).isFavorite(series.seriesId);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            // A tile at a phone's width carries one saying per corner, not two:
            // the reading that belongs to the viewer — where this device stopped
            // — joins the listing line, which says it wherever a row draws the
            // title, and the category phrase does the same. What stays on the
            // cover is the board place and the station's heat.
            final wideCover = width >= kHongguoCoverChipFloor;
            final onCoverState = wideCover || watched == null;
            final onCoverCategory = showsCategory && wideCover;
            // The card's own line is the listing line with whatever its corners
            // carry taken out of it, and without the total: the cover's foot and
            // the state pill say the readings, this line says what they left.
            final metaLine = visibility.shows(HongguoCardElement.meta)
                ? hongguoSeriesListingLine(
                    t,
                    series,
                    withEpisodeCount: false,
                    watched: onCoverState ? null : watched,
                    withFigure: !showsHot,
                    withCategory: !onCoverCategory,
                  )
                : '';
            return Column(
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
                      // Darkens the cover's edges so the chips keep their
                      // contrast over a bright picture — the room cover's scrim.
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                        ),
                      ),
                      if (showsRank || showsTag)
                        PositionedDirectional(
                          top: DsSpace.s8,
                          start: DsSpace.s8,
                          // One mark, not a column of them: the board place
                          // where it is drawn and ranked, the source's own tag
                          // wherever the corner is left free.
                          child: _CoverMark(rank: showsRank ? rank : null, label: showsTag ? firstTag : null),
                        ),
                      if ((stateText != null && onCoverState) || favored)
                        PositionedDirectional(
                          top: DsSpace.s8,
                          end: DsSpace.s8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: DsSpace.s6,
                            children: [
                              if (stateText != null && onCoverState)
                                // Half the tile, not six-tenths: the mark holds
                                // the corner this row faces, and at a phone's
                                // width the two readings would otherwise meet
                                // in the middle of the cover.
                                RoomCoverChip(compact: true, text: stateText, maxWidth: width * 0.5),
                              // The heart is the kept state, not an offer: an
                              // unkept title leaves the corner to the state, the
                              // way an unfollowed room leaves it to nothing.
                              if (favored) _FavoriteHeartButton(series: series),
                            ],
                          ),
                        ),
                      if (onCoverCategory || showsHot)
                        PositionedDirectional(
                          start: DsSpace.s8,
                          end: DsSpace.s8,
                          bottom: DsSpace.s8,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // The category holds the corner it starts in and
                              // the figure the opposite one, as the room card
                              // does — the spacer takes what is left over.
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: onCoverCategory
                                      ? RoomCoverChip(text: series.category, maxWidth: width * 0.55)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              if (onCoverCategory && showsHot) const SizedBox(width: DsSpace.s8),
                              if (showsHot)
                                RoomCoverChip(
                                  text: series.hot,
                                  icon: DsIcons.flame,
                                  // The station's heat line is a phrase
                                  // ("1.2万人在看"), not the bare figure the
                                  // room card's corner carries, so it takes
                                  // the wider of the foot's two shares.
                                  maxWidth: width * 0.55,
                                  style: theme.typography.numeric(
                                    theme.typography.caption.copyWith(color: playerInk, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
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
                ),
              ],
            );
          },
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
    final line = hongguoSeriesListingLine(t, series, watched: watched);
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

/// The one mark the cover's top-left corner carries: the board place, or the
/// source's own tag where the listing ranks nothing — at the size the room
/// card's platform mark keeps.
final class _CoverMark extends StatelessWidget {
  const _CoverMark({this.rank, this.label});

  final int? rank;

  /// The source's corner label (爆剧 / 新剧 / 独播); null when [rank] is the mark.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final leading = rank != null && rank! <= 3;
    final text = label ?? '$rank';
    return DsBadge(
      label: Text(text),
      dot: false,
      icon: rank == null ? null : const DsIcon(DsIcons.trophy),
      style: DsBadgeStyle(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
        background: leading ? colors.accent : const Color(0xB3000000),
        foreground: leading ? colors.onAccent : playerInk,
        borderRadius: BorderRadius.circular(8),
        textStyle: theme.typography.labelStrong,
        iconSize: 14,
        gap: DsSpace.s6,
      ),
    );
  }
}

/// The card's kept state at the cover's corner: the red heart the room card's
/// follow button is, and the press takes the title off the shelf.
final class _FavoriteHeartButton extends ConsumerWidget {
  const _FavoriteHeartButton({required this.series});

  final HongguoSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsButton.icon(
      onPressed: () {
        final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(series);
        showDsToast(context: context, title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff);
      },
      semanticLabel: t.hongguo.unfavorite,
      size: DsSize.xs,
      variant: DsButtonVariant.ghost,
      icon: const DsIcon(DsIcons.heart),
      style: DsButtonStyle(
        height: 28,
        padding: EdgeInsets.zero,
        background: const Color(0x00000000),
        foreground: DsTheme.colorsOf(context).danger.fill,
        borderWidth: 0,
        borderRadius: BorderRadius.circular(DsRadii.pill),
        iconSize: 14,
        shadows: const [],
        hovered: const DsButtonStyle(background: Color(0x00000000)),
        pressed: const DsButtonStyle(background: Color(0x00000000)),
      ),
    );
  }
}

/// The poster both list rows lead with: the series' own picture at the row's
/// measure, read through [hongguoCoverImage] like every other face of it — the
/// station's covers are HEIC behind a path-bound URL, and a row that asked for
/// the bare link would show a blank.
final class _RowPoster extends StatelessWidget {
  const _RowPoster({required this.series});

  final HongguoSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    const width = kHongguoSeriesRowPosterHeight * 3 / 4;
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s4));
    return SizedBox(
      height: kHongguoSeriesRowPosterHeight,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.control(width)),
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
    );
  }
}

/// One series as the list layout's row: the poster at the row's measure, then
/// the title and the listing line beside it — the same two lines, and the same
/// words, as [HongguoSeriesCard] — with the listing's own synopsis on a third
/// line under them. The row is that card with its cover taken down to a poster
/// and its corners folded into the listing line; the poster's fixed height never
/// had room for the synopsis, so only the row reads it, the way only the room
/// card's row reads a room's follow tags.
///
/// The row is the other shape of the same feed — a wall and its rows are one
/// listing seen through [PagedCardGrid]'s layout switch — so the card's
/// 「信息行」 switch closes this line as it closes the card's, and the pieces the
/// row folds into it stay folded: the switches that choose a cover corner have
/// no corner to choose here.
final class HongguoSeriesRow extends ConsumerWidget {
  /// The row for [series]; [onOpen] opens its page. [withEpisodeCount] is false
  /// where the row's own figure line already names the series' total, so the
  /// listing line must not say it a second time. [watched] is the local shelf's
  /// row for the same series, where the listing is one the viewer browses rather
  /// than one read by progress (收藏 and 历史 say it themselves). [note] is this
  /// page's own reading of the title — the history's clock — said once at the
  /// listing line's end.
  const HongguoSeriesRow({
    required this.series,
    this.onOpen,
    this.trailing,
    this.withEpisodeCount = true,
    this.watched,
    this.note,
    super.key,
  });

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  /// Whether the row's own figure line already names the episode total.
  final bool withEpisodeCount;

  /// Where this device left the series; null when it never opened it.
  final HongguoWatchProgress? watched;

  /// The page's own reading, at the listing line's end; null when it has none.
  final String? note;

  /// The row's own action, drawn at the row's end — the ✕ that drops the
  /// series from the page showing it, the box that picks it for a batch, the
  /// button that reserves it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final line = ref.watch(hongguoCardSettingsProvider).shows(HongguoCardElement.meta)
        ? hongguoSeriesListingLine(context.t, series, withEpisodeCount: withEpisodeCount, watched: watched, note: note)
        : '';
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              _RowPoster(series: series),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(color: colors.text),
                    ),
                    if (line.isNotEmpty)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    // The row's own third line, the way the room card's row
                    // keeps a line for the follow tags: the listing's synopsis,
                    // which a poster's fixed height never had room for.
                    if (series.intro.isNotEmpty)
                      Text(
                        series.intro,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// One board title as the station's app lists it: the place, the poster, the
/// name with its heat beside it, then the listing line the poster card and the
/// list row use, and under it the board's own marks — the tags, the score, the
/// newest marker and the social figures. The board reads as rows because a
/// hundred titles have to be scanned, not admired; its lines, its measure and
/// its words are [HongguoSeriesRow]'s, so one feed in either layout is one
/// design.
final class HongguoRankRow extends ConsumerWidget {
  /// The row for [series] at [position], used when the listing carries no
  /// place of its own. [watched] is the local shelf's row for the same
  /// series, when there is one: it joins the listing line, not the marks.
  const HongguoRankRow({required this.series, this.position = 1, this.watched, this.onOpen, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// The fallback place.
  final int position;

  /// Where this device left the series: the line says 已看完 or the episode it
  /// stopped at. Null when nothing of it has been watched.
  final HongguoWatchProgress? watched;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final rank = series.rank ?? position;
    final leading = rank <= 3;
    // The heat keeps the place the board gives it — beside the name — so the
    // listing line is built without the figure it would print a second time.
    // That line is the card's 「信息行」 switch's; the board's own marks — its
    // place, its tags, its score — are the page's subject, not a cover corner.
    final listing = ref.watch(hongguoCardSettingsProvider).shows(HongguoCardElement.meta)
        ? hongguoSeriesListingLine(t, series, watched: watched, withFigure: false)
        : '';
    final marks = <Widget>[
      if (series.favoriteText.isNotEmpty) _RankFigure(icon: DsIcons.heart, label: series.favoriteText),
      if (series.likeText.isNotEmpty) _RankFigure(icon: DsIcons.thumbsUp, label: series.likeText),
      // The station's own tags lead the marks, as the board prints them beside
      // the score, and carry their own tone rather than the score badge's.
      for (final tag in series.coverTags.take(2)) DsBadge(label: Text(tag), status: DsStatus.info),
      if (series.score.isNotEmpty) DsBadge(label: Text(series.score)),
      if (series.today) DsBadge(label: Text(t.hongguo.todayTag)),
    ];
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              SizedBox(
                width: 36,
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
              _RowPoster(series: series),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(
                          child: Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.bodyStrong.copyWith(color: colors.text),
                          ),
                        ),
                        if (series.hot.isNotEmpty)
                          _RankFigure(icon: DsIcons.flame, label: series.hot, color: colors.accentText),
                      ],
                    ),
                    if (listing.isNotEmpty)
                      Text(
                        listing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    if (marks.isNotEmpty) Wrap(spacing: DsSpace.s8, runSpacing: DsSpace.s4, children: marks),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One figure of a board row: the glyph and the source's own count.
final class _RankFigure extends StatelessWidget {
  /// The figure for [label]; [color] is the caller's when the row reads the
  /// number in its own tone — the board's heat, which the poster card stamps
  /// on its cover.
  const _RankFigure({required this.icon, required this.label, this.color});

  final DsIconData icon;

  final String label;

  /// The row's own tone for the figure; null keeps the muted ink of a count.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        DsIcon(icon, size: theme.sizes.iconXs, color: color ?? colors.textSubtle),
        Text(
          label,
          style: theme.typography.numeric(theme.typography.caption.copyWith(color: color ?? colors.textMuted)),
        ),
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

/// The one control a narrow shelf bar keeps after its tabs: the page's own
/// actions — the condition entry and the reload a wide row draws as named
/// buttons — folded into a menu at the row's end, the way the live feeds fold
/// their layout switch and platform wall. A page that has nothing to fold
/// draws its tabs alone rather than a button that opens an empty menu.
final class HongguoToolbarMore extends StatelessWidget {
  const HongguoToolbarMore({required this.items, super.key});

  /// The page's actions, in the order they stand at the wide row's end.
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsMenuAnchor(
      semanticLabel: t.common.more,
      align: DsAlign.end,
      items: items,
      builder: (context, controller, _) => DsButton.icon(
        variant: DsButtonVariant.ghost,
        size: DsSize.sm,
        semanticLabel: t.common.more,
        onPressed: controller.open,
        icon: const DsIcon(DsIcons.ellipsisVertical),
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
            final columns = hongguoPosterColumns(content, spacing: spacing, ceiling: browse.gridColumns);
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
