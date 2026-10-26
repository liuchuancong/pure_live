import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';

import 'package:pure_live/features/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/l10n/translations.dart';

/// Opens the channel's guide: one day of programmes, the one on air marked
/// with its progress, the past ones replayable where the playlist offers
/// catch-up. The panel closes before replaying, so the picture is never
/// covered by the list it was chosen from.
Future<void> showIptvGuide(
  BuildContext context, {
  required IptvChannel channel,
  required EpgProgramme? catchup,
  required Future<void> Function(EpgProgramme programme) onCatchup,
  required Future<void> Function() onBackToLive,
}) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.iptv.guideTitle),
    child: _IptvGuidePanel(channel: channel, catchup: catchup, onCatchup: onCatchup, onBackToLive: onBackToLive),
  ),
);

/// Whether [programme] can be replayed on [channel], from the playlist's
/// own catch-up attributes and the archive window.
IptvCatchupAvailability catchupAvailabilityOf(IptvChannel channel, EpgProgramme programme, {DateTime? now}) =>
    evaluateIptvCatchupAvailability(
      programmeStop: programme.stop,
      now: now ?? DateTime.now(),
      mode: channel.entry.catchupMode,
      source: channel.entry.catchupSource,
      days: double.tryParse(channel.entry.catchupDays?.trim() ?? ''),
      catchupId: programme.catchupId,
    );

/// The URL that replays [programme] on [channel], or null when the playlist
/// offers no usable catch-up for it.
String? catchupUrlOf(IptvChannel channel, EpgProgramme programme) {
  if (catchupAvailabilityOf(channel, programme) != IptvCatchupAvailability.available) return null;
  try {
    return buildIptvCatchupUrl(
      originalUrl: channel.entry.url,
      start: programme.start,
      stop: programme.stop,
      mode: channel.entry.catchupMode,
      source: channel.entry.catchupSource,
      catchupId: programme.catchupId,
    );
  } on Object {
    return null;
  }
}

/// The guide's content: a day at a time, read from the library the moment
/// it builds and once a minute while it stays open (the progress and the
/// "on air" mark move with the clock, not with a reload).
final class _IptvGuidePanel extends ConsumerStatefulWidget {
  const _IptvGuidePanel({
    required this.channel,
    required this.catchup,
    required this.onCatchup,
    required this.onBackToLive,
  });

  final IptvChannel channel;
  final EpgProgramme? catchup;
  final Future<void> Function(EpgProgramme programme) onCatchup;
  final Future<void> Function() onBackToLive;

  @override
  ConsumerState<_IptvGuidePanel> createState() => _IptvGuidePanelState();
}

final class _IptvGuidePanelState extends ConsumerState<_IptvGuidePanel> {
  late DateTime _day = _startOfDay(DateTime.now());
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // A minute is the guide's own resolution: the on-air mark and the
    // progress bar move without a provider rebuild.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final library = ref.watch(iptvLibraryProvider).value;
    final now = DateTime.now();
    final nextDay = DateTime(_day.year, _day.month, _day.day + 1);
    final schedule =
        library?.schedule(widget.channel, from: _day, span: nextDay.difference(_day)) ?? const <EpgProgramme>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Row(
          spacing: DsSpace.s4,
          children: [
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.iptv.previousDay,
              onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day - 1)),
              icon: const DsIcon(DsIcons.chevronLeft),
            ),
            Expanded(
              child: Text(
                _dayLabel(t, _day, now),
                textAlign: TextAlign.center,
                style: theme.typography.bodyStrong.copyWith(color: colors.text),
              ),
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.iptv.nextDay,
              onPressed: () => setState(() => _day = nextDay),
              icon: const DsIcon(DsIcons.chevronRight),
            ),
          ],
        ),
        if (widget.catchup != null)
          DsButton(
            variant: DsButtonVariant.secondary,
            leading: const DsIcon(DsIcons.radio, size: 16),
            onPressed: () => unawaited(_backToLive()),
            child: Text(t.iptv.backToLive),
          ),
        if (library != null && library.guideKeyFor(widget.channel) == null)
          DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.noGuide))
        else if (schedule.isEmpty)
          DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.guideEmpty))
        else
          DsListSection(
            children: [
              for (final programme in schedule)
                _GuideRow(
                  channel: widget.channel,
                  programme: programme,
                  now: now,
                  catchup: widget.catchup,
                  onCatchup: _play,
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _play(EpgProgramme programme) async {
    Navigator.of(context).pop();
    await widget.onCatchup(programme);
  }

  Future<void> _backToLive() async {
    Navigator.of(context).pop();
    await widget.onBackToLive();
  }

  static DateTime _startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);

  static String _dayLabel(Translations t, DateTime day, DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final today = _startOfDay(now);
    if (day == today) return t.iptv.today;
    if (day == DateTime(today.year, today.month, today.day - 1)) return t.iptv.yesterday;
    return '${two(day.month)}-${two(day.day)}';
  }
}

/// One programme: its clock, its name (and subtitle), the on-air progress,
/// and the replay button where the provider allows one.
final class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.programme,
    required this.now,
    required this.catchup,
    required this.onCatchup,
  });

  final IptvChannel channel;
  final EpgProgramme programme;
  final DateTime now;
  final EpgProgramme? catchup;
  final Future<void> Function(EpgProgramme programme) onCatchup;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final phase = classifyIptvProgramme(start: programme.start, stop: programme.stop, now: now);
    final live = phase == IptvProgrammePhase.live;
    final replaying = catchup != null && catchup!.start == programme.start && catchup!.stop == programme.stop;
    final available =
        phase == IptvProgrammePhase.catchup &&
        catchupAvailabilityOf(channel, programme, now: now) == IptvCatchupAvailability.available;
    final subtitle = programme.subtitle?.trim() ?? '';
    final total = programme.stop.difference(programme.start);
    final progress = live && total > Duration.zero
        ? (now.difference(programme.start).inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Text(
                  _clock(programme.start),
                  style: theme.typography.numeric(
                    theme.typography.caption.copyWith(
                      color: live ? colors.accent : colors.textMuted,
                      fontWeight: live ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Text(
                  _clock(programme.stop),
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Text(
                  programme.title.isEmpty ? '—' : programme.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(
                    color: live || replaying ? colors.text : colors.textMuted,
                    fontWeight: live || replaying ? FontWeight.w600 : null,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                if (live) ...[
                  if (progress case final value?) DsProgressBar(value: value, semanticLabel: t.iptv.onAir),
                  Text(t.iptv.onAir, style: theme.typography.caption.copyWith(color: colors.accent)),
                ] else if (replaying)
                  Text(t.iptv.playingCatchup, style: theme.typography.caption.copyWith(color: colors.accent))
                else if (phase == IptvProgrammePhase.scheduled)
                  Text(t.iptv.upNext, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              ],
            ),
          ),
          if (available)
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(onCatchup(programme)),
              child: Text(t.iptv.catchup),
            ),
          if (phase == IptvProgrammePhase.catchup && !available)
            Text(t.iptv.catchupUnavailable, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
        ],
      ),
    );
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}
