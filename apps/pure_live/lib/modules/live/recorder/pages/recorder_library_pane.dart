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
  /// The drilled folders: a day, then a platform, then a room.
  List<String> _path = [];

  /// What the search box holds; matched against room, platform, day and file.
  String _query = '';

  /// Only the sites ticked in the panel; empty means every site.
  final Set<String> _platforms = {};

  /// Whether a row must hold something playable.
  bool _playableOnly = false;

  /// Browsed folders, or the whole library as one flat list of takes.
  bool _flat = false;

  DsTableSort? _sort;

  final Set<Object> _selected = {};

  /// The levels the drill-down answers, in the tree's own order.
  static const List<RecordingBrowseLevel> _levels = [
    RecordingBrowseLevel.day,
    RecordingBrowseLevel.platform,
    RecordingBrowseLevel.room,
    RecordingBrowseLevel.take,
  ];

  /// A day as the viewer reads it: today and yesterday name themselves, so a
  /// week of takes reads as a calendar. Grouping and drilling use the folder's
  /// real name; only this says it in words.
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

  String get _rootPath => ref.read(appPathsProvider).recordings.path;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final library = ref.watch(recordingLibraryProvider);
    final takes = _scope(library.value ?? const <RecordingTake>[]);
    final filtered = _filter(takes);
    final level = _flat ? RecordingBrowseLevel.take : _levels[_path.length.clamp(0, _levels.length - 1)];
    final entries = recordingEntriesFor(
      takesUnder(filtered, _flat ? const [] : _path),
      level,
      platformLabel: (take) => widget.platformName(take.platformId),
      dayTitle: _dayTitle,
    );
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    final compact = LiveWindow.isCompact(width);
    final root = ref.watch(appPathsProvider).recordings.path;
    final controller = ref.read(recordingLibraryProvider.notifier);
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
                spacing: DsSpace.s12,
                children: [
                  if (widget.showHeading)
                    Expanded(
                      child: Text(t.recorder.libraryTitle, style: theme.typography.title.copyWith(color: colors.text)),
                    ),
                  // One line says what is here and names the folder it lives in,
                  // which is what the folder button then opens.
                  if (!compact)
                    Flexible(
                      child: Text(
                        '${t.recorder.librarySummary(count: filtered.length, size: formatRecordingBytes(_bytesOf(filtered)))} · $root',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.typography.small.copyWith(color: colors.textSubtle),
                      ),
                    ),
                  _Toolbar(
                    compact: compact,
                    query: _query,
                    onQuery: (value) => setState(() {
                      _query = value;
                      _selected.clear();
                    }),
                    onFilter: () => unawaited(_openFilter(takes)),
                    filterActive: _platforms.isNotEmpty || _playableOnly,
                    flat: _flat,
                    onView: (value) => setState(() {
                      _flat = value;
                      _selected.clear();
                    }),
                    onReveal: () => unawaited(openDownloadedPath(context, root)),
                    onRefresh: () => unawaited(controller.refresh()),
                    loading: library.isLoading,
                  ),
                ],
              ),
              if (!_flat) _breadcrumb(level, entries.length),
              if (_selected.isNotEmpty)
                Row(
                  spacing: DsSpace.s8,
                  children: [
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
                      onPressed: () => unawaited(_deleteSelected(entries)),
                      child: Text(t.recorder.deleteSelected),
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
            (false, false) => Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
              child: _table(entries, level),
            ),
          },
        ),
      ],
    );
  }

  /// The drilled path as pressable crumbs, ending where the viewer stands.
  Widget _breadcrumb(RecordingBrowseLevel level, int shown) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    Widget crumb(String label, {required bool current, VoidCallback? onPressed}) => DsButton(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      onPressed: onPressed,
      child: Text(
        label,
        style: theme.typography.small.copyWith(
          color: current ? colors.text : colors.accent,
          fontWeight: current ? FontWeight.w600 : null,
        ),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          crumb(
            t.recorder.libraryRoot,
            current: _path.isEmpty,
            onPressed: _path.isEmpty ? null : () => _drill(const []),
          ),
          for (var depth = 0; depth < _path.length; depth++) ...[
            DsIcon(DsIcons.chevronRight, size: 14, color: colors.textSubtle),
            crumb(
              _crumbLabel(depth),
              current: depth == _path.length - 1 && level != RecordingBrowseLevel.take,
              onPressed: depth == _path.length - 1 && level != RecordingBrowseLevel.take
                  ? null
                  : () => _drill(_path.sublist(0, depth + 1)),
            ),
          ],
          if (level == RecordingBrowseLevel.take && _path.isNotEmpty) ...[
            DsIcon(DsIcons.chevronRight, size: 14, color: colors.textSubtle),
            Text(
              t.recorder.takesShown(count: shown),
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ],
        ],
      ),
    );
  }

  /// A crumb's text: a day says it in words; a platform and a room use the
  /// names the app can give them, because the folder names are the recorder's
  /// safe spelling of an id the viewer never typed.
  String _crumbLabel(int depth) {
    if (depth == 0) return _dayTitle(_path.first);
    final under = takesUnder(_filter(_all), _path.sublist(0, depth + 1));
    if (under.isEmpty) return _path[depth].replaceAll('_', ' ');
    final take = under.first;
    return depth == 1 ? widget.platformName(take.platformId) : take.roomTitle;
  }

  Widget _table(List<RecordingEntry> entries, RecordingBrowseLevel level) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final leaf = level == RecordingBrowseLevel.take;
    final columns = <DsTableColumn<RecordingEntry>>[
      DsTableColumn(
        id: 'name',
        label: leaf ? t.recorder.columnFile : t.recorder.columnName,
        sortable: true,
        value: (entry) => entry.label,
        width: const DsTableColumnWidth.flex(3, 160),
        // A folder row counts what is inside it under its name; a take row says
        // which room it came from, which its own file name never tells.
        cell: (context, entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (entry.sublabel.isNotEmpty)
              Text(
                entry.unplayable ? '${entry.sublabel} · ${t.recorder.stateUnplayable}' : entry.sublabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(color: theme.colors.textSubtle),
              ),
          ],
        ),
      ),
      if (!leaf)
        DsTableColumn(
          id: 'count',
          label: t.recorder.columnCount,
          numeric: true,
          sortable: true,
          value: (entry) => '${entry.takeCount}',
          comparator: (a, b) => a.takeCount.compareTo(b.takeCount),
          width: const DsTableColumnWidth.intrinsic(min: 64),
        ),
      if (leaf)
        DsTableColumn(
          id: 'duration',
          label: t.recorder.columnDuration,
          numeric: true,
          sortable: true,
          value: (entry) {
            final duration = entry.take?.duration;
            return duration == null ? '--:--' : formatRecordingDuration(duration);
          },
          width: const DsTableColumnWidth.intrinsic(min: 72),
        ),
      DsTableColumn(
        id: 'size',
        label: t.recorder.columnSize,
        numeric: true,
        sortable: true,
        value: (entry) => formatRecordingBytes(entry.bytes),
        comparator: (a, b) => a.bytes.compareTo(b.bytes),
        width: const DsTableColumnWidth.intrinsic(min: 88),
      ),
      DsTableColumn(
        id: 'time',
        label: t.recorder.columnTime,
        sortable: true,
        value: (entry) => entry.takenAt == null ? '' : formatRecordingMoment(entry.takenAt!),
        comparator: (a, b) => (a.takenAt ?? DateTime(1970)).compareTo(b.takenAt ?? DateTime(1970)),
        width: const DsTableColumnWidth.intrinsic(min: 96),
      ),
    ];
    return DsTable<RecordingEntry>(
      columns: columns,
      rows: entries,
      rowKey: (entry) => entry.groupKey,
      rowsVersion:
          '${_path.join('|')}-$_flat-$_query-${_platforms.length}-$_playableOnly-${entries.length}-${_bytesOf(entries.map((entry) => entry.take).whereType<RecordingTake>().toList())}',
      sort: _sort,
      onSortChanged: (value) => setState(() => _sort = value),
      selected: _selected,
      onSelectionChanged: (value) => setState(() {
        _selected
          ..clear()
          ..addAll(value);
      }),
      // A take plays; a folder walks in. The room a take came from is a menu
      // step, never the row's press — the row is the recording.
      onRowPressed: _press,
      rowMenuBuilder: (context, entry) => _menu(entry),
      showRowMenuButton: true,
      semanticLabel: t.recorder.libraryTitle,
    );
  }

  void _drill(List<String> path) => setState(() {
    _path = List.of(path);
    _selected.clear();
  });

  void _press(RecordingEntry entry) {
    if (!entry.isLeaf) {
      _drill(entry.segments);
      return;
    }
    final take = entry.take;
    if (take == null) return;
    if (!take.playable) {
      showDsToast(context: context, title: context.t.recorder.previewUnavailable);
      return;
    }
    // The run is everything on screen, ordered as the viewer sees it, so the
    // player's next and previous walk the library and its list can group by the
    // folders the recorder filed the takes into.
    widget.onPlay(_filter(_all), take);
  }

  List<Widget> _menu(RecordingEntry entry) {
    final t = context.t;
    final takes = _takesOf(entry);
    final first = takes.isEmpty ? null : takes.first;
    final task = entry.task ?? first?.task;
    return [
      if (entry.isLeaf && first != null && first.playable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.play),
          label: Text(t.recorder.playRecording),
          onPressed: () => _press(entry),
        ),
      if (!entry.isLeaf)
        DsMenuItem(
          leading: const DsIcon(DsIcons.chevronRight),
          label: Text(t.recorder.enterFolder),
          onPressed: () => _press(entry),
        ),
      // A hand-dropped file the store never made a row for has no room to open.
      if (task != null && first != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(widget.openRoomLabel ?? t.recorder.openRoom),
          onPressed: () => widget.onOpenRoom(first),
        ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.folderOpen),
        label: Text(t.recorder.openFolder),
        onPressed: () => unawaited(openDownloadedPath(context, _folderOf(entry, takes))),
      ),
      if (first?.filePath case final file?)
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.recorder.copyPath),
          onPressed: () => unawaited(_copy(file)),
        ),
      const DsMenuDivider(),
      DsMenuItem(
        leading: const DsIcon(DsIcons.trash2),
        label: Text(entry.isLeaf ? t.recorder.delete : t.recorder.deleteHere),
        destructive: true,
        onPressed: () => unawaited(_confirmDelete(entry, takes)),
      ),
    ];
  }

  // -- state helpers -------------------------------------------------------

  /// The takes on screen: searched, filtered, drilled to here.
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

  /// The takes a row stands for: the one take, or everything inside the folder.
  List<RecordingTake> _takesOf(RecordingEntry entry) => takesUnder(_filter(_all), entry.segments);

  /// The folder a row's "open the folder" answers with: the take's own folder,
  /// or the folder the group row gathered.
  String _folderOf(RecordingEntry entry, List<RecordingTake> takes) {
    if (entry.isLeaf) return takes.isEmpty ? _rootPath : takes.first.folder;
    if (takes.isEmpty) return _rootPath;
    if (entry.segments.isEmpty) return _rootPath;
    return p.joinAll([_rootPath, ...entry.segments.take(entry.level.index + 1)]);
  }

  int _bytesOf(List<RecordingTake> takes) => takes.fold(0, (total, take) => total + take.bytes);

  // -- actions -------------------------------------------------------------

  Future<void> _confirmDelete(RecordingEntry entry, List<RecordingTake> takes) async {
    final t = context.t;
    final single = takes.length == 1 ? takes.first : null;
    final ok = await showDsConfirm(
      context: context,
      title: single == null
          ? t.recorder.deleteHereTitle(name: entry.label)
          : t.recorder.deleteTakeTitle(name: single.name),
      description: t.recorder.deleteTakeBody(count: takes.length),
      confirmLabel: t.recorder.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final removed = await _deleteAll(takes);
    if (!mounted) return;
    setState(() => _selected.remove(entry.groupKey));
    showDsToast(
      context: context,
      title: removed == 0 ? t.recorder.deleteBlocked : t.recorder.deletedToast(count: removed),
    );
    // The take's row stays and says its file is gone; re-reading the store is
    // what puts that on the task card.
    unawaited(ref.read(recordingTasksProvider.notifier).reload());
  }

  Future<int> _deleteSelected(List<RecordingEntry> entries) async {
    final picked = <RecordingTake>[];
    for (final entry in entries) {
      if (_selected.contains(entry.groupKey)) picked.addAll(_takesOf(entry));
    }
    final removed = await _deleteAll(picked);
    if (!mounted) return removed;
    setState(_selected.clear);
    showDsToast(
      context: context,
      title: removed == 0 ? context.t.recorder.deleteBlocked : context.t.recorder.deletedToast(count: removed),
    );
    if (removed > 0) unawaited(ref.read(recordingTasksProvider.notifier).reload());
    return removed;
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
/// player marks its task row file-deleted and re-reads the tree: the row keeps
/// naming the take's folder, so 打开文件夹 still reaches whatever is left beside
/// it, and the task strip — where a row like that stays listed — is the one
/// place it can still be handled.
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
        // The list groups by the folder the recorder filed the take into, and
        // names it the way the breadcrumb does — day, platform, room — so the
        // run reads as the tree rather than as a queue.
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

/// The library's controls in one row: search, filter, the view switch, the
/// folder and a refresh. On a narrow window only the search box and the
/// overflow menu stay, as on every other toolbar in the app.
final class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.compact,
    required this.query,
    required this.onQuery,
    required this.onFilter,
    required this.filterActive,
    required this.flat,
    required this.onView,
    required this.onReveal,
    required this.onRefresh,
    required this.loading,
  });

  final bool compact;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onFilter;
  final bool filterActive;
  final bool flat;
  final ValueChanged<bool> onView;
  final VoidCallback onReveal;
  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final search = SizedBox(
      width: compact ? 132 : 220,
      child: DsSearchField(
        initialValue: query,
        onChanged: onQuery,
        placeholder: t.recorder.librarySearchHint,
        semanticLabel: t.recorder.librarySearchHint,
      ),
    );
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          search,
          DsMenuAnchor(
            align: DsAlign.end,
            semanticLabel: t.recorder.filterLabel,
            items: [
              DsMenuItem(
                leading: const DsIcon(DsIcons.filter),
                label: Text(t.recorder.filterTitle),
                trailing: filterActive ? const DsIcon(DsIcons.check, size: 14) : null,
                onPressed: onFilter,
              ),
              DsMenuItem(
                leading: const DsIcon(DsIcons.folderOpen),
                label: Text(t.recorder.openFolder),
                onPressed: onReveal,
              ),
              DsMenuItem(
                leading: const DsIcon(DsIcons.refresh),
                label: Text(t.recorder.refresh),
                onPressed: loading ? null : onRefresh,
              ),
              const DsMenuDivider(),
              DsMenuItem(
                leading: DsIcon(flat ? DsIcons.check : DsIcons.circle),
                label: Text(t.recorder.allView),
                onPressed: () => onView(true),
              ),
              DsMenuItem(
                leading: DsIcon(!flat ? DsIcons.check : DsIcons.circle),
                label: Text(t.recorder.folderView),
                onPressed: () => onView(false),
              ),
            ],
            builder: (context, controller, _) => DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              onPressed: controller.toggle,
              icon: const DsIcon(DsIcons.ellipsisVertical),
              semanticLabel: t.recorder.filterLabel,
            ),
          ),
        ],
      );
    }
    return Row(
      spacing: DsSpace.s4,
      children: [
        search,
        DsButton.icon(
          variant: filterActive ? DsButtonVariant.tinted : DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: onFilter,
          icon: const DsIcon(DsIcons.filter),
          semanticLabel: t.recorder.filterTitle,
        ),
        DsSegmentedControl<bool>(
          value: flat,
          semanticLabel: t.recorder.viewLabel,
          segments: [
            DsSegment(value: false, label: Text(t.recorder.folderView)),
            DsSegment(value: true, label: Text(t.recorder.allView)),
          ],
          onChanged: onView,
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: onReveal,
          icon: const DsIcon(DsIcons.folderOpen),
          semanticLabel: t.recorder.openFolder,
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: loading ? null : onRefresh,
          icon: const DsIcon(DsIcons.refresh),
          semanticLabel: t.recorder.refresh,
        ),
      ],
    );
  }
}
