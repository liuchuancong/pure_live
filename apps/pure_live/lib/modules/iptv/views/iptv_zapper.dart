import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show IptvReminder, iptvRemindersProvider;
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart'
    show catchupAvailabilityOf, iptvClockLabel, iptvStartOfDay;
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The height of one row in any of the panel's three columns; the keyboard
/// scrolls by it, so the columns have to agree on it.
const double _rowHeight = 48;

/// The height of a programme row: the time and the name share the line, the
/// subtitle and the action take a second.
const double _programmeRowHeight = 60;

/// A group in the panel's first column: a real group of the library, or the
/// synthetic favourites entry the reference puts at the top.
typedef _Group = ({bool favourites, String? name});

/// The webtv reference's channel panel, drawn over the picture it changes:
/// groups, the open group's channels, and the selected channel's day.
///
/// The first column is where the viewer starts (their favourites first, then
/// the library's groups); the second is the same zapping order the remote
/// walks, so the panel and the up/down keys never disagree; the third is the
/// programme guide, where a past programme replays and a future one can be
/// set as a reminder. Choosing a channel switches the picture, choosing a
/// programme replays or reminds, and the panel closes first so the picture
/// is never covered by the list it was chosen from.
final class IptvZapper extends ConsumerStatefulWidget {
  /// The panel for [channel], the one playing now.
  const IptvZapper({
    required this.channel,
    required this.onPlayChannel,
    required this.onCatchup,
    required this.onClose,
    super.key,
  });

  /// The channel on screen when the panel opens.
  final IptvChannel channel;

  /// Plays live on [channel] — the same channel or another one.
  final void Function(IptvChannel channel) onPlayChannel;

  /// Replays a past programme on [channel].
  final Future<void> Function(IptvChannel channel, EpgProgramme programme) onCatchup;

  /// Closes the panel without changing anything.
  final VoidCallback onClose;

  @override
  ConsumerState<IptvZapper> createState() => _IptvZapperState();
}

final class _IptvZapperState extends ConsumerState<IptvZapper> {
  final FocusNode _focus = FocusNode(debugLabel: 'iptv-zapper');
  final ScrollController _groupScroll = ScrollController();
  final ScrollController _channelScroll = ScrollController();
  final ScrollController _programmeScroll = ScrollController();

  /// Which column the keys move in: 0 groups, 1 channels, 2 programmes.
  int _column = 1;
  int _groupIndex = 0;
  int _channelIndex = 0;
  int _programmeIndex = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _focus.dispose();
    _groupScroll.dispose();
    _channelScroll.dispose();
    _programmeScroll.dispose();
    super.dispose();
  }

  /// Selects the playing channel's own group, channel and programme, so the
  /// panel opens where the picture already is.
  void _open() {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    final now = DateTime.now();
    final groups = _groupsOf(library);
    final key = iptvGroupKeyOf(widget.channel);
    final group = groups.indexWhere((entry) => !entry.favourites && entry.name == key);
    _groupIndex = group < 0 ? 0 : group;
    final channels = _channelsOf(library, groups[_groupIndex]);
    final channel = channels.indexWhere((entry) => entry.id == widget.channel.id);
    _channelIndex = channel < 0 ? 0 : channel;
    _programmeIndex = _liveProgramme(library, widget.channel, now);
  }

  static List<_Group> _groupsOf(IptvLibrary library) => [
    if (library.zapSequence(favouritesOnly: true).channels.isNotEmpty) (favourites: true, name: null),
    for (final name in library.groupNames)
      if (!library.isGroupHidden(name)) (favourites: false, name: name),
  ];

  static List<IptvChannel> _channelsOf(IptvLibrary library, _Group? group) =>
      group == null ? const [] : library.zapSequence(group: group.name, favouritesOnly: group.favourites).channels;

  /// The index of the programme on air at [now], or the first upcoming one
  /// when the guide is between programmes.
  static int _liveProgramme(IptvLibrary library, IptvChannel channel, DateTime now) {
    final schedule = library.schedule(channel, from: iptvStartOfDay(now), span: const Duration(days: 1));
    final live = schedule.indexWhere((programme) => !programme.start.isAfter(now) && !programme.stop.isBefore(now));
    if (live >= 0) return live;
    final next = schedule.indexWhere((programme) => programme.start.isAfter(now));
    return next < 0 ? 0 : next;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final library = ref.watch(iptvLibraryProvider).value;
    final reminders = ref.watch(iptvRemindersProvider);
    if (library == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final groups = _groupsOf(library);
    final groupIndex = groups.isEmpty ? 0 : _groupIndex.clamp(0, groups.length - 1);
    final group = groups.isEmpty ? null : groups[groupIndex];
    final channels = _channelsOf(library, group);
    final channelIndex = channels.isEmpty ? 0 : _channelIndex.clamp(0, channels.length - 1);
    final channel = channels.isEmpty ? null : channels[channelIndex];
    final schedule = channel == null
        ? const <EpgProgramme>[]
        : library.schedule(channel, from: iptvStartOfDay(now), span: const Duration(days: 1));
    final programmeIndex = schedule.isEmpty ? 0 : _programmeIndex.clamp(0, schedule.length - 1);
    String groupLabel(_Group entry) => entry.favourites
        ? t.iptv.favouritesTitle
        : (entry.name ?? '').isEmpty
        ? t.iptv.ungrouped
        : entry.name!;
    String actionLabel(EpgProgramme programme) {
      final phase = classifyIptvProgramme(start: programme.start, stop: programme.stop, now: now);
      if (phase == IptvProgrammePhase.live) return t.iptv.onAir;
      if (phase == IptvProgrammePhase.catchup) {
        return channel != null &&
                catchupAvailabilityOf(channel, programme, now: now) == IptvCatchupAvailability.available
            ? t.iptv.catchup
            : t.iptv.catchupUnavailable;
      }
      return reminders.any((reminder) => reminder.isFor(channel?.id ?? '', programme.start))
          ? t.iptv.reminderCancelAction
          : t.iptv.reminderAction;
    }

    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _moveColumn(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _moveColumn(1),
        const SingleActivator(LogicalKeyboardKey.enter): _activate,
        const SingleActivator(LogicalKeyboardKey.select): _activate,
        const SingleActivator(LogicalKeyboardKey.space): _activate,
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: DsSurface(
          decoration: DsBoxDecoration(
            color: colors.overlay,
            borderRadius: BorderRadius.circular(theme.radii.overlay),
            shadows: theme.shadows.overlay,
          ),
          child: Padding(
            padding: const EdgeInsets.all(DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        t.iptv.zapperTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.title.copyWith(color: colors.text),
                      ),
                    ),
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.common.close,
                      onPressed: widget.onClose,
                      icon: const DsIcon(DsIcons.x),
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s8,
                    children: [
                      SizedBox(
                        width: 132,
                        child: _Column(
                          active: _column == 0,
                          header: t.iptv.zapperGroups,
                          child: ListView.builder(
                            controller: _groupScroll,
                            itemExtent: _rowHeight,
                            itemCount: groups.length,
                            itemBuilder: (context, index) => DsListRow(
                              title: Text(
                                groupLabel(groups[index]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(color: colors.text),
                              ),
                              selected: index == groupIndex,
                              style: const DsListRowStyle(height: _rowHeight),
                              onPressed: () => _chooseGroup(index),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 212,
                        child: _Column(
                          active: _column == 1,
                          header: t.iptv.zapperChannels,
                          child: channels.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(DsSpace.s8),
                                  child: DsEmptyState(
                                    icon: const DsIcon(DsIcons.tv),
                                    title: Text(t.iptv.zapperEmptyGroup),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _channelScroll,
                                  itemExtent: _rowHeight,
                                  itemCount: channels.length,
                                  itemBuilder: (context, index) {
                                    final entry = channels[index];
                                    final logo = (entry.entry.tvgLogo ?? '').trim();
                                    return DsListRow(
                                      leading: DsAvatar(
                                        initials: entry.entry.name,
                                        image: logo.isEmpty ? null : cachedImage(logo),
                                        size: DsSize.xs,
                                        toneIndex: DsAvatar.toneFor(entry.id),
                                        semanticLabel: entry.entry.name,
                                      ),
                                      title: Text(
                                        [if (entry.number != null) '${entry.number}', entry.entry.name].join('  '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.typography.body.copyWith(color: colors.text),
                                      ),
                                      selected: index == channelIndex,
                                      style: const DsListRowStyle(height: _rowHeight),
                                      trailing: DsButton.icon(
                                        variant: DsButtonVariant.ghost,
                                        size: DsSize.sm,
                                        semanticLabel: entry.favorite
                                            ? t.iptv.unfavouriteAction
                                            : t.iptv.favouriteAction,
                                        onPressed: () => unawaited(_toggleFavourite(entry)),
                                        icon: DsIcon(DsIcons.heart, color: entry.favorite ? colors.accent : null),
                                      ),
                                      onPressed: () => _chooseChannel(index),
                                    );
                                  },
                                ),
                        ),
                      ),
                      Expanded(
                        child: _Column(
                          active: _column == 2,
                          header: t.iptv.zapperProgrammes,
                          child: schedule.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(DsSpace.s8),
                                  child: DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.guideEmpty)),
                                )
                              : ListView.builder(
                                  controller: _programmeScroll,
                                  itemExtent: _programmeRowHeight,
                                  itemCount: schedule.length,
                                  itemBuilder: (context, index) {
                                    final programme = schedule[index];
                                    final live =
                                        classifyIptvProgramme(start: programme.start, stop: programme.stop, now: now) ==
                                        IptvProgrammePhase.live;
                                    return DsListRow(
                                      title: Text(
                                        '${iptvClockLabel(programme.start)}  ${programme.title.isEmpty ? '—' : programme.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.typography.body.copyWith(
                                          color: live ? colors.text : colors.textMuted,
                                          fontWeight: live ? FontWeight.w600 : null,
                                        ),
                                      ),
                                      description: Text(
                                        [
                                          '${iptvClockLabel(programme.start)} - ${iptvClockLabel(programme.stop)}',
                                          if ((programme.subtitle ?? '').trim().isNotEmpty) programme.subtitle!.trim(),
                                        ].join('  '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                      ),
                                      detail: Text(
                                        actionLabel(programme),
                                        style: theme.typography.caption.copyWith(
                                          color: live ? colors.accent : colors.textMuted,
                                        ),
                                      ),
                                      selected: index == programmeIndex,
                                      style: const DsListRowStyle(height: _programmeRowHeight),
                                      onPressed: channel == null ? null : () => unawaited(_act(channel, programme)),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  t.iptv.zapperHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the selection in the active column by [delta].
  void _move(int delta) {
    switch (_column) {
      case 0:
        final library = ref.read(iptvLibraryProvider).value;
        if (library == null) return;
        final groups = _groupsOf(library);
        if (groups.isEmpty) return;
        _groupIndex = _step(_groupIndex, delta, groups.length);
        _reveal(_groupScroll, _groupIndex);
        _syncGroup(library, groups[_groupIndex]);
        setState(() {});
      case 1:
        final library = ref.read(iptvLibraryProvider).value;
        if (library == null) return;
        final groups = _groupsOf(library);
        if (groups.isEmpty) return;
        final channels = _channelsOf(library, groups[_groupIndex.clamp(0, groups.length - 1)]);
        if (channels.isEmpty) return;
        _channelIndex = _step(_channelIndex, delta, channels.length);
        _programmeIndex = _liveProgramme(library, channels[_channelIndex], DateTime.now());
        _reveal(_channelScroll, _channelIndex);
        setState(() {});
      case 2:
        final channel = _selectedChannel();
        final schedule = _scheduleOf(channel);
        if (schedule.isEmpty) return;
        _programmeIndex = _step(_programmeIndex, delta, schedule.length);
        _reveal(_programmeScroll, _programmeIndex, height: _programmeRowHeight);
        setState(() {});
    }
  }

  /// Moves between the three columns, stopping at the ends.
  void _moveColumn(int delta) {
    _column = (_column + delta).clamp(0, 2);
    setState(() {});
  }

  static int _step(int value, int delta, int length) => length == 0 ? 0 : (value + delta) % length;

  /// Keeps the channel column and the programme column with the group the
  /// keys just moved to: the playing channel when it is in that group, the
  /// group's first one otherwise.
  void _syncGroup(IptvLibrary library, _Group group) {
    final channels = _channelsOf(library, group);
    if (channels.isEmpty) {
      _channelIndex = 0;
      _programmeIndex = 0;
      return;
    }
    final playing = channels.indexWhere((entry) => entry.id == widget.channel.id);
    _channelIndex = playing < 0 ? 0 : playing;
    _programmeIndex = _liveProgramme(library, channels[_channelIndex], DateTime.now());
  }

  void _chooseGroup(int index) {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    final groups = _groupsOf(library);
    if (index < 0 || index >= groups.length) return;
    _groupIndex = index;
    _syncGroup(library, groups[index]);
    _column = 1;
    _reveal(_channelScroll, _channelIndex);
    setState(() {});
  }

  void _chooseChannel(int index) {
    final channel = _at(index);
    if (channel == null) return;
    _channelIndex = index;
    setState(() {});
    widget.onPlayChannel(channel);
  }

  /// The confirm key: group → channels, channel → play, programme → replay,
  /// remind or back to live.
  void _activate() {
    switch (_column) {
      case 0:
        _moveColumn(1);
      case 1:
        final channel = _selectedChannel();
        if (channel != null) widget.onPlayChannel(channel);
      case 2:
        final channel = _selectedChannel();
        final programme = _selectedProgramme();
        if (channel != null && programme != null) unawaited(_act(channel, programme));
    }
  }

  IptvChannel? _selectedChannel() {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return null;
    final groups = _groupsOf(library);
    if (groups.isEmpty) return null;
    return _at(_channelIndex);
  }

  IptvChannel? _at(int index) {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return null;
    final groups = _groupsOf(library);
    if (groups.isEmpty) return null;
    final channels = _channelsOf(library, groups[_groupIndex.clamp(0, groups.length - 1)]);
    return index >= 0 && index < channels.length ? channels[index] : null;
  }

  List<EpgProgramme> _scheduleOf(IptvChannel? channel) {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null || channel == null) return const [];
    final now = DateTime.now();
    return library.schedule(channel, from: iptvStartOfDay(now), span: const Duration(days: 1));
  }

  EpgProgramme? _selectedProgramme() {
    final schedule = _scheduleOf(_selectedChannel());
    if (schedule.isEmpty) return null;
    return schedule[_programmeIndex.clamp(0, schedule.length - 1)];
  }

  /// A programme's action: live switches to the channel, a past programme
  /// replays where the playlist allows it, a future one toggles its reminder.
  Future<void> _act(IptvChannel channel, EpgProgramme programme) async {
    final now = DateTime.now();
    final t = context.t;
    switch (classifyIptvProgramme(start: programme.start, stop: programme.stop, now: now)) {
      case IptvProgrammePhase.live:
        widget.onPlayChannel(channel);
      case IptvProgrammePhase.catchup:
        if (catchupAvailabilityOf(channel, programme, now: now) != IptvCatchupAvailability.available) return;
        await widget.onCatchup(channel, programme);
      case IptvProgrammePhase.scheduled:
        final added = await ref
            .read(iptvRemindersProvider.notifier)
            .toggle(
              IptvReminder(channelId: channel.id, title: programme.title, start: programme.start, stop: programme.stop),
            );
        if (!mounted) return;
        showDsToast(
          context: context,
          title: added ? t.iptv.reminderSet(title: programme.title) : t.iptv.reminderRemoved,
          status: added ? DsStatus.success : DsStatus.neutral,
        );
    }
  }

  Future<void> _toggleFavourite(IptvChannel channel) async {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    await library.toggleFavorite(channel.id);
    if (mounted) setState(() {});
  }

  /// Scrolls the row at [index] into the middle of its column.
  void _reveal(ScrollController controller, int index, {double height = _rowHeight}) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (index * height - position.viewportDimension / 2 + height / 2)
        .clamp(0.0, math.max(0.0, position.maxScrollExtent))
        .toDouble();
    controller.animateTo(target, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }
}

/// One of the panel's three columns: a caption that lights up while the keys
/// move in it, and the list below.
final class _Column extends StatelessWidget {
  const _Column({required this.active, required this.header, required this.child});

  final bool active;
  final String header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s4,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
          child: Text(
            header,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(
              color: active ? colors.accent : colors.textSubtle,
              fontWeight: active ? FontWeight.w600 : null,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
