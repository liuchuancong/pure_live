import 'dart:async' show unawaited;
import 'dart:io' show File;

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
import 'package:pure_live/modules/live/recorder/data/recorder_library_filter.dart'
    show RecorderLibraryFilter, RecorderLibrarySort, recorderLibraryFilterProvider, scopeLibraryTakes;
import 'package:pure_live/modules/live/recorder/data/recording_covers.dart' show recordingCoversProvider;
import 'package:pure_live/modules/live/recorder/data/recording_library.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart'
    show formatRecordingBytes, formatRecordingDuration, formatRecordingMoment;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show kRecordingFileDeletedWarning;
import 'package:pure_live/shared/shared.dart' show LiveWindow, kAllPlatforms;

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

  /// The row menu's word for going to where the take was made. The live centre
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
  List<RecordingTake> get _all => scopeLibraryTakes(
    ref.read(recordingLibraryProvider).value ?? const [],
    platforms: widget.platforms,
    excluded: widget.excludedPlatforms,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final library = ref.watch(recordingLibraryProvider);
    final takes = scopeLibraryTakes(
      library.value ?? const <RecordingTake>[],
      platforms: widget.platforms,
      excluded: widget.excludedPlatforms,
    );
    final filter = ref.watch(recorderLibraryFilterProvider);
    final filtered = filter.sort.sorted(narrowLibraryTakes(takes, filter));
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
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
        // Adding a task is the shell's own search above; this page narrows with
        // the filter, and the filter is one entry, not a band of controls.
        if (widget.showToolbar)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: RecorderLibraryToolbar(takes: takes, platformName: widget.platformName),
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
                  // Narrowed to nothing is not an empty library: the one verb
                  // that answers is the one that widens it again.
                  if (takes.isNotEmpty && filter.narrowed)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      onPressed: () => ref.read(recorderLibraryFilterProvider.notifier).reset(),
                      child: Text(t.recorder.filterClear),
                    ),
                ],
              ),
            ),
            (false, false) => _dayGroups(filtered, days, inset),
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

  /// The file list: one day after another, each day opening with its own
  /// header and folding away under it.
  ///
  /// The days are ordinary slivers of one list rather than a
  /// `SliverMainAxisGroup` around a pinned header: the group emits a geometry
  /// whose layout extent exceeds its paint extent once a pinned child sits
  /// inside it, which aborts the viewport's layout and leaves the next pointer
  /// event hit-testing slivers that were never laid out.
  Widget _dayGroups(List<RecordingTake> filtered, List<String> days, double inset) {
    final t = context.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s12),
      child: CustomScrollView(
        slivers: [
          for (final day in days) ...[
            SliverToBoxAdapter(
              child: _DayHeader(
                title: _dayTitle(day),
                summary: t.recorder.groupSummary(
                  count: filtered.where((take) => take.day == day).length,
                  size: formatRecordingBytes(
                    filtered.where((take) => take.day == day).fold<int>(0, (total, take) => total + take.bytes),
                  ),
                ),
                collapsed: _collapsed.contains(day),
                onToggle: () => setState(() {
                  if (!_collapsed.remove(day)) _collapsed.add(day);
                }),
              ),
            ),
            if (!_collapsed.contains(day))
              SliverList(
                delegate: SliverChildListDelegate([
                  for (final take in filtered)
                    if (take.day == day)
                      _TakeRow(
                        take: take,
                        selected: _selected,
                        onSelect: _toggle,
                        onPlay: () => _play(take),
                        menu: _takeMenu(take),
                        platformName: widget.platformName,
                      ),
                ]),
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
    widget.onPlay(filter.sort.sorted(narrowLibraryTakes(_all, filter)), take);
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

/// The library's conditions applied: one site (while that choice has anything
/// to choose between) and, when asked, only the rows a player can open.
///
/// A platform choice only exists while the tree holds more than one site; with
/// one site the stored choice is ignored rather than hiding every take behind a
/// row nobody can see.
List<RecordingTake> narrowLibraryTakes(List<RecordingTake> takes, RecorderLibraryFilter filter) {
  final platforms = {for (final take in takes) take.platformId};
  final platform = platforms.length > 1 ? filter.platform : kAllPlatforms;
  return [
    for (final take in takes)
      if ((platform == kAllPlatforms || take.platformId == platform) && (!filter.playableOnly || take.playable)) take,
  ];
}

/// The library's own controls: one entry to its conditions, the folder the
/// takes sit in, and the refresh that walks the tree again.
///
/// A wide window says what each verb does; a small one keeps the two it needs
/// most — the filter and the refresh — as glyphs, the same fold every other
/// page makes when its header line runs out of room.
final class RecorderLibraryToolbar extends ConsumerWidget {
  /// The toolbar over the module's [takes], sites named by [platformName].
  const RecorderLibraryToolbar({required this.takes, required this.platformName, super.key});

  /// The takes this library holds, before its own conditions cut them.
  final List<RecordingTake> takes;

  /// The viewer's name for a site id.
  final String Function(String platformId) platformName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final library = ref.watch(recordingLibraryProvider);
    final filter = ref.watch(recorderLibraryFilterProvider);
    final root = ref.watch(appPathsProvider).recordings.path;
    final compact = LiveWindow.isCompact(MediaQuery.sizeOf(context).width);
    void open() => unawaited(showRecordingLibraryFilter(context, ref, takes: takes, platformName: platformName));
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        // A wide window says what the entry is; a small one spends its room on
        // the list and lets the funnel glyph answer for it.
        if (compact)
          DsButton.icon(
            variant: filter.narrowed ? DsButtonVariant.tinted : DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: open,
            icon: const DsIcon(DsIcons.filter, size: 16),
            semanticLabel: t.recorder.filterLabel,
          )
        else
          DsButton(
            variant: filter.narrowed ? DsButtonVariant.tinted : DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.filter, size: 14),
            onPressed: open,
            child: Text(t.recorder.filterLabel),
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
  }
}

/// The library's conditions, behind the toolbar's one entry: which site's takes
/// show, whether a row must hold something playable, and the order the days are
/// read in.
///
/// The panel edits the provider rather than a local copy, so the list under it
/// answers while the panel is still open — the conditions are few enough that a
/// separate 应用 step would only hide what each one just did.
Future<void> showRecordingLibraryFilter(
  BuildContext context,
  WidgetRef ref, {
  required List<RecordingTake> takes,
  required String Function(String platformId) platformName,
}) => showDsPanel<void>(
  context: context,
  builder: (panelContext) => _LibraryFilterPanel(takes: takes, platformName: platformName),
);

final class _LibraryFilterPanel extends ConsumerWidget {
  const _LibraryFilterPanel({required this.takes, required this.platformName});

  final List<RecordingTake> takes;
  final String Function(String platformId) platformName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final filter = ref.watch(recorderLibraryFilterProvider);
    final controller = ref.read(recorderLibraryFilterProvider.notifier);
    final ids = {for (final take in takes) take.platformId}.toList()
      ..sort((a, b) => platformName(a).compareTo(platformName(b)));
    return DsPanel(
      title: Text(t.recorder.filterTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsListSection(
            header: Text(t.recorder.filterPlatformGroup),
            children: [
              for (final id in [kAllPlatforms, ...ids])
                DsListRow(
                  title: Text(id == kAllPlatforms ? t.recorder.filterAll : platformName(id)),
                  detail: Text(
                    '${id == kAllPlatforms ? takes.length : takes.where((take) => take.platformId == id).length}',
                  ),
                  trailing: filter.platform == id ? const DsIcon(DsIcons.check, size: 16) : null,
                  onPressed: () => controller.setPlatform(id),
                ),
            ],
          ),
          DsListSection(
            children: [
              DsListRow(
                title: Text(t.recorder.filterPlayable),
                trailing: DsSwitch(
                  value: filter.playableOnly,
                  onChanged: (value) => controller.setPlayableOnly(value: value),
                ),
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
                  onPressed: () => controller.setSort(order),
                ),
            ],
          ),
          DsListSection(
            children: [DsListRow(title: Text(t.recorder.filterClear), onPressed: controller.reset)],
          ),
        ],
      ),
    );
  }
}

/// The order's own word, said the same way in the panel and in the list.
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
    final ok = take.playable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The checkbox, the badge, the verbs and the menu are the fixed part,
          // so the row gives way in the order a viewer reads it: the words on
          // the buttons first (the glyphs say the same thing), then the state
          // badge — which stays only when it is the bad news — then the cover,
          // so the name keeps a readable line at the window's floor.
          final width = constraints.maxWidth;
          final roomy = width >= 620;
          final (coverWidth, coverHeight) = width >= 520
              ? (96.0, 54.0)
              : width >= 400
              ? (72.0, 40.0)
              : (0.0, 0.0);
          return DsCard(
            onPressed: onPlay,
            style: DsCardStyle(
              padding: const EdgeInsets.all(DsSpace.s8),
              borderRadius: BorderRadius.circular(theme.radii.card),
            ),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                DsCheckbox(value: selected.contains(key), semanticLabel: name, onChanged: (_) => onSelect(take)),
                if (coverWidth > 0) _TakeCover(take: take, width: coverWidth, height: coverHeight),
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
                          if (take.duration case final length?) formatRecordingDuration(length),
                          if (take.bytes > 0) formatRecordingBytes(take.bytes),
                          if (take.duration case final length?) formatRecordingBitrate(take.bytes, length),
                        ].where((part) => part.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (roomy || !ok)
                  DsBadge(
                    label: Text(ok ? t.recorder.stateSaved : t.recorder.stateUnplayable),
                    status: ok ? DsStatus.success : DsStatus.neutral,
                  ),
                if (roomy)
                  DsButton(
                    variant: DsButtonVariant.primary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.play, size: 14),
                    onPressed: ok ? onPlay : null,
                    child: Text(t.recorder.playRecording),
                  )
                else
                  DsButton.icon(
                    variant: DsButtonVariant.primary,
                    size: DsSize.sm,
                    onPressed: ok ? onPlay : null,
                    icon: const DsIcon(DsIcons.play, size: 16),
                    semanticLabel: t.recorder.playRecording,
                  ),
                if (roomy)
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
          );
        },
      ),
    );
  }
}

/// The take's own frame, cut from the file by the recording backend's FFmpeg.
///
/// A take with nothing playable, or one FFmpeg could not open, keeps the tile
/// the library always drew: the picture is what a row gains, never what it
/// depends on.
final class _TakeCover extends ConsumerStatefulWidget {
  const _TakeCover({required this.take, required this.width, required this.height});

  final RecordingTake take;
  final double width;
  final double height;

  @override
  ConsumerState<_TakeCover> createState() => _TakeCoverState();
}

final class _TakeCoverState extends ConsumerState<_TakeCover> {
  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(_TakeCover old) {
    super.didUpdateWidget(old);
    if (old.take.filePath != widget.take.filePath) _request();
  }

  /// Asks for this take's frame after the frame is painted, so a page of rows
  /// queues its covers instead of starting FFmpeg inside a build.
  void _request() {
    final file = widget.take.filePath;
    if (file == null || file.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recordingCoversProvider.notifier).request(file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final cover = ref.watch(recordingCoversProvider)[widget.take.filePath ?? ''];
    final duration = widget.take.duration;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DsImage(
              image: cover == null ? null : FileImage(File(cover)),
              width: widget.width,
              height: widget.height,
              semanticLabel: widget.take.roomTitle,
              fallback: DecoratedBox(
                decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(6)),
                child: Center(child: DsIcon(DsIcons.video, size: 20, color: colors.accentText)),
              ),
            ),
          ),
          if (duration != null)
            Positioned(
              right: 4,
              bottom: 4,
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
    );
  }
}

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
