import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart'
    show HongguoWatchProgress, hongguoLibraryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoEpisode, HongguoSeriesDetail;
import 'package:pure_live/shared/shared.dart';

/// The episodes one group of the shelf lists before the pager takes over —
/// the reference's twenty.
const int kHongguoEpisodeGroup = 20;

/// How far the viewer has got, as every surface that lists the series'
/// episodes reads it: `watchedThrough` is the last one finished — it and
/// everything behind it take the tick — and `resumeAt` is the one stopped
/// part-way, the only one that gets the play glyph. The immersive catalogue
/// over the picture runs this one reading, and the shelf's own lit chip
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

/// One page of the series, named by the episode numbers it holds — `1–20`,
/// and the short last one `81–102`.
String hongguoEpisodeRangeLabel(List<HongguoEpisode> episodes, int group) {
  final first = group * kHongguoEpisodeGroup;
  return '${first + 1}–${first + (episodes.length - first).clamp(0, kHongguoEpisodeGroup)}';
}

/// The series' episodes as the stations' own selection reads: one row of
/// range tabs — `1–20`, `21–40` — and under it the group's numbers as
/// chips, the number the only thing on them. No frames: a short drama's
/// episodes share one cover, so a catalogue of the same picture a hundred
/// times says nothing the numbers do not. The chip being watched stands
/// filled in the accent, the finished ones carry the tick, the one stopped
/// part-way the play glyph, and every chip opens its episode.
/// [onOpen] runs when the viewer picks one.
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

  /// One key per range tab, so the row can bring the selected range into
  /// view when the episode moves under it: a series autoplaying through its
  /// pages must not leave the selected tab scrolled out of sight.
  final Map<int, GlobalKey> _tabKeys = <int, GlobalKey>{};

  /// Whether the selected tab still owes its reveal; set when the group
  /// moves under the shelf rather than under the viewer's own press.
  bool _revealTabs = false;

  @override
  void initState() {
    super.initState();
    _group = _groupOf(widget.current);
    _revealTabs = true;
  }

  @override
  void didUpdateWidget(HongguoEpisodeShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.detail, widget.detail) || oldWidget.current?.vid != widget.current?.vid) {
      final group = _groupOf(widget.current);
      if (group != _group) _revealTabs = true;
      _group = group;
    }
  }

  /// The group [episode] sits in, by its place in the loaded list.
  int _groupOf(HongguoEpisode? episode) => hongguoEpisodeGroupOf(widget.detail.episodes, episode);

  /// Asks for an episode number and opens it; an empty or unknown answer
  /// leaves the shelf where it was.
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

    final position = await showAppDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return AppDialog(
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
    final current = widget.current;
    final episodes = widget.detail.episodes;
    final groups = (episodes.length + kHongguoEpisodeGroup - 1) ~/ kHongguoEpisodeGroup;
    final group = _group.clamp(0, groups <= 0 ? 0 : groups - 1);
    final shown = episodes.skip(group * kHongguoEpisodeGroup).take(kHongguoEpisodeGroup).toList();
    // The watch marks come off the local library, the same reading the
    // player's own catalogue runs, so shelf and catalogue never disagree
    // about what has been seen.
    final marks = hongguoEpisodeMarks(ref.watch(hongguoLibraryProvider).progressOf(widget.detail.meta.seriesId));
    bool isCurrent(HongguoEpisode episode) => episode.vid == current?.vid && episode.index == current?.index;
    // The selected tab's reveal, once the tabs are on stage: the row walks
    // the range in — centred when it can be — and the debt is cleared, so a
    // plain rebuild never scrolls the row again.
    if (_revealTabs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tabContext = _tabKeys[group]?.currentContext;
        if (tabContext != null) {
          Scrollable.ensureVisible(
            tabContext,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        }
      });
      _revealTabs = false;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SectionHeader(title: t.hongguo.episodes, count: episodes.length, trailing: [_jumpButton()]),
        // The ranges as the page's own tabs, one per group: the selected one
        // carries the accent, the rest stay quiet. A hundred-plus-episode
        // series walks them sideways.
        if (groups > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: DsSpace.s6,
              children: [
                for (var index = 0; index < groups; index++)
                  _RangeTab(
                    key: _tabKeys.putIfAbsent(index, GlobalKey.new),
                    label: hongguoEpisodeRangeLabel(episodes, index),
                    selected: index == group,
                    onPressed: () => setState(() => _group = index),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: DsSpace.s6,
          runSpacing: DsSpace.s6,
          children: [
            for (final episode in shown)
              _EpisodeChip(
                episode: episode,
                playing: isCurrent(episode),
                marks: marks,
                onOpen: isCurrent(episode) ? null : () => widget.onOpen(episode),
              ),
          ],
        ),
      ],
    );
  }

  Widget _jumpButton() {
    final t = context.t;
    return DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      leading: const DsIcon(DsIcons.listOrdered, size: 16),
      onPressed: widget.detail.episodes.isEmpty ? null : () => unawaited(_jumpToEpisode()),
      child: Text(t.hongguo.episodesJump),
    );
  }
}

/// One range of the selection: `1–20` on a quiet pill, the group on stage
/// filled and accented.
final class _RangeTab extends StatelessWidget {
  const _RangeTab({required this.label, required this.selected, required this.onPressed, super.key});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          height: theme.sizes.xs,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8),
          alignment: AlignmentDirectional.center,
          decoration: DsBoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.14)
                : hovered
                ? colors.hover
                : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.xs),
          ),
          child: Text(
            label,
            style: theme.typography.numeric(
              theme.typography.caption.copyWith(
                color: selected ? colors.accentText : colors.textMuted,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One number of the selection: the episode's index on a small tile — filled
/// in the accent while it plays, ticked once finished, the play glyph where
/// the viewer stopped part-way. The episode's own name, where the source
/// gives one, rides in the semantics rather than on the tile: the number is
/// what the grid reads.
final class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({required this.episode, required this.playing, required this.marks, required this.onOpen});

  final HongguoEpisode episode;

  /// Whether this is the episode on air: filled, and inert.
  final bool playing;

  /// How far the viewer has got through the series.
  final ({int watchedThrough, int? resumeAt}) marks;

  /// Opens the episode; null leaves the chip inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final label = t.hongguo.episodeLabel(index: episode.index);
    final height = theme.sizes.xs < 28.0 ? 28.0 : theme.sizes.xs;
    return DsPressable(
      semanticLabel: episode.title.isEmpty ? label : '$label ${episode.title}',
      onPressed: onOpen,
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        final resume = !playing && episode.index == marks.resumeAt;
        final watched = !playing && !resume && episode.index <= marks.watchedThrough;
        final ink = playing
            ? colors.onAccent
            : watched
            ? colors.textSubtle
            : colors.textMuted;
        return Container(
          height: height,
          constraints: BoxConstraints(minWidth: height + 20),
          alignment: AlignmentDirectional.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
          decoration: DsBoxDecoration(
            color: playing
                ? colors.accent
                : lit
                ? colors.hover
                : colors.control,
            borderRadius: theme.radii.controlCorners(null, height),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              if (resume)
                DsIcon(DsIcons.play, size: 10, color: ink)
              else if (watched)
                DsIcon(DsIcons.check, size: 10, color: ink),
              Text(
                '${episode.index}',
                style: theme.typography.numeric(
                  theme.typography.caption.copyWith(
                    color: playing ? ink : (watched ? colors.textSubtle : colors.text),
                    fontWeight: playing ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
