import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_covers.dart' show hongguoCoverImage;
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart' show HongguoWatchProgress;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoEpisode, HongguoSeriesDetail;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// The episodes one group of the shelf lists before the pager takes over —
/// the reference's twenty.
const int kHongguoEpisodeGroup = 20;

/// The widest an episode's cover card gets: what a pane pays for one before
/// the grid would rather take another column than stretch the picture — the
/// station's own episode frames read a little over a phone's width, never
/// the whole reading column.
const double kHongguoEpisodeCardWidth = 280;

/// The most columns the episode grid draws: the design's four — a catalogue
/// of covers, not a wall that runs to the window's edge.
const int kHongguoEpisodeGridMaxColumns = 4;

/// The columns the episode grid takes in a pane [width] pixels wide, at
/// [spacing] between them: as many cards of [kHongguoEpisodeCardWidth] as
/// the pane holds, at most [kHongguoEpisodeGridMaxColumns] — and below the
/// app's compact width exactly two, the design's phone frame, where the
/// 16:9 covers want a neighbour to read as a catalogue rather than one
/// stretched banner.
int hongguoEpisodeColumns(double width, {double spacing = DsSpace.s8}) {
  if (width <= 0) return 1;
  if (width < LiveWindow.compact) return 2;
  final columns = ((width + spacing) / (kHongguoEpisodeCardWidth + spacing)).floor();
  return math.min(math.max(1, columns), kHongguoEpisodeGridMaxColumns);
}

/// How far the viewer has got, as every surface that lists the series'
/// episodes reads it: `watchedThrough` is the last one finished — it and
/// everything behind it take the tick — and `resumeAt` is the one stopped
/// part-way, the only one that gets the play glyph. The immersive catalogue
/// over the picture runs this one reading, and the shelf's own lit card
/// names the same episode, so the two can never disagree about what has
/// been watched.
({int watchedThrough, int? resumeAt}) hongguoEpisodeMarks(HongguoWatchProgress? progress) => (
  watchedThrough: switch (progress) {
    null => 0,
    final row when row.completed => row.episodeIndex,
    final row => row.episodeIndex - 1,
  },
  resumeAt: progress == null || progress.completed ? null : progress.episodeIndex,
);

/// The tile group [episode] sits in, by its place in the loaded list rather
/// than its number — a series can open mid-list, and the pages are of the
/// list, not of the numbering.
int hongguoEpisodeGroupOf(List<HongguoEpisode> episodes, HongguoEpisode? episode) {
  if (episode == null) return 0;
  final position = episodes.indexWhere((row) => row.vid == episode.vid);
  return position < 0 ? 0 : position ~/ kHongguoEpisodeGroup;
}

/// The series' episodes as the design's cover cards — a 16:9 frame to an
/// episode, the number over the picture's start, the length over its end and
/// the episode's own name under it — [kHongguoEpisodeGroup] at a time with a
/// jump box. The episode being watched stands lit at its number and its name
/// and gives up its press; the rest of the cards open the player.
/// [onOpen] runs when the viewer picks another.
final class HongguoEpisodeShelf extends ConsumerStatefulWidget {
  /// The shelf for the series' own episodes.
  const HongguoEpisodeShelf({required this.detail, required this.onOpen, this.current, super.key});

  /// The series whose episodes are listed.
  final HongguoSeriesDetail detail;

  /// The episode the viewer is on, when one is.
  final HongguoEpisode? current;

  /// Runs when the viewer picks an episode.
  final void Function(HongguoEpisode episode) onOpen;

  @override
  ConsumerState<HongguoEpisodeShelf> createState() => _HongguoEpisodeShelfState();
}

final class _HongguoEpisodeShelfState extends ConsumerState<HongguoEpisodeShelf> {
  int _group = 0;

  @override
  void initState() {
    super.initState();
    _group = _groupOf(widget.current);
  }

  @override
  void didUpdateWidget(HongguoEpisodeShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.detail, widget.detail) || oldWidget.current?.vid != widget.current?.vid) {
      _group = _groupOf(widget.current);
    }
  }

  /// The group [episode] sits in, by its place in the loaded list.
  int _groupOf(HongguoEpisode? episode) => hongguoEpisodeGroupOf(widget.detail.episodes, episode);

  /// Asks for an episode number and opens it; an empty or unknown answer
  /// leaves the shelf where it was.
  void _jump() => unawaited(_jumpToEpisode());

  Future<void> _jumpToEpisode() async {
    final episodes = widget.detail.episodes;
    if (episodes.isEmpty) return;
    final controller = TextEditingController();
    int? parse() {
      final typed = int.tryParse(controller.text.trim());
      if (typed == null) return null;
      final byIndex = episodes.where((episode) => episode.index == typed);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return typed >= 1 && typed <= episodes.length ? typed - 1 : null;
    }

    final position = await showDsDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return DsDialog(
          title: Text(t.hongguo.episodesJump),
          description: DsTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: '1–${episodes.length}',
            onSubmitted: (_) => Navigator.of(dialogContext).pop(parse()),
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            DsButton(onPressed: () => Navigator.of(dialogContext).pop(parse()), child: Text(t.common.confirm)),
          ],
        );
      },
    );
    controller.dispose();
    if (position == null || !mounted) return;
    widget.onOpen(episodes[position]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = widget.current;
    final episodes = widget.detail.episodes;
    final groups = (episodes.length + kHongguoEpisodeGroup - 1) ~/ kHongguoEpisodeGroup;
    final group = _group.clamp(0, groups <= 0 ? 0 : groups - 1);
    final first = group * kHongguoEpisodeGroup;
    final shown = episodes.skip(first).take(kHongguoEpisodeGroup).toList();
    final last = first + shown.length;
    bool isCurrent(HongguoEpisode episode) => episode.vid == current?.vid && episode.index == current?.index;
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            // The total rides the title as the season page's does — a series
            // that fits one page otherwise never says how many it holds.
            Expanded(
              child: Text(
                '${t.hongguo.episodes} · ${episodes.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            if (groups > 1) ...[
              Text('$first–$last / ${episodes.length}', style: muted),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronLeft),
                semanticLabel: t.hongguo.episodesPrevious,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group > 0 ? () => setState(() => _group = group - 1) : null,
              ),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronRight),
                semanticLabel: t.hongguo.episodesNext,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group < groups - 1 ? () => setState(() => _group = group + 1) : null,
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.listOrdered, size: 16),
                onPressed: _jump,
                child: Text(t.hongguo.episodesJump),
              ),
            ],
          ],
        ),
        // The columns come from the pane this shelf lands in — the series
        // page's reading column, the player's own panel — so the same widget
        // lays a phone's pair and a desktop's four out of one reading. The
        // cards stand in a shrink-wrap row set, the page's scroll carrying
        // them, because a group of the shelf is a block of the page, not a
        // feed of its own.
        LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
            final spacing = ref.watch(browseSettingsProvider).crossSpacing;
            final columns = hongguoEpisodeColumns(content, spacing: spacing);
            final cardWidth = content > 0
                ? columnExtentForWidth(content, columns, spacing) - .01
                : kHongguoEpisodeCardWidth;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final episode in shown)
                  SizedBox(
                    width: cardWidth,
                    child: _HongguoEpisodeCard(
                      episode: episode,
                      current: isCurrent(episode),
                      onOpen: isCurrent(episode) ? null : () => widget.onOpen(episode),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One episode as the design's cover card: the picture at the cards' 16:9,
/// the episode's number over its start — lit on the one being watched, the
/// station's dark mark on the rest — the length over its end, and the
/// episode's own name on one line under the picture. The whole card is the
/// way into the episode; the watched one keeps its place and gives up the
/// press, the way the numbered chip it grew out of did.
final class _HongguoEpisodeCard extends StatelessWidget {
  const _HongguoEpisodeCard({required this.episode, required this.current, required this.onOpen});

  final HongguoEpisode episode;

  /// Whether this is the episode the viewer is on: its number reads in the
  /// accent and the card does not press.
  final bool current;

  /// Opens the episode; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final label = t.hongguo.episodeLabel(index: episode.index);
    // The station's own episode cards carry the episode's name where it has
    // one and the number where it has not — the words the player's catalogue
    // and the card menu read for the same episode.
    final name = episode.title.isNotEmpty ? episode.title : label;
    final fallback = CoverFallback(title: name, padding: const EdgeInsets.all(DsSpace.s8));
    return DsCard(
      onPressed: onOpen,
      semanticLabel: label,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s6,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (episode.cover.isEmpty)
                    fallback
                  else
                    DsImage(
                      image: hongguoCoverImage(episode.cover),
                      aspectRatio: 16 / 9,
                      semanticLabel: label,
                      fallback: fallback,
                    ),
                  // Darkens the picture's edges so the two marks keep their
                  // contrast over a bright frame — the room cover's scrim.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  PositionedDirectional(
                    top: DsSpace.s8,
                    start: DsSpace.s8,
                    child: current
                        ? DsBadge(
                            label: Text(t.hongguo.episodeNo(index: episode.index)),
                            dot: false,
                            style: DsBadgeStyle(
                              height: 22,
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
                              background: colors.accent,
                              foreground: colors.onAccent,
                              borderRadius: BorderRadius.circular(6),
                              textStyle: theme.typography.labelStrong,
                            ),
                          )
                        : RoomCoverChip(text: t.hongguo.episodeNo(index: episode.index), compact: true),
                  ),
                  if (episode.durationSeconds > 0)
                    PositionedDirectional(
                      bottom: DsSpace.s8,
                      end: DsSpace.s8,
                      child: RoomCoverChip(
                        text: hongguoDurationText(Duration(seconds: episode.durationSeconds)),
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, 0, DsSpace.s8, DsSpace.s6),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  color: current ? colors.accentText : colors.textSubtle,
                  fontWeight: current ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
