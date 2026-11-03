import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart' show appPathsProvider;
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/media_preview/media_preview_page.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/data/recorder_search_handoff.dart'
    show recorderLibrarySearchHandoffProvider;
import 'package:pure_live/modules/live/recorder/data/recording_library.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart'
    show formatRecordingBytes, formatRecordingDuration, formatRecordingMoment;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show kRecordingFileDeletedWarning;
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// The recording library: the takes on disk, browsed the way the recorder
/// filed them — a day, the platforms recorded that day, the rooms behind a
/// platform, and the takes of one room.
///
/// It walks the folder tree rather than the task store because the store keys a
/// row by `platform:roomId`: a room recorded twice keeps one row and hides its
/// other take, though the file sits on disk. So pressing a row plays the
/// recording it names, and the room it came from is one menu step away.
final class RecorderLibraryPane extends ConsumerStatefulWidget {
  const RecorderLibraryPane({
    required this.onPlay,
    required this.onOpenRoom,
    required this.platformName,
    this.platforms = const {},
    this.excludedPlatforms = const {},
    this.openRoomLabel,
    this.showHeading = true,
    super.key,
  });

  /// Plays the chosen take over the run the library currently shows, in the
  /// order it shows it, so the player's next and previous walk the same list the
  /// viewer was reading.
  final void Function(List<RecordingTake> around, RecordingTake take) onPlay;

  /// Opens the room a take was made in, for the row menu.
  final void Function(RecordingTake take) onOpenRoom;

  /// The viewer's name for a site id.
  final String Function(String platformId) platformName;

  /// Only these site ids; empty means every site the tree holds. A module's own
  /// recording page passes its platform id, so the IPTV list never shows live
  /// rooms and the live centre never shows channels — the recorder writes both
  /// into one tree, and this is the cut between them.
  final Set<String> platforms;

  /// Sites left out even when [platforms] is empty. The live centre uses this
  /// rather than a list of site ids, because the sites grow and IPTV does not.
  final Set<String> excludedPlatforms;

  /// The row menu's word for going to where the take was made. The live centre
  /// says 进入直播间; a module whose rooms are channels says its own, and the
  /// library has no opinion — null falls back to the recorder's wording.
  final String? openRoomLabel;

  /// Whether the pane draws its own heading. Embedded under a page that already
  /// has one — the recording centre, which keeps its title and its filter chips
  /// — the heading would say the same thing twice, and only the toolbar shows.
  final bool showHeading;

  @override
  ConsumerState<RecorderLibraryPane> createState() => _RecorderLibraryPaneState();
}

final class _RecorderLibraryPaneState extends ConsumerState<RecorderLibraryPane> {
  /// What the search box holds; matched against room, platform, day and file.
  String _query = '';

  /// Only the sites ticked in the panel; empty means every site.
  final Set<String> _platforms = {};

  /// Whether a row must hold something playable.
  bool _playableOnly = false;

  /// The list's order; newest first, the way a file manager opens.
  _LibrarySort _sort = _LibrarySort.newest;

  /// List rows, or a grid of covers.
  bool _grid = false;

  /// The days the viewer folded away; a day key, not a title.
  final Set<String> _collapsed = {};

  final Set<String> _selected = {};

  /// A day as the viewer reads it: today and yesterday name themselves, so a
  /// week of takes reads as a calendar. Grouping uses the folder's real name;
  /// only this says it in words.
  String _dayTitle(String day) {
    final t = context.t;
    return recordingTakeOfDay(day).dayTitle(today: t.history.today, yesterday: t.history.yesterday);
  }

  /// The tree this pane owns: every take, cut down to the module's platforms.
  List<RecordingTake> get _all => _scope(ref.read(recordingLibraryProvider).value ?? const []);

  /// Cuts the library down to this module's takes. [RecordingTake.platformId]
  /// falls back to the folder's name for a take whose row is gone, which is the
  /// same string for both sides — so an orphaned channel take still lands on the
  /// IPTV side of the cut.
  List<RecordingTake> _scope(List<RecordingTake> takes) {
    final only = widget.platforms;
    final out = widget.excludedPlatforms;
    if (only.isEmpty && out.isEmpty) return takes;
    return [
      for (final take in takes)
        if ((only.isEmpty || only.contains(take.platformId)) && !out.contains(take.platformId)) take,
    ];
  }

  @override
  void initState() {
    super.initState();
    // The toolbar's word becomes the list's query, after the first frame:
    // a state write in initState is a modification during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final word = ref.read(recorderLibrarySearchHandoffProvider.notifier).take();
      if (word != null && word.isNotEmpty && mounted) setState(() => _query = word);
    });
    ref.listenManual(recorderLibrarySearchHandoffProvider, (_, _) {
      if (!mounted) return;
      final word = ref.read(recorderLibrarySearchHandoffProvider.notifier).take();
      if (word != null && word.isNotEmpty && mounted) setState(() => _query = word);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final library = ref.watch(recordingLibraryProvider);
    final takes = _scope(library.value ?? const <RecordingTake>[]);
    final filtered = _sort.sorted(_filter(takes));
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    final compact = LiveWindow.isCompact(width);
    final root = ref.watch(appPathsProvider).recordings.path;
    final controller = ref.read(recordingLibraryProvider.notifier);
    // The days in the shown order; the grouping never reorders, it follows
    // the sort.
    final daySet = <String>{};
    final days = <String>[
      for (final take in filtered)
        if (daySet.add(take.day)) take.day,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsSearchField(
                      initialValue: _query,
                      onChanged: (value) => setState(() {
                        _query = value;
                        _selected.clear();
                      }),
                      placeholder: t.recorder.librarySearchHint,
                      semanticLabel: t.recorder.librarySearchHint,
                    ),
                  ),
                  DsButton.icon(
                    variant: _platforms.isNotEmpty || _playableOnly
                        ? DsButtonVariant.tinted
                        : DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(_openFilter(takes)),
                    icon: const DsIcon(DsIcons.filter, size: 16),
                    semanticLabel: t.recorder.filterTitle,
                  ),
                  _SortMenu(sort: _sort, onChanged: (value) => setState(() => _sort = value)),
                  DsSegmentedControl<bool>(
                    value: _grid,
                    semanticLabel: t.recorder.viewLabel,
                    segments: [
                      DsSegment(
                        value: false,
                        icon: const DsIcon(DsIcons.layoutList, size: 16),
                        semanticLabel: t.recorder.listView,
                      ),
                      DsSegment(
                        value: true,
                        icon: const DsIcon(DsIcons.layoutGrid, size: 16),
                        semanticLabel: t.recorder.gridView,
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _grid = value;
                      _selected.clear();
                    }),
                  ),
                  if (!compact)
                    DsButton.icon(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => unawaited(openDownloadedPath(context, root)),
                      icon: const DsIcon(DsIcons.folderOpen, size: 16),
                      semanticLabel: t.recorder.openFolder,
                    ),
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: library.isLoading ? null : () => unawaited(controller.refresh()),
                    icon: const DsIcon(DsIcons.refresh, size: 16),
                    semanticLabel: t.recorder.refresh,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: switch ((library.isLoading && takes.isEmpty, library.hasError)) {
            (true, _) => Center(child: DsSpinner(semanticLabel: t.recorder.libraryTitle)),
            (false, true) => Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.trash2),
                title: Text(t.recorder.libraryFailedTitle),
                description: Text(t.recorder.libraryFailedBody(error: '${library.error}')),
                actions: [
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: () => unawaited(controller.refresh()),
                    child: Text(t.recorder.refresh),
                  ),
                ],
              ),
            ),
            (false, false) when filtered.isEmpty => Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.disc3),
                title: Text(takes.isEmpty ? t.recorder.emptyLibraryTitle : t.recorder.emptySearchTitle),
                description: Text(
                  takes.isEmpty ? t.recorder.emptyLibraryDescription : t.recorder.emptySearchDescription,
                ),
                actions: [
                  if (takes.isEmpty)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      onPressed: () => unawaited(openDownloadedPath(context, root)),
                      child: Text(t.recorder.openFolder),
                    ),
                ],
              ),
            ),
            (false, false) => _grid ? _gridBody(filtered, inset) : _listBody(filtered, days, inset),
          },
        ),
        if (_selected.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s8),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                DsCheckbox(
                  value: _selected.length == filtered.length && filtered.isNotEmpty,
                  semanticLabel: t.recorder.selectAll,
                  onChanged: (value) => setState(() {
                    _selected
                      ..clear()
                      ..addAll(value == true ? filtered.map((take) => take.filePath ?? take.folder) : const []);
                  }),
                ),
                Expanded(
                  child: Text(
                    t.recorder.selectedCount(count: _selected.length),
                    style: theme.typography.small.copyWith(color: colors.textMuted),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.dangerSoft,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.trash2, size: 16),
                  onPressed: () => unawaited(_deleteSelectedTakes(filtered)),
                  child: Text(t.recorder.deleteSelected),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The file list: one collapsible day group after another, each take a
  /// row like a file manager's — cover, name, facts, state, actions.
  Widget _listBody(List<RecordingTake> filtered, List<String> days, double inset) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayTakes = [
          for (final take in filtered)
            if (take.day == day) take,
        ];
        final dayBytes = dayTakes.fold<int>(0, (total, take) => total + take.bytes);
        final collapsed = _collapsed.contains(day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.s8),
              child: DsPressable(
                onPressed: () => setState(() {
                  if (collapsed) {
                    _collapsed.remove(day);
                  } else {
                    _collapsed.add(day);
                  }
                }),
                builder: (context, states, _) => Row(
                  spacing: DsSpace.s8,
                  children: [
                    DsIcon(collapsed ? DsIcons.chevronRight : DsIcons.chevronDown, size: 16, color: colors.textMuted),
                    Text(_dayTitle(day), style: theme.typography.bodyStrong.copyWith(color: colors.text)),
                    Text(
                      t.recorder.groupSummary(count: dayTakes.length, size: formatRecordingBytes(dayBytes)),
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (!collapsed)
              for (final take in dayTakes)
                _TakeRow(
                  take: take,
                  selected: _selected,
                  onSelect: _toggle,
                  onPlay: () => _play(take),
                  menu: _takeMenu(take),
                  platformName: widget.platformName,
                ),
          ],
        );
      },
    );
  }

  /// The cover grid: the same takes as cards, two or more across by width.
  Widget _gridBody(List<RecordingTake> filtered, double inset) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200 ? 4 : (width >= 800 ? 3 : 2);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: DsSpace.s12,
        crossAxisSpacing: DsSpace.s12,
        childAspectRatio: 0.82,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final take = filtered[index];
        return _TakeCard(
          take: take,
          selected: _selected.contains(take.filePath ?? take.folder),
          onSelect: () => _toggle(take),
          onPlay: () => _play(take),
          menu: _takeMenu(take),
          platformName: widget.platformName,
        );
      },
    );
  }

  void _toggle(RecordingTake take) => setState(() {
    final key = take.filePath ?? take.folder;
    if (!_selected.remove(key)) _selected.add(key);
  });

  void _play(RecordingTake take) {
    if (!take.playable) {
      showDsToast(context: context, title: context.t.recorder.previewUnavailable);
      return;
    }
    // The run is everything on screen, ordered as the viewer sees it, so the
    // player's next and previous walk the library in its own order.
    widget.onPlay(_sort.sorted(_filter(_all)), take);
  }

  /// The row menu: play, the room, the folder, the path, the delete.
  List<Widget> _takeMenu(RecordingTake take) {
    final t = context.t;
    final task = take.task;
    return [
      if (take.playable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.play),
          label: Text(t.recorder.playRecording),
          onPressed: () => _play(take),
        ),
      if (task != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(widget.openRoomLabel ?? t.recorder.openRoom),
          onPressed: () => widget.onOpenRoom(take),
        ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.folderOpen),
        label: Text(t.recorder.openFolder),
        onPressed: () => unawaited(openDownloadedPath(context, take.folder)),
      ),
      if (take.filePath case final file?)
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.recorder.copyPath),
          onPressed: () => unawaited(_copy(file)),
        ),
      const DsMenuDivider(),
      DsMenuItem(
        leading: const DsIcon(DsIcons.trash2),
        label: Text(t.recorder.delete),
        destructive: true,
        onPressed: () => unawaited(_confirmDeleteTake(take)),
      ),
    ];
  }

  // -- state helpers --------------------------------------------------------

  /// The takes on screen: searched, filtered.
  List<RecordingTake> _filter(List<RecordingTake> takes) {
    final query = _query.trim().toLowerCase();
    final platformName = widget.platformName;
    return [
      for (final take in takes)
        if ((_platforms.isEmpty || _platforms.contains(take.platformId)) &&
            (!_playableOnly || take.playable) &&
            (query.isEmpty ||
                take.roomTitle.toLowerCase().contains(query) ||
                take.name.toLowerCase().contains(query) ||
                _dayTitle(take.day).contains(query) ||
                take.day.contains(query) ||
                platformName(take.platformId).toLowerCase().contains(query)))
          take,
    ];
  }

  // -- actions --------------------------------------------------------------

  Future<void> _confirmDeleteTake(RecordingTake take) async {
    final t = context.t;
    final ok = await showDsConfirm(
      context: context,
      title: t.recorder.deleteTakeTitle(name: take.name),
      description: t.recorder.deleteTakeBody(count: 1),
      confirmLabel: t.recorder.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final removed = await _deleteAll([take]);
    if (!mounted) return;
    setState(() => _selected.remove(take.filePath ?? take.folder));
    showDsToast(
      context: context,
      title: removed == 0 ? t.recorder.deleteBlocked : t.recorder.deletedToast(count: removed),
    );
    // The take's row stays and says its file is gone; re-reading the store is
    // what puts that on the task card.
    unawaited(ref.read(recordingTasksProvider.notifier).reload());
  }

  Future<void> _deleteSelectedTakes(List<RecordingTake> filtered) async {
    final picked = [
      for (final take in filtered)
        if (_selected.contains(take.filePath ?? take.folder)) take,
    ];
    final removed = await _deleteAll(picked);
    if (!mounted) return;
    setState(_selected.clear);
    showDsToast(
      context: context,
      title: removed == 0 ? context.t.recorder.deleteBlocked : context.t.recorder.deletedToast(count: removed),
    );
    if (removed > 0) unawaited(ref.read(recordingTasksProvider.notifier).reload());
  }

  /// Deletes each take folder, skipping any the engine is still writing or
  /// joining; the answer is how many actually went.
  ///
  /// A take that had a task row is marked 文件已删除 on the way out. Without
  /// that the row would stop being the page's business (a saved row with a path
  /// is the library's) while the library had nothing left to show for it — and
  /// the recording would vanish from both lists with no way back to it.
  Future<int> _deleteAll(List<RecordingTake> takes) async {
    final controller = ref.read(recordingLibraryProvider.notifier);
    final store = ref.read(recordingTasksProvider.notifier);
    var removed = 0;
    for (final take in takes) {
      if (!await controller.deleteTake(take)) continue;
      removed++;
      final row = take.task;
      if (row == null) continue;
      await store.setStopped(row.id, filePath: row.takeDirectory, bytes: 0, warning: kRecordingFileDeletedWarning);
    }
    return removed;
  }

  Future<void> _copy(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    showDsToast(context: context, title: context.t.common.copied);
  }

  Future<void> _openFilter(List<RecordingTake> takes) async {
    final t = context.t;
    final sites = {for (final take in takes) take.platformId: widget.platformName(take.platformId)}.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final picked = {..._platforms};
    var playable = _playableOnly;
    void apply() => setState(() {
      _platforms
        ..clear()
        ..addAll(picked);
      _playableOnly = playable;
      _selected.clear();
    });
    await showDsPanel<void>(
      context: context,
      builder: (panelContext) => DsPanel(
        title: Text(t.recorder.filterTitle),
        child: DsListSection(
          children: [
            for (final site in sites)
              DsListRow(
                title: Text(site.value),
                trailing: DsCheckbox(
                  value: picked.contains(site.key),
                  onChanged: (value) {
                    if (value == true) {
                      picked.add(site.key);
                    } else {
                      picked.remove(site.key);
                    }
                    apply();
                  },
                ),
              ),
            DsListRow(
              title: Text(t.recorder.filterPlayable),
              trailing: DsSwitch(
                value: playable,
                onChanged: (value) {
                  playable = value;
                  apply();
                },
              ),
            ),
            DsListRow(
              title: Text(t.recorder.reset),
              onPressed: () {
                picked.clear();
                playable = false;
                apply();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays a library take in the app's own player, over the run the pane was
/// showing.
///
/// Both recording centres — the live one and the IPTV one — come through here,
/// so the caption a list row shows, the order the player walks and what a
/// delete inside the player does to the module's own records are one behaviour
/// rather than two copies that drift apart. A file the viewer deletes from the
/// player marks its task row file-deleted and re-reads the tree.
Future<void> playRecordingTake(
  BuildContext context,
  WidgetRef ref, {
  required List<RecordingTake> around,
  required RecordingTake take,
  required String Function(String platformId) platformName,
}) async {
  final t = context.t;
  final root = ref.read(appPathsProvider).recordings.path;
  final items = <MediaPreviewItem>[];
  for (final candidate in around) {
    final file = candidate.filePath;
    if (!candidate.playable || file == null || file.isEmpty) continue;
    items.add(
      MediaPreviewItem(
        id: file,
        title: candidate.roomTitle,
        path: file,
        groupPath: p.join(root, candidate.day, candidate.platformFolder, candidate.roomFolder),
        groupLabel: [
          candidate.dayTitle(today: t.history.today, yesterday: t.history.yesterday),
          platformName(candidate.platformId),
          candidate.roomTitle,
        ].join(' · '),
        subtitle: [
          platformName(candidate.platformId),
          if (candidate.duration case final duration?) formatRecordingDuration(duration),
          if (candidate.bytes > 0) formatRecordingBytes(candidate.bytes),
          formatRecordingMoment(candidate.takenAt),
        ].where((part) => part.trim().isNotEmpty).join(' · '),
      ),
    );
  }
  final index = items.indexWhere((item) => item.path == take.filePath);
  if (index < 0) {
    showDsToast(context: context, title: t.recorder.previewUnavailable, status: DsStatus.warning);
    return;
  }
  await openMediaPreview(
    context,
    title: t.recorder.previewTitle,
    items: items,
    initialIndex: index,
    onDeleted: (item) async {
      final takes = ref.read(recordingLibraryProvider).value ?? const <RecordingTake>[];
      final row = takes.where((candidate) => candidate.filePath == item.path).firstOrNull?.task;
      if (row != null) {
        await ref
            .read(recordingTasksProvider.notifier)
            .setStopped(row.id, filePath: row.takeDirectory, bytes: 0, warning: kRecordingFileDeletedWarning);
      }
      await ref.read(recordingLibraryProvider.notifier).refresh();
    },
  );
}

/// The list's orders; the file manager's sort menu.
enum _LibrarySort {
  newest,
  oldest,
  name,
  size,
  duration;

  /// The takes in this order. A take without a stamp sorts as the oldest
  /// thing on disk, a file-name order reads case-blind.
  List<RecordingTake> sorted(List<RecordingTake> takes) {
    int byName(RecordingTake a, RecordingTake b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return switch (this) {
      _LibrarySort.newest => takes..sort((a, b) => b.takenAt.compareTo(a.takenAt)),
      _LibrarySort.oldest => takes..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
      _LibrarySort.name => takes..sort(byName),
      _LibrarySort.size => takes..sort((a, b) => b.bytes.compareTo(a.bytes)),
      _LibrarySort.duration =>
        takes..sort((a, b) => (b.duration?.inMilliseconds ?? 0).compareTo(a.duration?.inMilliseconds ?? 0)),
    };
  }
}

/// The sort menu: one checked order, the label carrying the active one.
final class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});

  final _LibrarySort sort;
  final ValueChanged<_LibrarySort> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsMenuAnchor(
      align: DsAlign.end,
      semanticLabel: t.recorder.sortLabel,
      items: [
        for (final order in _LibrarySort.values)
          DsMenuItem(
            label: Text(switch (order) {
              _LibrarySort.newest => t.recorder.sortNewest,
              _LibrarySort.oldest => t.recorder.sortOldest,
              _LibrarySort.name => t.recorder.sortName,
              _LibrarySort.size => t.recorder.sortSize,
              _LibrarySort.duration => t.recorder.sortDuration,
            }),
            checked: order == sort,
            onPressed: () => onChanged(order),
          ),
      ],
      builder: (context, controller, _) => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        trailing: const DsIcon(DsIcons.chevronDown, size: 14),
        onPressed: controller.toggle,
        child: Text(switch (sort) {
          _LibrarySort.newest => t.recorder.sortNewest,
          _LibrarySort.oldest => t.recorder.sortOldest,
          _LibrarySort.name => t.recorder.sortName,
          _LibrarySort.size => t.recorder.sortSize,
          _LibrarySort.duration => t.recorder.sortDuration,
        }),
      ),
    );
  }
}

/// One take as the file manager draws it: the cover tile with its duration,
/// the platform · title line, the facts line, the state's badge, and the
/// play / folder / menu actions.
final class _TakeRow extends StatelessWidget {
  const _TakeRow({
    required this.take,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
    required this.menu,
    required this.platformName,
  });

  final RecordingTake take;
  final Set<String> selected;
  final ValueChanged<RecordingTake> onSelect;
  final VoidCallback onPlay;
  final List<Widget> menu;
  final String Function(String platformId) platformName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final key = take.filePath ?? take.folder;
    final name = take.roomTitle.trim().isNotEmpty ? take.roomTitle.trim() : take.name;
    final duration = take.duration;
    final ok = take.playable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: DsCard(
        onPressed: onPlay,
        style: DsCardStyle(
          padding: const EdgeInsets.all(DsSpace.s8),
          borderRadius: BorderRadius.circular(theme.radii.card),
        ),
        child: Row(
          spacing: DsSpace.s12,
          children: [
            DsCheckbox(value: selected.contains(key), semanticLabel: name, onChanged: (_) => onSelect(take)),
            SizedBox(
              width: 96,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(6)),
                child: Stack(
                  children: [
                    Center(child: DsIcon(DsIcons.video, size: 20, color: colors.accentText)),
                    if (duration != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xB3000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            child: Text(
                              formatRecordingDuration(duration),
                              style: theme.typography.overline.copyWith(color: const Color(0xFFFFFFFF)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    '${platformName(take.platformId)} · $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  Text(
                    [
                      formatRecordingMoment(take.takenAt),
                      if (take.bytes > 0) formatRecordingBytes(take.bytes),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            DsBadge(
              label: Text(ok ? t.recorder.stateSaved : t.recorder.stateUnplayable),
              status: ok ? DsStatus.success : DsStatus.neutral,
            ),
            DsButton(
              variant: DsButtonVariant.primary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.play, size: 14),
              onPressed: ok ? onPlay : null,
              child: Text(t.recorder.playRecording),
            ),
            DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(openDownloadedPath(context, take.folder)),
              icon: const DsIcon(DsIcons.folderOpen, size: 16),
              semanticLabel: t.recorder.openFolder,
            ),
            DsMenuAnchor(
              align: DsAlign.end,
              semanticLabel: t.recorder.menuMore,
              items: menu,
              builder: (context, controller, _) => DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: controller.toggle,
                icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
                semanticLabel: t.recorder.menuMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One take as a cover card for the grid: the tile over the name, the
/// facts under it, and the same actions as the row.
final class _TakeCard extends StatelessWidget {
  const _TakeCard({
    required this.take,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
    required this.menu,
    required this.platformName,
  });

  final RecordingTake take;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPlay;
  final List<Widget> menu;
  final String Function(String platformId) platformName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final name = take.roomTitle.trim().isNotEmpty ? take.roomTitle.trim() : take.name;
    final duration = take.duration;
    final ok = take.playable;
    return DsCard(
      onPressed: onPlay,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentTint,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(theme.radii.card),
                      topRight: Radius.circular(theme.radii.card),
                    ),
                  ),
                  child: Center(child: DsIcon(DsIcons.video, size: 28, color: colors.accentText)),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: DsCheckbox(value: selected, semanticLabel: name, onChanged: (_) => onSelect()),
              ),
              if (duration != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        formatRecordingDuration(duration),
                        style: theme.typography.overline.copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                Text(
                  [
                    platformName(take.platformId),
                    formatRecordingMoment(take.takenAt),
                    if (take.bytes > 0) formatRecordingBytes(take.bytes),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
                Row(
                  spacing: DsSpace.s4,
                  children: [
                    DsBadge(
                      label: Text(ok ? t.recorder.stateSaved : t.recorder.stateUnplayable),
                      status: ok ? DsStatus.success : DsStatus.neutral,
                    ),
                    const Spacer(),
                    DsMenuAnchor(
                      align: DsAlign.end,
                      semanticLabel: t.recorder.menuMore,
                      items: menu,
                      builder: (context, controller, _) => DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        onPressed: controller.toggle,
                        icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
                        semanticLabel: t.recorder.menuMore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
