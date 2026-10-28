import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
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

/// One series as a poster card: the cover with its badges — the board
/// position, the 今日 marker, the score — the title, and the listing line.
final class HongguoSeriesCard extends StatelessWidget {
  /// The card for [series]; [onOpen] opens its page.
  const HongguoSeriesCard({required this.series, this.onOpen, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
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
        spacing: DsSpace.s6,
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
                    DsImage(image: cachedImage(series.cover), aspectRatio: 3 / 4, semanticLabel: series.title, fallback: fallback),
                  if (series.rank != null)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                        decoration: DsBoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(theme.radii.control(22)),
                        ),
                        child: Text(
                          '${series.rank}',
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(color: colors.onAccent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  if (series.today)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      end: DsSpace.s6,
                      child: DsBadge(label: Text(context.t.hongguo.todayTag), status: DsStatus.success),
                    ),
                  if (series.score.isNotEmpty)
                    PositionedDirectional(
                      bottom: DsSpace.s6,
                      end: DsSpace.s6,
                      child: DsBadge(label: Text(series.score), dot: false),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
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
              ],
            ),
          ),
          const SizedBox(height: DsSpace.s6),
        ],
      ),
    );
  }
}

/// One series as a full-width row: the poster beside the title and the
/// listing line — the list layout of the same feed.
final class HongguoSeriesRow extends StatelessWidget {
  /// The row for [series]; [onOpen] opens its page.
  const HongguoSeriesRow({required this.series, this.onOpen, super.key});

  /// The series shown.
  final HongguoSeries series;

  /// Opens the series; null leaves the row inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final fallback = CoverFallback(title: series.title, padding: const EdgeInsets.all(DsSpace.s8));
    return DsCard(
      onPressed: onOpen,
      semanticLabel: series.title,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s8),),
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
                    : DsImage(image: cachedImage(series.cover), aspectRatio: 3 / 4, semanticLabel: series.title, fallback: fallback),
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

/// One dimension of a shelf's selector panel: the dimension's name beside a
/// wrapping row of chips — "全部" first, then the panel's own options. The
/// chips are single-choice; choosing the lit one clears the dimension.
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
    final t = context.t;
    final chosen = selection[row.type];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: DsSpace.s6),
              child: Text(
                row.rowName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
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
          ),
        ],
      ),
    );
  }
}
