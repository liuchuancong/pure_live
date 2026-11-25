import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart' show appPathsProvider, sitesProvider;
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/media_preview/media_preview_page.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/data/recorder_library_filter.dart'
    show RecorderLibrarySort, recorderLibraryFilterProvider, scopeLibraryTakes;
import 'package:pure_live/modules/live/recorder/data/recorder_platform_filter.dart';
import 'package:pure_live/modules/live/recorder/data/recording_covers.dart' show recordingCoversProvider;
import 'package:pure_live/modules/live/recorder/data/recording_library.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart'
    show formatRecordingBytes, formatRecordingDuration, formatRecordingMoment;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart'
    show RecordingTaskState, kRecordingFileDeletedWarning;
import 'package:pure_live/modules/live/recorder/pages/recorder_card_parts.dart';
import 'package:pure_live/shared/shared.dart'
    show
        LiveWindow,
        SkeletonRows,
        avatarInitials,
        cachedImage,
        kAllPlatforms,
        localizedSiteIcon,
        showActionsPanel,
        showPlatformPickerPanel;
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// The library's inline search word, shared by the pane and the toolbar that
/// may sit in its host page's header.
final recorderLibrarySearchProvider = NotifierProvider<RecorderLibrarySearchController, String>(
  RecorderLibrarySearchController.new,
);

final class RecorderLibrarySearchController extends Notifier<String> {
  @override
  String build() => '';

  /// Narrows the library to [word]; an empty word returns to every take.
  void search(String word) => state = word.trim();

  /// Returns to every take.
  void clear() => state = '';
}

/// Whether a take answers the search by facts already in the model: its title,
/// anchor, site, room and file/folder names. Every word must match, so a title
/// and site can be combined without another filter control.
bool recordingTakeMatchesQuery(RecordingTake take, String query, String Function(String platformId) platformName) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  if (words.isEmpty) return true;
  final fields = [
    take.roomTitle,
    take.task?.anchorName ?? '',
    take.platformId,
    platformName(take.platformId),
    take.roomId,
    take.name,
    take.platformFolder,
    take.roomFolder,
    take.folder,
    take.filePath ?? '',
  ].join('\n').toLowerCase();
  return words.every(fields.contains);
}

/// The recording library: the takes on disk, browsed the way the recorder
/// filed them — one day after another, the way a drive client reads a folder.
///
/// It walks the folder tree rather than the task store because the store keys a
/// row by `platform:roomId`: a room recorded twice keeps one row and hides its
/// other take, though the file sits on disk. So pressing a row plays the
/// recording it names, and the room it came from is one menu step away.
///
/// The library's conditions — the site, whether a row must play, the order —
/// are the page's view state rather than this widget's: [RecorderLibraryToolbar]
/// edits them wherever the host page places it, and this pane obeys them.
final class RecorderLibraryPane extends ConsumerStatefulWidget {
  const RecorderLibraryPane({
    required this.onPlay,
    required this.onOpenRoom,
    required this.platformName,
    this.platforms = const {},
    this.excludedPlatforms = const {},
    this.filterByPlatform = true,
    this.emptyDescription,
    this.openRoomLabel,
    this.showHeading = true,
    this.showToolbar = true,
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

  /// Whether the centre's shared platform filter also cuts this pane.
  final bool filterByPlatform;

  /// The empty file list's own explanation when a module scopes the tree.
  final String? emptyDescription;

  /// The card's word for going to where the take was made. The live centre
  /// says 进入直播间; a module whose rooms are channels says its own, and the
  /// library has no opinion — null falls back to the recorder's wording.
  final String? openRoomLabel;

  /// Whether the pane draws its own heading. Embedded under a page that already
  /// has one — the recording centre, which keeps its title and its filter chips
  /// — the heading would say the same thing twice, and only the toolbar shows.
  final bool showHeading;

  /// Whether the pane carries the library's own toolbar. A page that puts the
  /// toolbar on its header line — the recording centre, beside the tasks/files
  /// switch — passes false and renders [RecorderLibraryToolbar] itself, so the
  /// conditions sit one row above the list instead of forming a second band
  /// under it.
  final bool showToolbar;

  @override
  ConsumerState<RecorderLibraryPane> createState() => _RecorderLibraryPaneState();
}

final class _RecorderLibraryPaneState extends ConsumerState<RecorderLibraryPane> {
  /// How many takes one file page holds.
  static const int _pageSize = 30;

  /// The file list's shown page; a new platform or order starts it again.
  int _page = 1;
  String _pageKey = '';

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

  /// The tree this pane owns: every take, cut down to the module's platforms
  /// and to the centre's platform filter.
  List<RecordingTake> get _all {
    final scoped = scopeLibraryTakes(
      ref.read(recordingLibraryProvider).value ?? const [],
      platforms: widget.platforms,
      excluded: widget.excludedPlatforms,
    );
    return _cutPlatforms(scoped, ref.read(recorderPlatformFilterProvider));
  }

  List<RecordingTake> _cutPlatforms(List<RecordingTake> scoped, String filter) {
    if (!widget.filterByPlatform || filter == kAllPlatforms) return scoped;
    return [
      for (final take in scoped)
        if (take.platformId == filter) take,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final library = ref.watch(recordingLibraryProvider);
    final scoped = scopeLibraryTakes(
      library.value ?? const <RecordingTake>[],
      platforms: widget.platforms,
      excluded: widget.excludedPlatforms,
    );
    // The centre's platform filter cuts both lists the same way.
    final platformFilter = ref.watch(recorderPlatformFilterProvider);
    final takes = _cutPlatforms(scoped, platformFilter);
    final query = ref.watch(recorderLibrarySearchProvider);
    final filter = ref.watch(recorderLibraryFilterProvider);
    final filtered = filter.sort.sorted([
      for (final take in takes)
        if (recordingTakeMatchesQuery(take, query, widget.platformName)) take,
    ]);
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    final root = ref.watch(appPathsProvider).recordings.path;
    final controller = ref.read(recordingLibraryProvider.notifier);
    final pageKey =
        '${widget.filterByPlatform ? platformFilter : kAllPlatforms}/${filter.sort.name}/${query.trim().toLowerCase()}';
    if (pageKey != _pageKey) {
      _pageKey = pageKey;
      _page = 1;
      // A selection made under another cut would delete files the viewer can
      // no longer see; a filter change starts both the page and the mark over.
      _selected.clear();
    }
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    final page = _page.clamp(1, pageCount);
    final shown = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();
    final shownKeys = {for (final take in shown) take.filePath ?? take.folder};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Adding a task is the shell's own search above; this page narrows with
        // the filter, and the filter is one entry, not a band of controls.
        if (widget.showToolbar)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: RecorderLibraryToolbar(
                platforms: recorderPlatformsOf(scoped.map((take) => take.platformId), widget.platformName),
                nameOf: widget.platformName,
                showPlatformFilter: widget.filterByPlatform,
              ),
            ),
          ),
        Expanded(
          child: switch ((library.isLoading && takes.isEmpty, library.hasError)) {
            (true, _) => const Padding(padding: EdgeInsets.all(DsSpace.s16), child: SkeletonRows(rows: 7)),
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
                  takes.isEmpty
                      ? widget.emptyDescription ?? t.recorder.emptyLibraryDescription
                      : t.recorder.emptySearchDescription,
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
            (false, false) => _dayGroups(shown, inset),
          },
        ),
        if (filtered.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
            child: Center(
              child: DsPagination(page: page, pageCount: pageCount, onChanged: (next) => setState(() => _page = next)),
            ),
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
                  value: shownKeys.isNotEmpty && shownKeys.every(_selected.contains),
                  semanticLabel: t.recorder.selectAll,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.addAll(shownKeys);
                    } else {
                      _selected.removeAll(shownKeys);
                    }
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

  /// The file list: one day after another, each day opening with its own
  /// header and folding away under it.
  ///
  /// The days are ordinary slivers of one list rather than a
  /// `SliverMainAxisGroup` around a pinned header: the group emits a geometry
  /// whose layout extent exceeds its paint extent once a pinned child sits
  /// inside it, which aborts the viewport's layout and leaves the next pointer
  /// event hit-testing slivers that were never laid out.
  Widget _dayGroups(List<RecordingTake> shown, double inset) {
    final t = context.t;
    final grouped = <String, List<RecordingTake>>{};
    for (final take in shown) {
      grouped.putIfAbsent(take.day, () => <RecordingTake>[]).add(take);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s12),
      child: CustomScrollView(
        slivers: [
          for (final entry in grouped.entries) ...[
            SliverToBoxAdapter(
              child: _DayHeader(
                title: _dayTitle(entry.key),
                summary: t.recorder.groupSummary(
                  count: entry.value.length,
                  size: formatRecordingBytes(entry.value.fold<int>(0, (total, take) => total + take.bytes)),
                ),
                collapsed: _collapsed.contains(entry.key),
                onToggle: () => setState(() {
                  if (!_collapsed.remove(entry.key)) _collapsed.add(entry.key);
                }),
              ),
            ),
            if (!_collapsed.contains(entry.key))
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final take = entry.value[index];
                  return KeyedSubtree(
                    key: ValueKey(take.filePath ?? take.folder),
                    child: _TakeRow(
                      take: take,
                      selected: _selected,
                      onSelect: _toggle,
                      onPlay: () => _play(take),
                      onOpenRoom: take.task == null ? null : () => widget.onOpenRoom(take),
                      onDelete: () => unawaited(_confirmDeleteTake(take)),
                      openRoomLabel: widget.openRoomLabel ?? t.recorder.openRoom,
                      platformName: widget.platformName,
                    ),
                  );
                }, childCount: entry.value.length),
              ),
          ],
        ],
      ),
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
    final filter = ref.read(recorderLibraryFilterProvider);
    final query = ref.read(recorderLibrarySearchProvider);
    widget.onPlay(
      filter.sort.sorted([
        for (final candidate in _all)
          if (recordingTakeMatchesQuery(candidate, query, widget.platformName)) candidate,
      ]),
      take,
    );
  }

  // -- actions --------------------------------------------------------------

  Future<void> _confirmDeleteTake(RecordingTake take) async {
    final t = context.t;
    final ok = await showAppConfirm(
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
    if (picked.isEmpty) return;
    final t = context.t;
    final bytes = picked.fold<int>(0, (total, take) => total + take.bytes);
    final confirmed = await showAppConfirm(
      context: context,
      title: t.common.deleteSelected(count: picked.length),
      description: [
        t.recorder.deleteTakeBody(count: picked.length),
        t.recorder.librarySummary(count: picked.length, size: formatRecordingBytes(bytes)),
        // The cache confirmation already carries the irreversible warning; no
        // second, untranslated warning is introduced for this destructive verb.
        t.recorder.cacheClearConfirmDesc,
      ].join('\n'),
      confirmLabel: t.recorder.deleteSelected,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    // The confirmed snapshot, not the mutable selection, is what is deleted.
    final removed = await _deleteAll(picked);
    if (!mounted) return;
    setState(_selected.clear);
    showDsToast(
      context: context,
      title: removed == 0 ? t.recorder.deleteBlocked : t.recorder.deletedToast(count: removed),
    );
    if (removed > 0) unawaited(ref.read(recordingTasksProvider.notifier).reload());
  }

  /// Deletes each take folder, skipping any the engine is still writing or
  /// joining and any file the current task still owns; the answer is how many
  /// actually went.
  ///
  /// A historical take shares its room's task row with the newest take. Only
  /// that current file may be marked 文件已删除: clearing an older file must not
  /// make the newest recording disappear from the task list as well.
  Future<int> _deleteAll(List<RecordingTake> takes) async {
    final controller = ref.read(recordingLibraryProvider.notifier);
    final store = ref.read(recordingTasksProvider.notifier);
    var removed = 0;
    for (final take in takes) {
      if (!await controller.deleteTake(take)) continue;
      removed++;
      final original = take.task;
      final file = take.filePath;
      if (original == null || file == null) continue;
      final current = ref.read(recordingTasksProvider).tasks.where((task) => task.id == original.id).firstOrNull;
      if (current == null || !current.startedAt.isAtSameMomentAs(original.startedAt)) continue;
      if (!taskOwnsFile(current, file)) continue;
      if (current.state == RecordingTaskState.stopped) {
        await store.setStopped(
          current.id,
          expectedStartedAt: current.startedAt,
          filePath: current.takeDirectory,
          bytes: 0,
          warning: kRecordingFileDeletedWarning,
        );
      } else {
        // A waiting or failed row keeps its own state — only the gone
        // file's record clears, or the card reads 文件已删除 over a
        // subscription that is about to start.
        await store.add(current.copyWith(filePath: current.takeDirectory, bytes: 0));
      }
    }
    return removed;
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
        groupPath: p.join(root, candidate.kind, candidate.day, candidate.platformFolder, candidate.roomFolder),
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
      final row = ref.read(recordingTasksProvider).tasks.where((task) => taskOwnsFile(task, item.path)).firstOrNull;
      // The library can hold several takes for one room. An older file going
      // from the player must not clear the newest take's path or warning.
      if (row != null) {
        await ref
            .read(recordingTasksProvider.notifier)
            .setStopped(
              row.id,
              expectedStartedAt: row.startedAt,
              filePath: row.takeDirectory,
              bytes: 0,
              warning: kRecordingFileDeletedWarning,
            );
      }
      await ref.read(recordingLibraryProvider.notifier).refresh();
    },
  );
}

/// The library's own controls: the order, the folder the takes sit in, and the
/// refresh that walks the tree again.
///
/// A wide window says what each verb does; a small one keeps them as glyphs,
/// the same fold every other page makes when its header line runs out of room.
final class RecorderLibraryToolbar extends ConsumerWidget {
  /// The toolbar over the module's takes; [platforms] feed the platform
  /// filter, named by [nameOf].
  const RecorderLibraryToolbar({
    required this.platforms,
    required this.nameOf,
    this.showPlatformFilter = true,
    super.key,
  });

  /// The site ids the list holds.
  final List<String> platforms;

  /// A site id's display name.
  final String Function(String id) nameOf;

  /// Whether this toolbar offers a platform choice.
  final bool showPlatformFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final library = ref.watch(recordingLibraryProvider);
    final root = ref.watch(appPathsProvider).recordings.path;
    final query = ref.watch(recorderLibrarySearchProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The pane's own width decides the verbs' dress — the window's width
        // includes a sidebar the pane does not get.
        final compact = LiveWindow.isCompact(constraints.maxWidth);
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            DsButton.icon(
              variant: query.isEmpty ? DsButtonVariant.secondary : DsButtonVariant.primary,
              size: DsSize.sm,
              onPressed: () => unawaited(_editLibrarySearch(context, ref)),
              icon: const DsIcon(DsIcons.search, size: 16),
              semanticLabel: t.recorder.searchHint,
            ),
            if (showPlatformFilter)
              RecorderPlatformFilterButton(platforms: platforms, nameOf: nameOf, compact: compact),
            // The order reads straight from this menu: it was the filter's only
            // condition, so a panel in between only added a step.
            DsMenuAnchor(
              semanticLabel: t.recorder.filterLabel,
              align: DsAlign.end,
              items: _sortItems(context, ref),
              builder: (context, menu, _) => compact
                  ? DsButton.icon(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: menu.toggle,
                      icon: const DsIcon(DsIcons.filter, size: 16),
                      semanticLabel: t.recorder.filterLabel,
                    )
                  : DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.filter, size: 14),
                      onPressed: menu.toggle,
                      child: Text(t.recorder.filterLabel),
                    ),
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
              onPressed: library.isLoading
                  ? null
                  : () {
                      // Walking the tree again is also the moment a take that could
                      // not be read last time gets asked again — a file that has
                      // since been joined or finished writing answers now.
                      ref.read(recordingCoversProvider.notifier).resetAttempts();
                      unawaited(ref.read(recordingLibraryProvider.notifier).refresh());
                    },
              icon: const DsIcon(DsIcons.refresh, size: 16),
              semanticLabel: t.recorder.refresh,
            ),
          ],
        );
      },
    );
  }
}

/// Opens the library's text search in the app's own dialog. Keeping the field
/// here leaves the header's verbs on one line; the list narrows in place.
Future<void> _editLibrarySearch(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final search = ref.read(recorderLibrarySearchProvider.notifier);
  final field = TextEditingController(text: ref.read(recorderLibrarySearchProvider));
  var query = field.text;
  await showAppDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(t.recorder.searchHint),
      description: DsTextField(
        controller: field,
        autofocus: true,
        clearable: true,
        placeholder: t.recorder.searchHint,
        semanticLabel: t.recorder.searchHint,
        onChanged: (next) => query = next,
        onSubmitted: (next) {
          query = next;
          Navigator.of(context).pop();
          search.search(query);
        },
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: () {
            Navigator.of(context).pop();
            search.search(query);
          },
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );
  field.dispose();
}

/// The library's verbs folded into one menu for a phone: the order, the folder
/// and the walk-again refresh, so the page switch keeps the header line to
/// itself instead of stacking a second band of buttons under it.
final class RecorderLibraryToolbarMore extends ConsumerWidget {
  /// Creates the compact toolbar; [platforms] feed the platform filter, named
  /// by [nameOf].
  const RecorderLibraryToolbarMore({
    required this.platforms,
    required this.nameOf,
    this.showPlatformFilter = true,
    super.key,
  });

  /// The site ids the list holds.
  final List<String> platforms;

  /// A site id's display name.
  final String Function(String id) nameOf;

  /// Whether this toolbar offers a platform choice.
  final bool showPlatformFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final library = ref.watch(recordingLibraryProvider);
    final root = ref.watch(appPathsProvider).recordings.path;
    final filter = ref.watch(recorderLibraryFilterProvider);
    final query = ref.watch(recorderLibrarySearchProvider);
    final controller = ref.read(recorderLibraryFilterProvider.notifier);
    return DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.common.more,
      leading: const DsIcon(DsIcons.chevronDown, size: 14),
      child: Text(t.common.more),
      onPressed: () => unawaited(
        showActionsPanel(
          context,
          title: t.common.more,
          children: [
            DsListSection(
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.search, size: 16),
                  title: Text(t.recorder.searchHint),
                  detail: query.isEmpty ? null : Text(query),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(_editLibrarySearch(context, ref));
                  },
                ),
              ],
            ),
            if (showPlatformFilter)
              DsListSection(
                children: [
                  DsListRow(
                    leading: const DsIcon(DsIcons.antenna, size: 16),
                    title: Text(t.recorder.filterPlatformGroup),
                    detail: Text(switch (ref.watch(recorderPlatformFilterProvider)) {
                      final id when id != kAllPlatforms => nameOf(id),
                      _ => t.recorder.filterAll,
                    }),
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(
                        showPlatformPickerPanel(
                          context,
                          platforms: [kAllPlatforms, ...platforms],
                          current: ref.read(recorderPlatformFilterProvider),
                          nameOf: (id) => id == kAllPlatforms ? t.recorder.filterAll : nameOf(id),
                          iconOf: (id) => id == kAllPlatforms
                              ? null
                              : localizedSiteIcon(ref.read(sitesProvider).getById(id), size: 32),
                          onChanged: (id) => ref.read(recorderPlatformFilterProvider.notifier).selected = id,
                        ),
                      );
                    },
                  ),
                ],
              ),
            DsListSection(
              header: Text(t.recorder.sortLabel),
              children: [
                for (final order in RecorderLibrarySort.values)
                  DsListRow(
                    title: Text(recorderLibrarySortLabel(t, order)),
                    trailing: filter.sort == order ? const DsIcon(DsIcons.check, size: 16) : null,
                    onPressed: () {
                      Navigator.of(context).pop();
                      controller.setSort(order);
                    },
                  ),
              ],
            ),
            DsListSection(
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.folderOpen, size: 16),
                  title: Text(t.recorder.openFolder),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(openDownloadedPath(context, root));
                  },
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.refresh, size: 16),
                  title: Text(t.recorder.refresh),
                  onPressed: library.isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          ref.read(recordingCoversProvider.notifier).resetAttempts();
                          unawaited(ref.read(recordingLibraryProvider.notifier).refresh());
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The order's choices as menu items, the current one checked.
List<Widget> _sortItems(BuildContext context, WidgetRef ref) {
  final t = context.t;
  final filter = ref.watch(recorderLibraryFilterProvider);
  final controller = ref.read(recorderLibraryFilterProvider.notifier);
  return [
    for (final order in RecorderLibrarySort.values)
      DsMenuItem(
        label: Text(recorderLibrarySortLabel(t, order)),
        checked: filter.sort == order,
        onPressed: () => controller.setSort(order),
      ),
  ];
}

/// The order's own word, said the same way in the menu and in the list.
String recorderLibrarySortLabel(Translations t, RecorderLibrarySort order) => switch (order) {
  RecorderLibrarySort.newest => t.recorder.sortNewest,
  RecorderLibrarySort.oldest => t.recorder.sortOldest,
  RecorderLibrarySort.name => t.recorder.sortName,
  RecorderLibrarySort.size => t.recorder.sortSize,
  RecorderLibrarySort.duration => t.recorder.sortDuration,
};

/// The day's header: what it folds away, how many takes it holds and how big
/// they are together.
///
/// It paints its own background because the rows scroll under it; a
/// transparent one would print the date through the take it is passing.
final class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.title, required this.summary, required this.collapsed, required this.onToggle});

  final String title;
  final String summary;
  final bool collapsed;
  final VoidCallback onToggle;

  /// The header's own height: one label line with its breathing room.
  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return SizedBox(
      height: _height,
      child: ColoredBox(
        color: colors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: DsPressable(
            onPressed: onToggle,
            builder: (context, states, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: DsSpace.s6),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  DsIcon(collapsed ? DsIcons.chevronRight : DsIcons.chevronDown, size: 16, color: colors.textMuted),
                  Text(title, style: theme.typography.labelStrong.copyWith(color: colors.text)),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One take as the subscription cards draw a room: the selection, the cover
/// with its length, the avatar and the room's name over the take's own line,
/// the facts as small chips, and the four verbs at the header's right.
final class _TakeRow extends StatelessWidget {
  const _TakeRow({
    required this.take,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
    required this.onOpenRoom,
    required this.onDelete,
    required this.openRoomLabel,
    required this.platformName,
  });

  final RecordingTake take;
  final Set<String> selected;
  final ValueChanged<RecordingTake> onSelect;
  final VoidCallback onPlay;
  final VoidCallback? onOpenRoom;
  final VoidCallback onDelete;

  /// The pane's word for going to the room, so a channel library names its
  /// own page instead of a live room.
  final String openRoomLabel;

  final String Function(String platformId) platformName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final key = take.filePath ?? take.folder;
    final name = take.roomTitle;
    final ok = take.playable;
    final task = take.task;
    final duration = take.duration;
    final anchor = (task?.anchorName ?? '').trim();
    final avatarUrl = (task?.anchorAvatarUrl ?? '').trim();
    // The stats the transfer used to spend two rows on — who was live,
    // when, how much disk it took and at what rate — one muted line, the
    // way the download queues' captions read.
    final caption = [
      platformName(take.platformId),
      anchor,
      formatRecordingMoment(take.takenAt),
      if (take.bytes > 0) formatRecordingBytes(take.bytes),
      if (duration != null) formatRecordingBitrate(take.bytes, duration),
    ].where((part) => part.isNotEmpty).join(' · ');
    final hang = recorderPunctuationHang(name, theme.typography.heading.fontSize ?? 14);
    // The store keeps one row per room, so its media facts belong to the last
    // take only; an older file under the same row must not wear them.
    final ownsTask = task != null && (take.filePath == null || taskOwnsFile(task, take.filePath!));
    // The length sits on the cover; the file's own shape — its container
    // and its pixels — stays in the chip row.
    final chips = [
      if (take.filePath case final file?) p.extension(file).replaceFirst('.', '').toUpperCase(),
      if (ownsTask && task.videoWidth > 0 && task.videoHeight > 0) '${task.videoWidth}×${task.videoHeight}',
    ].where((part) => part.isNotEmpty).toList();
    final avatarLabel = anchor.isNotEmpty ? anchor : _initialsOfTitle(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final (coverWidth, coverHeight) = width >= 700 ? (160.0, 90.0) : (96.0, 54.0);
          // Four verbs in two rows of two, the same shape the subscription
          // cards use: what the take does first, what it names second.
          // The play verb stands alone where the window affords it; the rest
          // of what a recording can do — into its room, its folder, out of
          // the library — folds into the ⋯ menu the download queues' rows
          // wear, so a card carries two controls instead of a keypad.
          final verbs = Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsButton(
                variant: DsButtonVariant.primary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.play, size: 14),
                onPressed: ok ? onPlay : null,
                child: Text(t.recorder.playRecording),
              ),
              DsMenuAnchor(
                semanticLabel: t.common.more,
                align: DsAlign.end,
                builder: (context, controller, child) => DsPressable(
                  semanticLabel: t.common.more,
                  onPressed: controller.toggle,
                  builder: (context, states, _) {
                    final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                    return Padding(
                      padding: const EdgeInsets.all(DsSpace.s4),
                      child: DsIcon(
                        DsIcons.ellipsisVertical,
                        size: theme.sizes.iconSm,
                        color: lit ? colors.text : colors.textSubtle,
                      ),
                    );
                  },
                ),
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.externalLink),
                    label: Text(openRoomLabel),
                    onPressed: onOpenRoom,
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.folderOpen),
                    label: Text(t.recorder.openFolder),
                    onPressed: () => unawaited(openDownloadedPath(context, take.folder)),
                  ),
                  const DsMenuDivider(),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.recorder.delete),
                    destructive: true,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          );
          final content = Row(
            spacing: DsSpace.s16,
            children: [
              DsCheckbox(value: selected.contains(key), semanticLabel: name, onChanged: (_) => onSelect(take)),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RecorderTakeCover(take: take, width: coverWidth, height: coverHeight),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Row(
                      spacing: DsSpace.s8,
                      children: [
                        DsAvatar(
                          initials: avatarInitials(avatarLabel),
                          image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl, policy: ImageCachePolicies.avatar),
                          size: DsSize.sm,
                          semanticLabel: avatarLabel,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 1,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.heading.copyWith(color: colors.text),
                              ),
                              if (caption.isNotEmpty)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(start: hang),
                                  child: Text(
                                    caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (chips.isNotEmpty)
                      Wrap(
                        spacing: DsSpace.s6,
                        runSpacing: DsSpace.s4,
                        children: [for (final chip in chips) RecorderTagChip(text: chip)],
                      ),
                  ],
                ),
              ),
              if (width >= 620) ...[const SizedBox(width: DsSpace.s16), verbs],
            ],
          );
          return DsCard(
            onPressed: onPlay,
            style: DsCardStyle(
              padding: const EdgeInsets.all(DsSpace.s16),
              borderRadius: BorderRadius.circular(theme.radii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                content,
                if (width < 620) Align(alignment: AlignmentDirectional.centerEnd, child: verbs),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The first letter a title can give an avatar.
///
/// A room title may open on a bracket or a mark (「【重播】…」), which
/// [avatarInitials] would draw as the disc's letter; the first letter or digit
/// is the one the avatar should show.
String _initialsOfTitle(String title) => title.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');

/// A take's average write rate, in the units a player's info line uses.
///
/// The store keeps bytes and media time and no live bitrate, so this is the
/// take's own average rather than the stream's instantaneous one — which is all
/// a finished recording can honestly answer with.
String formatRecordingBitrate(int bytes, Duration duration) {
  if (bytes <= 0 || duration.inSeconds <= 0) return '';
  final kbps = bytes * 8 / duration.inSeconds;
  // A wide take passes a gigabit a second; four digits of Mbps read worse
  // than the unit above them.
  if (kbps >= 1000000) return '${(kbps / 1000000).toStringAsFixed(1)} Gbps';
  return kbps >= 1000 ? '${(kbps / 1000).toStringAsFixed(1)} Mbps' : '${kbps.round()} kbps';
}
