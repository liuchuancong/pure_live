import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart' show hongguoLibraryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoEpisode, HongguoSeriesDetail;

/// The episodes one group of the shelf lists before the pager takes over —
/// the reference's twenty.
const int kHongguoEpisodeGroup = 20;

/// The series' numbered episode tiles: [kHongguoEpisodeGroup] at a time with a
/// jump box, the episode being watched lit, the last one watched marked and
/// the ones behind it checked. [onOpen] runs when the viewer picks another.
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
  int _groupOf(HongguoEpisode? episode) {
    if (episode == null) return 0;
    final episodes = widget.detail.episodes;
    final position = episodes.indexWhere((row) => row.vid == episode.vid);
    return position < 0 ? 0 : position ~/ kHongguoEpisodeGroup;
  }

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
    final progress = ref.watch(hongguoLibraryProvider).progressOf(widget.detail.meta.seriesId);
    final watchedThrough = progress == null
        ? 0
        : progress.completed
        ? progress.episodeIndex
        : progress.episodeIndex - 1;
    bool isCurrent(HongguoEpisode episode) => episode.vid == current?.vid && episode.index == current?.index;
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(t.hongguo.episodes, style: theme.typography.title.copyWith(color: colors.text)),
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
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            for (final episode in shown)
              DsChip(
                leading: isCurrent(episode)
                    ? null
                    : episode.index == progress?.episodeIndex && !(progress?.completed ?? false)
                    ? const DsIcon(DsIcons.play, size: 12)
                    : episode.index <= watchedThrough
                    ? const DsIcon(DsIcons.check, size: 12)
                    : null,
                label: Text('${episode.index}'),
                selected: isCurrent(episode),
                onChanged: isCurrent(episode) ? null : (_) => widget.onOpen(episode),
                semanticLabel: t.hongguo.episodeLabel(index: episode.index),
              ),
          ],
        ),
      ],
    );
  }
}
