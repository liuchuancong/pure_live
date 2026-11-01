import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart' show iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart' show iptvRecentProvider;
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart'
    show IptvGuideRow, iptvClockLabel, iptvDayLabel, iptvStartOfDay;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show IptvIconAction;
import 'package:pure_live/shared/shared.dart' show LiveWindow, cachedImage;

/// The IPTV module's programme guide as a page of its own: the channels on
/// one side, the open channel's day on the other, with the day walked back
/// and forward. A past programme's replay button opens the player on that
/// programme, so the guide is a way into catch-up rather than a read-out.
///
/// The day's panel opens with its own head — the channel it belongs to, what
/// is on air right now with its progress, the day being read and the way into
/// the player — the same anchor the player's info strip draws. Without it the
/// list of a day's programmes is anonymous as soon as the channel picker
/// scrolls away, and the day control sits in the page header above the seam
/// between the two panes, attached to neither.
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
    // The guide opens on the channel last watched — the zapper's own rule of
    // starting where the picture already is — and on the first when nothing
    // has. A channel the library no longer holds falls back in the build.
    final recent = ref.read(iptvRecentProvider);
    _channelId = recent.isEmpty ? null : recent.first.channelId;
    // The on-air mark and its progress follow the clock, not a reload.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // The toolbar's word lands in the picker's name filter in place: the
    // listener catches a word handed while the page is showing, the
    // post-frame take one handed as the page arrives.
    ref.listenManual(iptvSearchHandoffProvider, (_, _) => _takeHandoff());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeHandoff());
  }

  /// Moves the handed word into the picker's name filter.
  void _takeHandoff() {
    final word = ref.read(iptvSearchHandoffProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    _search.value = TextEditingValue(text: word, selection: TextSelection.collapsed(offset: word.length));
    setState(() {});
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

  /// Flips the open channel's favourite on the library itself, the seam every
  /// other surface of the module reads; the page redraws its own heart from
  /// the channel the library hands back.
  Future<void> _toggleFavourite(IptvChannel channel) async {
    await ref.read(iptvLibraryProvider).value?.toggleFavorite(channel.id);
    if (mounted) setState(() {});
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
    // "On air" is a fact about the day the panel shows, so the slot is read
    // from this day's own list rather than from the library's wide current-
    // hour window — a past day would otherwise be headed by today's
    // programme.
    final slot = _day == iptvStartOfDay(now) ? _slotOf(schedule, now) : null;
    final hasGuide = selected != null && library != null && library.guideKeyFor(selected) != null;
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
          Column(
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
                  slot: slot,
                  day: _day,
                  now: now,
                  hasGuide: hasGuide,
                  onReplay: (programme) {
                    final open = selected;
                    if (open != null) _play(open, catchup: programme);
                  },
                  onPlay: () {
                    final open = selected;
                    if (open != null) _play(open);
                  },
                  onFavourite: () {
                    final open = selected;
                    if (open != null) unawaited(_toggleFavourite(open));
                  },
                  onPreviousDay: () => _stepDay(-1),
                  onNextDay: () => _stepDay(1),
                  onToday: () => setState(() => _day = iptvStartOfDay(DateTime.now())),
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
                // The two panes split the window's height rather than the
                // picker keeping a hardcoded box: the day's panel now opens
                // with its own head, and a fixed 260 over a fixed head leaves
                // the list whatever the viewport has not already spent.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    Expanded(flex: 2, child: picker),
                    Expanded(flex: 3, child: guide),
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

/// The current and next programme inside one day's list, read the way the
/// library reads its own slot but from the programmes the panel actually
/// shows.
IptvProgrammeSlot _slotOf(List<EpgProgramme> schedule, DateTime now) {
  EpgProgramme? current;
  EpgProgramme? next;
  for (final programme in schedule) {
    if (programme.start.isAfter(now)) {
      next ??= programme;
      continue;
    }
    if (!programme.stop.isBefore(now) && (current == null || programme.start.isAfter(current.start))) {
      current = programme;
    }
  }
  return IptvProgrammeSlot(at: now, current: current, next: next);
}

/// The day's own controls: the date between the steps, and the way back to
/// today without reading the label. The way back is only offered when the
/// panel is not already on today — a step onto the day already open does
/// nothing.
final class _DayStepper extends StatelessWidget {
  const _DayStepper({
    required this.label,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(label, style: theme.typography.bodyStrong.copyWith(color: colors.text)),
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.iptv.nextDay,
          onPressed: onNext,
          icon: const DsIcon(DsIcons.chevronRight),
        ),
        if (!isToday)
          DsButton(variant: DsButtonVariant.ghost, size: DsSize.sm, onPressed: onToday, child: Text(t.iptv.today)),
      ],
    );
  }
}

/// A channel's logo, or the kit's tinted initials when its playlist carries
/// none — the same mark the channel list rows and the day's head draw.
final class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel, this.size = DsSize.sm});

  final IptvChannel channel;
  final DsSize size;

  @override
  Widget build(BuildContext context) {
    final logo = (channel.entry.tvgLogo ?? '').trim();
    return DsAvatar(
      initials: channel.entry.name,
      image: logo.isEmpty ? null : cachedImage(logo),
      size: size,
      toneIndex: DsAvatar.toneFor(channel.id),
      semanticLabel: channel.entry.name,
    );
  }
}

/// The channels the guide can open: the name search above a one-row-per-
/// channel list, the open channel marked.
final class _ChannelPicker extends StatefulWidget {
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
  State<_ChannelPicker> createState() => _ChannelPickerState();
}

final class _ChannelPickerState extends State<_ChannelPicker> {
  /// The selected row's mark, so the list can bring it into view — the page
  /// may open on a channel buried deep in the list.
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_ChannelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) _revealSelected();
  }

  /// Scrolls the selected row into view; a row already on screen stays put.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keyContext = _selectedKey.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(keyContext, alignment: 0.3, duration: const Duration(milliseconds: 120));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final channels = widget.channels;
    final selectedId = widget.selectedId;
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.s12),
            child: DsSearchField(
              controller: widget.search,
              placeholder: t.iptv.searchChannels,
              semanticLabel: t.iptv.searchChannels,
              onChanged: widget.onQuery,
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
                      final group = iptvGroupKeyOf(channel);
                      return KeyedSubtree(
                        key: channel.id == selectedId ? _selectedKey : null,
                        child: DsListRow(
                          selected: channel.id == selectedId,
                          leading: _ChannelLogo(channel: channel),
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
                          onPressed: () => widget.onSelect(channel),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The open channel's day: the head that names whose day it is and what is on
/// air now, then the day's programmes with their clocks, the one on air marked
/// and the past ones replayable where the playlist offers catch-up.
final class _SchedulePanel extends ConsumerWidget {
  const _SchedulePanel({
    required this.channel,
    required this.schedule,
    required this.slot,
    required this.day,
    required this.now,
    required this.hasGuide,
    required this.onReplay,
    required this.onPlay,
    required this.onFavourite,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
  });

  final IptvChannel? channel;
  final List<EpgProgramme> schedule;

  /// The programme on air now and the one after it, for the day being shown;
  /// null for a day the clock has already passed or not yet reached.
  final IptvProgrammeSlot? slot;
  final DateTime day;
  final DateTime now;

  /// Whether a guide source stands behind this channel at all — the panel
  /// says 暂无节目单 for a channel with none, and 这一天没有节目 for a day of a
  /// guide that has nothing on.
  final bool hasGuide;
  final void Function(EpgProgramme programme) onReplay;
  final VoidCallback onPlay;
  final VoidCallback onFavourite;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(iptvBrowseSettingsProvider);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScheduleHead(
            channel: open,
            slot: slot,
            day: day,
            now: now,
            showNumber: browse.showChannelNumber,
            showProgramme: browse.showProgrammeLine,
            onPlay: onPlay,
            onFavourite: onFavourite,
            onPreviousDay: onPreviousDay,
            onNextDay: onNextDay,
            onToday: onToday,
          ),
          const DsDivider(),
          Expanded(
            child: !hasGuide
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpace.s16),
                      child: DsEmptyState(icon: const DsIcon(DsIcons.calendarClock), title: Text(t.iptv.noGuide)),
                    ),
                  )
                : schedule.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpace.s16),
                      child: DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.guideEmpty)),
                    ),
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
                        onCatchup: (programme) async => onReplay(programme),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The head of the day's panel: the channel it belongs to (its logo, name,
/// dial number and group — the last two under the same browse switches the
/// channel list reads), what is on air now with its progress, the day being
/// walked, and the way into the player beside the heart.
///
/// The panel is a card of one channel's day, so the channel's own name has to
/// live in it: the picker at its side marks the choice, but on a narrow window
/// it is a box of its own that scrolls away, and a day's list with no name over
/// it is the same list for every channel.
final class _ScheduleHead extends StatelessWidget {
  const _ScheduleHead({
    required this.channel,
    required this.slot,
    required this.day,
    required this.now,
    required this.showNumber,
    required this.showProgramme,
    required this.onPlay,
    required this.onFavourite,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
  });

  final IptvChannel channel;
  final IptvProgrammeSlot? slot;
  final DateTime day;
  final DateTime now;
  final bool showNumber;
  final bool showProgramme;
  final VoidCallback onPlay;
  final VoidCallback onFavourite;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final number = showNumber ? channel.number : null;
    final group = iptvGroupKeyOf(channel);
    final identity = Row(
      spacing: DsSpace.s8,
      children: [
        _ChannelLogo(channel: channel, size: DsSize.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Row(
                spacing: DsSpace.s6,
                children: [
                  Flexible(
                    child: Text(
                      channel.entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                  ),
                  if (number != null)
                    Text(
                      '$number',
                      style: theme.typography.numeric(theme.typography.small.copyWith(color: colors.textSubtle)),
                    ),
                ],
              ),
              Text(
                group.isEmpty ? t.iptv.ungrouped : group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
    final stepper = _DayStepper(
      label: iptvDayLabel(t, day, now),
      isToday: day == iptvStartOfDay(now),
      onPrevious: onPreviousDay,
      onNext: onNextDay,
      onToday: onToday,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        IptvIconAction(
          icon: DsIcons.heart,
          label: channel.favorite ? t.iptv.unfavouriteAction : t.iptv.favouriteAction,
          onPressed: onFavourite,
          color: channel.favorite ? colors.accent : null,
        ),
        DsButton(
          size: DsSize.sm,
          onPressed: onPlay,
          leading: const DsIcon(DsIcons.play, size: 15),
          child: Text(t.iptv.openChannel),
        ),
      ],
    );
    final programme = showProgramme ? _programmeLine(context) : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final top = LiveWindow.stacksToolbar(constraints.maxWidth)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s6,
                children: [
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(child: identity),
                      actions,
                    ],
                  ),
                  Align(alignment: AlignmentDirectional.centerStart, child: stepper),
                ],
              )
            : Row(
                spacing: DsSpace.s12,
                children: [
                  Expanded(child: identity),
                  stepper,
                  actions,
                ],
              );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s6,
            children: [top, ?programme],
          ),
        );
      },
    );
  }

  /// The on-air anchor for the day being read: what is on with its clock and
  /// progress, or what comes next. Quiet when the day has neither — the panel
  /// below already says 这一天没有节目, and saying it twice is not saying it
  /// better.
  Widget? _programmeLine(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = slot?.current;
    final next = slot?.next;
    if (current != null && current.title.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              DsBadge(label: Text(t.iptv.onAir), status: DsStatus.danger),
              Flexible(
                child: Text(
                  '${iptvClockLabel(current.start)}–${iptvClockLabel(current.stop)}  ${current.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          if (slot?.progress case final progress?) DsProgressBar(value: progress, semanticLabel: t.iptv.onAir),
        ],
      );
    }
    if (next != null && next.title.isNotEmpty) {
      return Row(
        spacing: DsSpace.s6,
        children: [
          DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
          Flexible(
            child: Text(
              '${t.iptv.upNext} · ${iptvClockLabel(next.start)} · ${next.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      );
    }
    return null;
  }
}
