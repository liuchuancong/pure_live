import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show kRecordingFileDeletedWarning;
import 'package:pure_live/modules/live/recorder/pages/recorder_card_parts.dart';
import 'package:pure_live/shared/shared.dart'
    show
        HuyaVideoGlyph,
        HuyaVideoIcon,
        LiveWindow,
        avatarInitials,
        cachedImage,
        kAllPlatforms,
        localizedSiteIcon,
        showActionsPanel,
        showPlatformPickerPanel;

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
    this.useCentrePlatformFilter = false,
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

  /// Whether the centre's own platform filter cuts this pane's list. The
  /// centre's two pages share that one choice, so its files page turns it on;
  /// a module's own recordings page (IPTV) turns it off — its list answers to
  /// its module alone, and the centre's picked site must not empty it (as the
  /// centre's own list must not be emptied by a choice made on IPTV's page).
  final bool useCentrePlatformFilter;

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

  /// The tree this pane owns: every take, cut down to the module's platforms
  /// and — when the pane answers to the centre ([RecorderLibraryPane.useCentrePlatformFilter])
  /// — to the centre's platform filter.
  List<RecordingTake> get _all {
    final scoped = scopeLibraryTakes(
      ref.read(recordingLibraryProvider).value ?? const [],
      platforms: widget.platforms,
      excluded: widget.excludedPlatforms,
    );
    if (!widget.useCentrePlatformFilter) return scoped;
    final filter = ref.read(recorderPlatformFilterProvider);
    return filter == kAllPlatforms
        ? scoped
        : [
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
    // The centre's platform filter cuts both lists the same way; a pane that
    // answers to its own module (IPTV's recordings page) reads nothing here.
    final platformFilter = widget.useCentrePlatformFilter ? ref.watch(recorderPlatformFilterProvider) : kAllPlatforms;
    final takes = platformFilter == kAllPlatforms
        ? scoped
        : [
            for (final take in scoped)
              if (take.platformId == platformFilter) take,
          ];
    final filter = ref.watch(recorderLibraryFilterProvider);
    final filtered = filter.sort.sorted(takes);
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
              child: RecorderLibraryToolbar(
                platforms: recorderPlatformsOf(scoped.map((take) => take.platformId), widget.platformName),
                nameOf: widget.platformName,
                // A pane outside the centre does not answer to the centre's
                // choice, so its toolbar does not offer it either.
                showPlatformFilter: widget.useCentrePlatformFilter,
              ),
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
                icon: const HuyaVideoIcon(HuyaVideoGlyph.recordCamera),
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
                        onOpenRoom: take.task == null ? null : () => widget.onOpenRoom(take),
                        onDelete: () => unawaited(_confirmDeleteTake(take)),
                        openRoomLabel: widget.openRoomLabel ?? t.recorder.openRoom,
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
    widget.onPlay(filter.sort.sorted(_all), take);
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

/// The library's own controls: the order, the folder the takes sit in, and the
/// refresh that walks the tree again.
///
/// A wide window says what each verb does; a small one keeps them as glyphs,
/// the same fold every other page makes when its header line runs out of room.
final class RecorderLibraryToolbar extends ConsumerWidget {
  /// The toolbar over the module's takes; [platforms] feed the platform
  /// filter, named by [nameOf]. [showPlatformFilter] leaves the filter out —
  /// a pane that does not answer to the centre's choice (a module's own
  /// recordings page) has no filter row to offer.
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

  /// Whether the platform filter leads the row.
  final bool showPlatformFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final library = ref.watch(recordingLibraryProvider);
    final root = ref.watch(appPathsProvider).recordings.path;
    final compact = LiveWindow.isCompact(MediaQuery.sizeOf(context).width);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        if (showPlatformFilter) RecorderPlatformFilterButton(platforms: platforms, nameOf: nameOf, compact: compact),
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
  }
}

/// The library's verbs folded into one menu for a phone: the order, the folder
/// and the walk-again refresh, so the page switch keeps the header line to
/// itself instead of stacking a second band of buttons under it.
final class RecorderLibraryToolbarMore extends ConsumerWidget {
  /// Creates the compact toolbar; [platforms] feed the platform filter, named
  /// by [nameOf].
  const RecorderLibraryToolbarMore({required this.platforms, required this.nameOf, super.key});

  /// The site ids the list holds.
  final List<String> platforms;

  /// A site id's display name.
  final String Function(String id) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final library = ref.watch(recordingLibraryProvider);
    final root = ref.watch(appPathsProvider).recordings.path;
    final filter = ref.watch(recorderLibraryFilterProvider);
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
    final caption = [
      platformName(take.platformId),
      formatRecordingMoment(take.takenAt),
    ].where((part) => part.isNotEmpty).join(' · ');
    final hang = recorderPunctuationHang(name, theme.typography.heading.fontSize ?? 14);
    // The store keeps one row per room, so its media facts belong to the last
    // take only; an older file under the same row must not wear them.
    final ownsTask = task != null && (take.filePath == null || taskOwnsFile(task, take.filePath!));
    // The length sits on the cover; everything else the file can say about
    // itself goes in the chip row.
    final chips = [
      if (take.bytes > 0) formatRecordingBytes(take.bytes),
      if (duration != null) formatRecordingBitrate(take.bytes, duration),
      if (take.filePath case final file?) p.extension(file).replaceFirst('.', '').toUpperCase(),
      if (ownsTask && task.videoWidth > 0 && task.videoHeight > 0) '${task.videoWidth}×${task.videoHeight}',
    ].where((part) => part.isNotEmpty).toList();
    final avatarLabel = anchor.isNotEmpty ? anchor : _initialsOfTitle(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final (coverWidth, coverHeight) = width >= 560 ? (132.0, 74.0) : (96.0, 54.0);
          // Four verbs in two rows of two, the same shape the subscription
          // cards use: what the take does first, what it names second.
          Widget cell(Widget child) => SizedBox(width: 124, child: child);
          // The rows shrink to their cells so the block can be held to the
          // card's right edge on a narrow window.
          final verbs = Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s8,
                children: [
                  cell(
                    DsButton(
                      variant: DsButtonVariant.primary,
                      size: DsSize.sm,
                      leading: const HuyaVideoIcon(HuyaVideoGlyph.play, size: 14),
                      onPressed: ok ? onPlay : null,
                      child: Text(t.recorder.playRecording),
                    ),
                  ),
                  cell(
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.externalLink, size: 14),
                      onPressed: onOpenRoom,
                      child: Text(openRoomLabel),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s8,
                children: [
                  cell(
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.folderOpen, size: 14),
                      onPressed: () => unawaited(openDownloadedPath(context, take.folder)),
                      child: Text(t.recorder.openFolder),
                    ),
                  ),
                  cell(
                    DsButton(
                      variant: DsButtonVariant.dangerSoft,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.trash2, size: 14),
                      onPressed: onDelete,
                      child: Text(t.recorder.delete),
                    ),
                  ),
                ],
              ),
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
                Row(
                  spacing: DsSpace.s16,
                  children: [
                    DsCheckbox(value: selected.contains(key), semanticLabel: name, onChanged: (_) => onSelect(take)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _TakeCover(take: take, width: coverWidth, height: coverHeight),
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
                                image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
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
                ),
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
                child: Center(child: HuyaVideoIcon(HuyaVideoGlyph.recordCamera, size: 20, color: colors.accentText)),
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
