import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
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

/// One series' subtitle line: the episode count, the play figure and the
/// shelf categories, whichever the listing carries.
String hongguoSeriesSubtitle(Translations t, HongguoSeries series) {
  final parts = <String>[
    if (series.episodeCount > 0) t.hongguo.episodesCount(count: series.episodeCount),
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

/// What a poster card prints under its name: the heat or play figure, then
/// the categories — the station's browse cards, without the episode count
/// the cover's own corner already carries.
String hongguoSeriesMetaLine(HongguoSeries series) {
  final parts = <String>[
    if (series.hot.isNotEmpty) series.hot else if (series.playCount > 0) AudienceFormat.format(series.playCount),
    if (series.category.isNotEmpty) series.category,
  ];
  return parts.join(' · ');
}

/// One series as a poster card: the cover with its badges — the board
/// position, the episode count, the heat, the 今日 marker — the title, the
/// listing line and, on a shelf that asks for it, the local bookmark.
final class HongguoSeriesCard extends StatelessWidget {
  /// The card for [series]; [onOpen] opens its page.
  const HongguoSeriesCard({required this.series, this.onOpen, this.favoritable = false, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the card inert.
  final VoidCallback? onOpen;

  /// Whether the card carries the local-shelf bookmark under its title.
  final bool favoritable;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
    final rank = series.rank;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
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
                  // The heat sits on the picture's own foot, where the
                  // listing puts it; a bare chip there would hide the art.
                  if (series.hot.isNotEmpty)
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      height: 34,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.bottomCenter,
                            end: AlignmentDirectional.topCenter,
                            colors: [Color(0xB3000000), Color(0x00000000)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, 0, DsSpace.s8, DsSpace.s5),
                          child: Text(
                            series.hot,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (rank != null)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: _RankFlag(rank: rank),
                    )
                  else if (series.coverTags.isNotEmpty)
                    // The source's own corner tags (爆剧 / 新剧 / 独播), where
                    // the app stamps them; a ranked card keeps the place for
                    // its flag instead.
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s4,
                        children: [for (final tag in series.coverTags.take(2)) _CoverTag(label: tag)],
                      ),
                    ),
                  PositionedDirectional(
                    top: DsSpace.s6,
                    end: DsSpace.s6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: DsSpace.s4,
                      children: [
                        if (series.episodeCount > 0)
                          _CoverTag(label: t.hongguo.allEpisodesCount(count: series.episodeCount)),
                        if (series.today) DsBadge(label: Text(t.hongguo.todayTag), status: DsStatus.success),
                        if (series.score.isNotEmpty) DsBadge(label: Text(series.score), dot: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s6, DsSpace.s6, DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Expanded(
                      child: Text(
                        series.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    if (favoritable) _FavoriteBookmark(series: series),
                  ],
                ),
                Text(
                  hongguoSeriesMetaLine(series),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final label = favored ? t.hongguo.favoriteToggleOff : t.hongguo.favoriteToggleOn;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: () {
          final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(series);
          showDsToast(context: context, title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff);
        },
        builder: (context, states, _) => Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: DsBoxDecoration(
            color: states.contains(WidgetState.hovered) ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.control(30)),
          ),
          child: DsIcon(
            favored ? DsIcons.bookmarkCheck : DsIcons.bookmark,
            size: 16,
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
  /// The row for [series]; [onOpen] opens its page.
  const HongguoSeriesRow({required this.series, this.onOpen, this.trailing, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  /// A trailing action, beside the listing line.
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
                    hongguoSeriesSubtitle(context.t, series),
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
        ],
      ),
    );
  }
}

/// One board as the station's app lists it: the place, the poster, the name
/// with its heat, the tags, the blurb and the listing's badges — a
/// full-width row rather than a poster, so the board's readings stay beside
/// each title.
final class HongguoRankRow extends StatelessWidget {
  /// The row for [series] at [position], used when the listing carries no
  /// place of its own.
  const HongguoRankRow({required this.series, this.position = 1, this.onOpen, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// The fallback place.
  final int position;

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
    final badges = [
      if (series.score.isNotEmpty) series.score,
      if (series.today) t.hongguo.todayTag,
      ...series.coverTags.take(2),
    ];
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
                if (series.category.isNotEmpty)
                  Text(
                    series.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                // The board's social figures sit beside the heat it prints at
                // the title's end, as the station's own row lays them out.
                if (series.favoriteText.isNotEmpty || series.likeText.isNotEmpty)
                  Wrap(
                    spacing: DsSpace.s12,
                    runSpacing: DsSpace.s4,
                    children: [
                      if (series.favoriteText.isNotEmpty) _RankFigure(icon: DsIcons.heart, label: series.favoriteText),
                      if (series.likeText.isNotEmpty) _RankFigure(icon: DsIcons.thumbsUp, label: series.likeText),
                    ],
                  ),
                if (series.intro.isNotEmpty)
                  Text(
                    series.intro,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                if (badges.isNotEmpty)
                  Wrap(
                    spacing: DsSpace.s4,
                    runSpacing: DsSpace.s4,
                    children: [for (final badge in badges) DsBadge(label: Text(badge))],
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
                      child: DsSkeleton.block(width: cardWidth, height: cardWidth * 4 / 3),
                    ),
                ],
              );
            }
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [for (final series in shown) SizedBox(width: cardWidth, child: cardBuilder(context, series))],
            );
          },
        ),
      ],
    );
  }
}
