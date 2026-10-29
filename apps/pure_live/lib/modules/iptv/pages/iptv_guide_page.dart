import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart' show IptvGuideRow, iptvDayLabel, iptvStartOfDay;
import 'package:pure_live/shared/shared.dart' show LiveWindow, cachedImage;

/// The IPTV module's programme guide as a page of its own: the channels on
/// one side, the open channel's day on the other, with the day walked back
/// and forward. A past programme's replay button opens the player on that
/// programme, so the guide is a way into catch-up rather than a read-out.
///
/// The webtv reference puts the same three panes (group, channel, programme)
/// beside its player; here the player is its own route, and this page is the
/// guide without it.
final class IptvGuidePage extends ConsumerStatefulWidget {
  /// The module's guide page.
  const IptvGuidePage({super.key});

  @override
  ConsumerState<IptvGuidePage> createState() => _IptvGuidePageState();
}

final class _IptvGuidePageState extends ConsumerState<IptvGuidePage> {
  /// The channel whose day is open; null takes the first one the list holds.
  String? _channelId;

  /// The day being read, at its first minute.
  late DateTime _day = iptvStartOfDay(DateTime.now());

  /// The picker's name filter.
  final TextEditingController _search = TextEditingController();

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The on-air mark and its progress follow the clock, not a reload.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _stepDay(int days) => setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  void _play(IptvChannel channel, {EpgProgramme? catchup}) {
    unawaited(
      context.push(
        RouteNames.iptvPlay.replaceFirst(':channelId', channel.id),
        extra: (channel: channel, catchupProgramme: catchup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final library = ref.watch(iptvLibraryProvider).value;
    final query = _search.text.trim().toLowerCase();
    final channels = [
      for (final channel in library?.orderedChannels ?? const <IptvChannel>[])
        if (query.isEmpty || channel.entry.name.toLowerCase().contains(query)) channel,
    ];
    final selected =
        (_channelId == null ? null : library?.channelById(_channelId!)) ?? (channels.isEmpty ? null : channels.first);
    final now = DateTime.now();
    final dayEnd = DateTime(_day.year, _day.month, _day.day + 1);
    final schedule = selected == null || library == null
        ? const <EpgProgramme>[]
        : library.schedule(selected, from: _day, span: dayEnd.difference(_day));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
        DsSpace.s16,
        LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
        DsSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(t.common.moduleIptv, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
                  Text(t.iptv.guideTitle, style: theme.typography.display.copyWith(color: colors.text)),
                  Text(
                    channels.isEmpty ? t.iptv.emptyDescription : t.iptv.channelCount(count: channels.length),
                    style: theme.typography.body.copyWith(color: colors.textMuted),
                  ),
                ],
              );
              final stepper = _DayStepper(
                label: iptvDayLabel(t, _day, now),
                onPrevious: () => _stepDay(-1),
                onNext: () => _stepDay(1),
                onToday: () => setState(() => _day = iptvStartOfDay(DateTime.now())),
              );
              if (LiveWindow.isCompact(constraints.maxWidth)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s8,
                  children: [title, stepper],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: DsSpace.s16),
                  stepper,
                ],
              );
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final picker = _ChannelPicker(
                  channels: channels,
                  selectedId: selected?.id,
                  search: _search,
                  onQuery: (value) => setState(() {}),
                  onSelect: (channel) => setState(() => _channelId = channel.id),
                );
                final guide = _SchedulePanel(
                  channel: selected,
                  schedule: schedule,
                  now: now,
                  onReplay: (programme) {
                    final open = selected;
                    if (open != null) _play(open, catchup: programme);
                  },
                );
                if (LiveWindow.isExpanded(constraints.maxWidth)) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s16,
                    children: [
                      SizedBox(width: 320, child: picker),
                      Expanded(child: guide),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    SizedBox(height: 260, child: picker),
                    Expanded(child: guide),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's own controls: the date between the steps, and the way back to
/// today without reading the label.
final class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.label, required this.onPrevious, required this.onNext, required this.onToday});

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s4,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.iptv.previousDay,
          onPressed: onPrevious,
          icon: const DsIcon(DsIcons.chevronLeft),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
          child: Text(label, style: theme.typography.bodyStrong.copyWith(color: colors.text)),
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.iptv.nextDay,
          onPressed: onNext,
          icon: const DsIcon(DsIcons.chevronRight),
        ),
        DsButton(variant: DsButtonVariant.ghost, size: DsSize.sm, onPressed: onToday, child: Text(t.iptv.today)),
      ],
    );
  }
}

/// The channels the guide can open: the name search above a one-row-per-
/// channel list, the open channel marked.
final class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({
    required this.channels,
    required this.selectedId,
    required this.search,
    required this.onQuery,
    required this.onSelect,
  });

  final List<IptvChannel> channels;
  final String? selectedId;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final ValueChanged<IptvChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.s12),
            child: DsSearchField(
              controller: search,
              placeholder: t.iptv.searchChannels,
              semanticLabel: t.iptv.searchChannels,
              onChanged: onQuery,
            ),
          ),
          const DsDivider(),
          Expanded(
            child: channels.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(DsSpace.s16),
                    child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noChannelMatch)),
                  )
                : ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      final logo = (channel.entry.tvgLogo ?? '').trim();
                      final group = iptvGroupKeyOf(channel);
                      return DsListRow(
                        selected: channel.id == selectedId,
                        leading: DsAvatar(
                          initials: channel.entry.name,
                          image: logo.isEmpty ? null : cachedImage(logo),
                          size: DsSize.sm,
                          toneIndex: DsAvatar.toneFor(channel.id),
                          semanticLabel: channel.entry.name,
                        ),
                        title: Text(
                          channel.entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.copyWith(color: colors.text),
                        ),
                        description: Text(
                          group.isEmpty ? t.iptv.ungrouped : group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                        ),
                        onPressed: () => onSelect(channel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The open channel's day: its programmes with their clocks, the one on air
/// marked and progressing, and the replay button where the playlist offers
/// catch-up.
final class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.channel, required this.schedule, required this.now, required this.onReplay});

  final IptvChannel? channel;
  final List<EpgProgramme> schedule;
  final DateTime now;
  final void Function(EpgProgramme programme)? onReplay;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final open = channel;
    if (open == null) {
      return DsCard(
        style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s16)),
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.calendarClock),
          title: Text(t.iptv.emptyTitle),
          description: Text(t.iptv.emptyDescription),
        ),
      );
    }
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: schedule.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.guideEmpty)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
              itemCount: schedule.length,
              itemBuilder: (context, index) {
                final programme = schedule[index];
                return IptvGuideRow(
                  channel: open,
                  programme: programme,
                  now: now,
                  catchup: null,
                  onCatchup: (programme) async => onReplay?.call(programme),
                );
              },
            ),
    );
  }
}
