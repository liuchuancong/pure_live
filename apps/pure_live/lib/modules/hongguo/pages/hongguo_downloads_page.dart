import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/features/media_preview/media_preview_page.dart' show openMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openModuleItem;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadFilterOption,
        DownloadWorkspace,
        LiveWindow,
        NavigationItem,
        cachedImage,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;

/// Whether a finished episode's file is still on disk where its row says.
///
/// Only a `done` row can be missing: a queued, paused or failed episode keeps
/// its bytes in the `.part` beside the target and renames into place only when
/// the transfer ends, so marking such a row 文件不在了 would say the opposite
/// of the truth. One stat per row build, never a folder scan.
bool _hongguoFileMissing(HongguoDownloadItem task) =>
    task.phase == HongguoDownloadPhase.done && !downloadFilePresent(task.filePath);

/// Takes one episode's record out of the queue; the file, if it is there, stays.
///
/// The row menu and the wide workspace's facts column both reach it, so a row
/// that only names a file the viewer moved can be cleared from wherever the
/// absence was noticed.
Future<void> _removeRecord(BuildContext context, WidgetRef ref, String id) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.downloadRemove,
    description: t.settings.downloadRemoveBody,
    confirmLabel: t.settings.downloadRemove,
    cancelLabel: t.common.cancel,
    destructive: true,
    icon: const DsIcon(DsIcons.trash2),
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(hongguoDownloadsProvider.notifier).remove(id);
}

/// 下载管理 — the station's download settings under Settings → 红果短剧.
///
/// The pane carries the lanes, the retry budget, the download tier and the
/// folder the files land in, then one line that says how much the queue holds
/// and opens the station's own 下载管理 page ([HongguoDownloadsPage]). Drawing
/// the queue here as well made one thing two entrances, and the settings half
/// was the weaker: no speed, no table, no batch verbs.
final class HongguoDownloadsPane extends ConsumerWidget {
  /// The pane shown under Settings → 红果短剧 → 下载.
  const HongguoDownloadsPane({super.key});

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.hongguo.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.videos, selected);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: saved ? t.hongguo.downloadDirectoryUpdated : t.hongguo.downloadDirectoryFailed,
        status: saved ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.hongguo.downloadDirectoryFailed, status: DsStatus.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tasks = ref.watch(hongguoDownloadsProvider);
    final lanes = ref.watch(hongguoDownloadSettingsProvider);
    final quality = ref.watch(hongguoDownloadQualityProvider);
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final active = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    // The bytes already on disk, the counter's second half.
    final finishedBytes = tasks
        .where((task) => task.phase == HongguoDownloadPhase.done)
        .fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.hongguo.downloadSettingsTitle),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.download),
              title: t.hongguo.downloadMaxConcurrent,
              description: t.hongguo.downloadMaxConcurrentDesc,
              value: lanes,
              options: [for (var count = 1; count <= 5; count++) DsSelectOption(value: count, label: '$count')],
              onChanged: (value) => ref.read(hongguoDownloadSettingsProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.hongguo.downloadRetry,
              description: t.hongguo.downloadRetryDesc,
              value: retry,
              options: [
                for (final count in HongguoDownloadRetryController.choices)
                  DsSelectOption(
                    value: count,
                    label: count == 0 ? t.hongguo.downloadRetryOff : t.hongguo.downloadRetryTimes(count: count),
                  ),
              ],
              onChanged: (value) => ref.read(hongguoDownloadRetryProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.timer),
              title: t.hongguo.downloadRetryDelay,
              description: t.hongguo.downloadRetryDelayDesc,
              value: retryDelay,
              options: [
                for (final seconds in HongguoDownloadRetryDelayController.choices)
                  DsSelectOption(value: seconds, label: '${seconds}s'),
              ],
              // A row without a retry to wait between stays visible, greyed:
              // a missing row reads as a missing feature.
              onChanged: retry == 0
                  ? null
                  : (value) => ref.read(hongguoDownloadRetryDelayProvider.notifier).select(value),
            ),
            SettingsChoiceRow<HongguoQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.hongguo.downloadQuality,
              description: t.hongguo.downloadQualityDesc,
              value: quality,
              options: [
                for (final choice in HongguoQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (value) => ref.read(hongguoDownloadQualityProvider.notifier).select(value),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.hongguo.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(_pickDirectory(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.hongguo.downloadDirectoryDefault),
              description: Text(t.hongguo.downloadDirectoryDefaultDesc),
              onPressed: () => unawaited(ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.videos)),
            ),
          ],
        ),
        // The queue is one row and one tap away, on the station's own 下载管理
        // page: this pane drew the same episodes a second time, with a weaker
        // summary and no table, so the same tasks read differently depending on
        // which door the viewer came through. Settings keeps the choices, the
        // count and the way out.
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.download),
              title: Text(t.hongguo.downloadManagerTitle),
              description: Text(
                [
                  t.hongguo.downloadTaskCount(count: tasks.length, active: active),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  directory,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              showChevron: true,
              onPressed: () => openModuleItem(context, ref, NavigationItem.hongguoDownloads),
            ),
          ],
        ),
      ],
    );
  }
}

/// The remaining time the caption carries when it can be computed at all:
/// a known speed and bytes still owed — otherwise the fact is left out
/// rather than guessed.
String? _etaOf(Translations t, {required int speed, required int total, required int received}) {
  if (speed <= 0 || received >= total) return null;
  final seconds = (total - received) ~/ speed;
  final hours = seconds ~/ 3600;
  final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return t.hongguo.downloadEta(time: hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss');
}

/// What the manager's filter shows.
enum _HongguoDownloadFilter {
  all,

  /// The queue and everything still owed a file.
  active,

  /// The episodes that finished and can be watched.
  done;

  String label(Translations t) => switch (this) {
    _HongguoDownloadFilter.all => t.hongguo.downloadFilterAll,
    _HongguoDownloadFilter.active => t.hongguo.downloadFilterActive,
    _HongguoDownloadFilter.done => t.hongguo.downloadFilterDone,
  };
}

/// The station's download manager as its own page: the folder the files land
/// in, the queue with its filters and batch actions, and the finished
/// episodes with their in-app preview.
final class HongguoDownloadsPage extends ConsumerStatefulWidget {
  /// The download manager, opening on the whole queue.
  const HongguoDownloadsPage({super.key});

  @override
  ConsumerState<HongguoDownloadsPage> createState() => _HongguoDownloadsPageState();
}

final class _HongguoDownloadsPageState extends ConsumerState<HongguoDownloadsPage> {
  _HongguoDownloadFilter _filter = _HongguoDownloadFilter.all;

  /// The row whose facts sit in the wide workspace's right column; null lets
  /// the first visible row speak.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final tasks = ref.watch(hongguoDownloadsProvider);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    final moving = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    final stopped = tasks.any(
      (task) => task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed,
    );
    final finished = tasks.where((task) => task.phase == HongguoDownloadPhase.done).toList();
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    // The queue's live throughput: every running task's own rate, summed.
    final totalSpeed = tasks
        .where((task) => task.phase == HongguoDownloadPhase.running)
        .fold<int>(0, (sum, task) => sum + task.speed);
    final shown = switch (_filter) {
      _HongguoDownloadFilter.all => tasks,
      _HongguoDownloadFilter.active => tasks.where((task) => task.phase != HongguoDownloadPhase.done).toList(),
      _HongguoDownloadFilter.done => finished,
    };
    final selectedTask =
        (_selectedId == null ? null : tasks.where((task) => task.id == _selectedId).firstOrNull) ??
        (shown.isEmpty ? null : shown.first);
    Widget queueList({required bool wide}) => shown.isEmpty
        ? Center(
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.download),
              title: Text(tasks.isEmpty ? t.hongguo.downloadEmpty : t.hongguo.downloadFilterEmpty),
              description: Text(tasks.isEmpty ? t.hongguo.downloadEmptyDesc : t.hongguo.downloadFilterEmptyDesc),
              actions: [
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.folderOpen, size: 14),
                  onPressed: () => unawaited(openDownloadedPath(context, directory)),
                  child: Text(t.settings.downloadManagerOpenFolder),
                ),
              ],
            ),
          )
        : ListView(
            padding: EdgeInsets.only(left: inset, right: inset, bottom: DsSpace.s16),
            children: [
              for (final group in _hongguoDownloadGroups(shown)) ...[
                _HongguoSeriesHead(group: group),
                DsListSection(
                  children: [
                    for (final task in group.tasks)
                      _HongguoTaskRow(
                        key: ValueKey(task.id),
                        task: task,
                        selected: wide && task.id == selectedTask?.id,
                        onSelect: wide ? () => setState(() => _selectedId = task.id) : null,
                      ),
                  ],
                ),
              ],
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        // A manager with room for three panes reads like a workspace: the
        // filters, the queue, and the selected task's facts.
        final wide = constraints.maxWidth >= LiveWindow.downloadWorkspace;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s8,
                children: [
                  Row(
                    spacing: DsSpace.s12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: DsSpace.s3,
                          children: [
                            // The page's name belongs to the menu entry that
                            // opened it; what this line has to say that the
                            // menu cannot is how big the queue is and where
                            // the files land.
                            Text(
                              [
                                t.hongguo.downloadTaskCount(count: tasks.length, active: moving),
                                if (totalSpeed > 0)
                                  t.common.downloadSpeed(speed: '${formatDownloadBytes(totalSpeed)}/s'),
                                if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                            ),
                            Text(
                              directory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            spacing: DsSpace.s8,
                            children: [
                              if (moving > 0)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: () => unawaited(controller.pauseAll()),
                                  child: Text(t.hongguo.downloadPauseAll),
                                ),
                              if (stopped)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: () => unawaited(controller.resumeAll()),
                                  child: Text(t.hongguo.downloadResumeAll),
                                ),
                              if (finished.isNotEmpty)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: () => unawaited(
                                    confirmClearFinished(
                                      context,
                                      title: t.hongguo.downloadClearFinished,
                                      clear: controller.clearFinished,
                                    ),
                                  ),
                                  child: Text(t.hongguo.downloadClearFinished),
                                ),
                              DsButton(
                                variant: DsButtonVariant.secondary,
                                size: DsSize.sm,
                                onPressed: () => unawaited(openDownloadedPath(context, directory)),
                                child: Text(t.settings.downloadManagerOpenFolder),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!wide)
                    SizedBox(
                      height: 40,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DsSegmentedControl<_HongguoDownloadFilter>(
                          value: _filter,
                          onChanged: (filter) => setState(() => _filter = filter),
                          semanticLabel: t.hongguo.downloadManagerTitle,
                          segments: [
                            for (final filter in _HongguoDownloadFilter.values)
                              DsSegment(value: filter, label: Text(filter.label(t))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: wide
                  ? DownloadWorkspace<_HongguoDownloadFilter>(
                      options: [
                        for (final value in _HongguoDownloadFilter.values)
                          DownloadFilterOption(
                            value: value,
                            icon: switch (value) {
                              _HongguoDownloadFilter.all => DsIcons.list,
                              _HongguoDownloadFilter.active => DsIcons.download,
                              _HongguoDownloadFilter.done => DsIcons.checkCircle,
                            },
                            label: value.label(t),
                            count: switch (value) {
                              _HongguoDownloadFilter.all => tasks.length,
                              _HongguoDownloadFilter.active =>
                                tasks.where((task) => task.phase != HongguoDownloadPhase.done).length,
                              _HongguoDownloadFilter.done => finished.length,
                            },
                          ),
                      ],
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                      list: queueList(wide: true),
                      details: selectedTask == null
                          ? null
                          : _detailsOf(
                              context,
                              selectedTask,
                              t,
                              retryLimit: retry,
                              retryDelay: retryDelay,
                              retryPending: controller.hasPendingRetry(selectedTask.id),
                            ),
                    )
                  : queueList(wide: false),
            ),
          ],
        );
      },
    );
  }
}

/// The preview page's list for the hongguo queue: every episode that finished,
/// in the queue's own order — the same grammar the station's downloads and the
/// recording centre hand the page, with no danmaku beside it because the
/// platform has none to save. An episode whose file was cleaned out stays in
/// the list; the page greys it and says the file is gone.
List<MediaPreviewItem> _hongguoPreviewItems(List<HongguoDownloadItem> tasks) {
  final items = <MediaPreviewItem>[];
  for (final task in tasks) {
    if (task.phase != HongguoDownloadPhase.done) continue;
    items.add(
      MediaPreviewItem(
        id: task.id,
        title: task.part.isEmpty ? task.title : '${task.title} · ${task.part}',
        path: task.filePath,
        subtitle: [
          '${task.maxHeight}P',
          if (task.total > 0) formatDownloadBytes(task.total),
          downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
        ].join(' · '),
        cover: task.cover,
        // The list groups by the show this part belongs to, so thirty episodes
        // of two series read as two blocks with their own folder action rather
        // than as one numbered run the viewer has to count by hand.
        groupPath: p.dirname(task.filePath),
        groupLabel: task.title,
      ),
    );
  }
  return items;
}

/// One drama's block of the queue: its name, its poster where the queue kept
/// one, and the episodes this list holds of it.
final class _HongguoDownloadGroup {
  _HongguoDownloadGroup({required this.title, required this.cover, required this.parts, required this.tasks});

  /// The series' name, written once for the block.
  final String title;

  /// The series' poster; the first task in the block that carries one.
  String cover;

  /// How many episodes the series lists — the queue keeps it per task, and a
  /// block reads as a part of a whole only when the whole is more than one.
  final int parts;

  /// The episodes, in the queue's own order.
  final List<HongguoDownloadItem> tasks;
}

/// The queue read by series: one block per drama, in the order the list first
/// names one, the episodes inside a block kept as the list has them. The
/// station's own 我的下载 lists dramas and opens a drama's episodes from there;
/// a flat list of episodes writes the same drama's name once per row — thirty
/// times for one take — and gives no line to read the take from.
List<_HongguoDownloadGroup> _hongguoDownloadGroups(Iterable<HongguoDownloadItem> tasks) {
  final order = <String>[];
  final blocks = <String, _HongguoDownloadGroup>{};
  for (final task in tasks) {
    final key = task.seriesId.isEmpty ? task.title : task.seriesId;
    final block = blocks[key];
    if (block == null) {
      blocks[key] = _HongguoDownloadGroup(title: task.title, cover: task.cover, parts: task.parts, tasks: [task]);
      order.add(key);
    } else {
      block.tasks.add(task);
      // A task queued before the queue kept posters still names its drama;
      // the first picture the block holds is the block's.
      if (block.cover.isEmpty) block.cover = task.cover;
    }
  }
  return [for (final key in order) blocks[key]!];
}

/// The line over one drama's episodes: its poster where the queue has one, its
/// name once for the block, the size of the drama the block belongs to, and the
/// verbs that act on the whole block. A thirty-episode take whose every action
/// sits on the row is thirty taps, and a page that counts tasks for the whole
/// queue and for none of its parts is a flat list wearing group headers.
final class _HongguoSeriesHead extends ConsumerWidget {
  const _HongguoSeriesHead({required this.group});

  /// The block being introduced.
  final _HongguoDownloadGroup group;

  /// Runs [verb] over every id it was handed. The store writes per task, so
  /// the ids go one after another rather than all at once.
  Future<void> _apply(
    WidgetRef ref,
    List<String> ids,
    Future<void> Function(HongguoDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    for (final id in ids) {
      await verb(controller, id);
    }
  }

  /// The block's own phases, read when the action is asked for rather than
  /// when the line was painted: a task that finished in between is no longer
  /// something to pause.
  ({List<String> pausable, List<String> resumable}) _phases() => (
    pausable: [
      for (final task in group.tasks)
        if (task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued) task.id,
    ],
    resumable: [
      for (final task in group.tasks)
        if (task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed) task.id,
    ],
  );

  Future<void> _removeBlock(BuildContext context, WidgetRef ref, Translations t) async {
    final ids = [for (final task in group.tasks) task.id];
    final phases = _phases();
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadRemove,
      // Which drama, and how many of its tasks: the row's own body says 这条
      // 记录, and a block would be answering for thirty of them.
      description: '${group.title} · ${t.hongguo.downloadTaskCount(count: ids.length, active: phases.pausable.length)}',
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    // The tap can land after the dialog's host is gone (the queue rebuilt
    // under it); a dead context must not reach the page's store.
    if (!confirmed || !context.mounted) return;
    await _apply(ref, ids, (controller, id) => controller.remove(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final phases = _phases();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, 0, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          if (group.cover.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(28)),
              child: SizedBox(
                width: 28,
                height: 28,
                child: DsImage(
                  image: cachedImage(group.cover),
                  aspectRatio: 1,
                  semanticLabel: group.title,
                  fallback: ColoredBox(color: colors.control),
                ),
              ),
            ),
          Expanded(
            child: Text(
              group.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
          // The drama's own scale, not the queue's: how many episodes sit here
          // is the rows under this line, and the page's head already counts the
          // whole queue. A one-episode take has nothing to be a part of.
          if (group.parts > 1)
            Text(
              t.hongguo.allEpisodesCount(count: group.parts),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          // One episode in the block is the row's own business; a verb with a
          // single object does not need a second place to be pressed, and a
          // head that greyed out an inapplicable switch would only say so
          // louder than the row already does.
          if (group.tasks.length > 1)
            DsMenuAnchor(
              semanticLabel: group.title,
              align: DsAlign.end,
              items: [
                if (phases.pausable.isNotEmpty)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pause),
                    label: Text(t.settings.downloadPause),
                    onPressed: () => unawaited(_apply(ref, phases.pausable, (controller, id) => controller.pause(id))),
                  ),
                if (phases.resumable.isNotEmpty)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.play),
                    label: Text(t.settings.downloadResume),
                    onPressed: () =>
                        unawaited(_apply(ref, phases.resumable, (controller, id) => controller.resume(id))),
                  ),
                if (phases.pausable.isNotEmpty || phases.resumable.isNotEmpty) const DsMenuDivider(),
                DsMenuItem(
                  leading: const DsIcon(DsIcons.trash2),
                  label: Text(t.settings.downloadRemove),
                  destructive: true,
                  onPressed: () => unawaited(_removeBlock(context, ref, t)),
                ),
              ],
              builder: (context, anchor, _) => DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: group.title,
                onPressed: anchor.toggle,
                icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

/// The facts the right column, the 详情 sheet and the row's own caption show
/// for [task] — one construction, so the three cannot drift. [retryLimit] and
/// [retryDelay] let a failed row say when the queue will come back for it
/// instead of leaving the wait silent.
DownloadDetails _detailsOf(
  BuildContext context,
  HongguoDownloadItem task,
  Translations t, {
  int retryLimit = 0,
  int retryDelay = 0,
  bool retryPending = false,
  VoidCallback? onRemove,
}) {
  final total = task.total;
  // One stat, and only for a row that claims a finished file.
  final missing = _hongguoFileMissing(task);
  // A failed row says what went wrong and, when the queue still owes it an
  // automatic retry, how long the wait is.
  final failedBase = (task.error ?? '').trim().isEmpty
      ? t.hongguo.downloadPhaseFailed
      : '${t.hongguo.downloadPhaseFailed} · ${task.error!.trim()}';
  final retryWait = retryPending && retryLimit > 0
      ? ' · ${t.common.downloadRetryPending(delay: retryDelay, left: (retryLimit - task.attempts).clamp(0, 1 << 20))}'
      : '';
  final caption = switch (task.phase) {
    HongguoDownloadPhase.queued => t.hongguo.downloadPhaseQueued,
    HongguoDownloadPhase.running when total > 0 => [
      t.hongguo.downloading(percent: task.received * 100 ~/ total),
      '${formatDownloadBytes(task.speed)}/s',
      '${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    HongguoDownloadPhase.running => t.hongguo.downloadingUnknown,
    HongguoDownloadPhase.paused when total > 0 =>
      '${t.hongguo.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
    HongguoDownloadPhase.paused => t.hongguo.downloadPhasePaused,
    HongguoDownloadPhase.failed => '$failedBase$retryWait',
    // The record says the transfer finished; only the disk says whether the
    // file is still there. A row whose episode was moved or deleted says so in
    // the same place its 已完成 used to stand alone.
    HongguoDownloadPhase.done =>
      '${missing ? t.common.previewFileMissing : t.hongguo.downloadPhaseDone} · '
          '${formatDownloadBytes(total > 0 ? total : task.received)}'
          ' · ${downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp))}',
  };
  return DownloadDetails(
    title: task.title,
    part: task.part,
    coverUrl: task.cover,
    status: caption,
    savePath: task.filePath,
    queuedAt: downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
    retries: task.attempts,
    error: task.error ?? '',
    fileMissing: missing,
    onOpenFile: task.phase == HongguoDownloadPhase.done && !missing
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
    onRemove: onRemove,
  );
}

/// One episode's row: the file's name over its phase's caption and bar, with
/// the actions that phase allows at the end.
final class _HongguoTaskRow extends ConsumerWidget {
  const _HongguoTaskRow({required this.task, this.selected = false, this.onSelect, super.key});

  final HongguoDownloadItem task;

  /// Whether the wide workspace shows this row's facts at the right.
  final bool selected;

  /// Marks this row as the one the workspace speaks about.
  final VoidCallback? onSelect;

  Future<void> _remove(BuildContext context, WidgetRef ref) => _removeRecord(context, ref, task.id);

  Future<void> _deleteFile(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.hongguo.downloadDeleteFile,
      description: t.hongguo.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(hongguoDownloadsProvider.notifier).remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.hongguo.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  /// Opens the app's own preview on this episode, with the queue's other
  /// finished episodes beside it. Hongguo saves no danmaku file, so the
  /// stage's switch says so and stays out of reach. An episode whose file
  /// went away after the row was built is said so rather than quietly
  /// replaced by a neighbour in the list.
  Future<void> _openPreview(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final items = _hongguoPreviewItems(ref.read(hongguoDownloadsProvider));
    final index = items.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      showDsToast(context: context, title: t.hongguo.previewUnavailable, status: DsStatus.warning);
      return;
    }
    await openMediaPreview(
      context,
      title: t.hongguo.previewTitle,
      items: items,
      initialIndex: index,
      // The same rule as the video site: an episode deleted in the player has
      // no reason to stay in the queue as a row that opens nothing.
      onDeleted: (item) => ref.read(hongguoDownloadsProvider.notifier).remove(item.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final moving = task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.paused;
    // The row states the same facts the details do, built by the same
    // function — including the wait before a pending automatic retry.
    final caption = _detailsOf(
      context,
      task,
      t,
      retryLimit: ref.watch(hongguoDownloadRetryProvider),
      retryDelay: ref.watch(hongguoDownloadRetryDelayProvider),
      retryPending: controller.hasPendingRetry(task.id),
    ).status;
    // The row is one episode of the block its header just named: the series'
    // name and its poster belong to that header, not to every one of the
    // thirty rows under it. The platform's own episode title is kept beside
    // the number when it differs from the number — the queue stores the
    // generated 第N集 label when the site named nothing.
    final label = t.hongguo.episodeLabel(index: task.index);
    final episode = task.part.isEmpty || task.part == label ? label : '$label · ${task.part}';
    // Asked once per row, never by walking the folder: a finished episode the
    // viewer moved elsewhere still plays no part.
    final missing = _hongguoFileMissing(task);
    return DsListRow(
      selected: selected,
      onPressed: onSelect,
      title: Text(episode, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          Text(
            '${task.maxHeight}P',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
          // Two lines: a failed row carries its error and the retry wait, and
          // a narrow window must not ellipsise the second half away.
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (moving && (fraction != null || task.received > 0))
            DsProgressBar(value: fraction, semanticLabel: task.fileName),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (task.phase) {
            HongguoDownloadPhase.running => DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.pause),
              semanticLabel: t.settings.downloadPause,
              onPressed: () => unawaited(controller.pause(task.id)),
            ),
            HongguoDownloadPhase.queued || HongguoDownloadPhase.paused => DsButton.icon(
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.play),
              semanticLabel: t.settings.downloadResume,
              onPressed: () => unawaited(controller.resume(task.id)),
            ),
            HongguoDownloadPhase.failed => DsButton.icon(
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.rotateCw),
              semanticLabel: t.common.retry,
              onPressed: () => unawaited(controller.resume(task.id)),
            ),
            // An episode whose file is gone has nothing to preview; the button
            // says which fact it is standing on instead of failing on tap.
            HongguoDownloadPhase.done => DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              icon: DsIcon(missing ? DsIcons.fileX : DsIcons.play),
              semanticLabel: missing ? t.common.previewFileMissing : t.settings.backgroundPreviewMedia,
              onPressed: missing ? null : () => unawaited(_openPreview(context, ref)),
            ),
          },
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
                leading: const DsIcon(DsIcons.info),
                label: Text(t.common.downloadDetails),
                onPressed: () => unawaited(
                  showDownloadDetails(
                    context,
                    _detailsOf(
                      context,
                      task,
                      t,
                      retryLimit: ref.watch(hongguoDownloadRetryProvider),
                      retryDelay: ref.watch(hongguoDownloadRetryDelayProvider),
                      retryPending: ref.read(hongguoDownloadsProvider.notifier).hasPendingRetry(task.id),
                      onRemove: () => unawaited(_remove(context, ref)),
                    ),
                  ),
                ),
              ),
              const DsMenuDivider(),
              if (task.phase == HongguoDownloadPhase.done) ...[
                // A gone file keeps its folder (what sits beside it is still
                // worth seeing) and loses the two verbs that act on it.
                if (!missing)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.externalLink),
                    label: Text(t.settings.downloadOpenFile),
                    onPressed: () => unawaited(openDownloadedPath(context, task.filePath)),
                  ),
                DsMenuItem(
                  leading: const DsIcon(DsIcons.folderOpen),
                  label: Text(t.settings.downloadManagerOpenFolder),
                  onPressed: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
                ),
                if (!missing) ...[
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.hongguo.downloadDeleteFile),
                    destructive: true,
                    onPressed: () => unawaited(_deleteFile(context, ref)),
                  ),
                  const DsMenuDivider(),
                ],
              ],
              DsMenuItem(
                leading: const DsIcon(DsIcons.trash2),
                // Over a file that is not there, 移除记录 is the whole answer:
                // the row is the only thing left of the download.
                label: Text(missing ? t.common.downloadRemoveFromList : t.settings.downloadRemove),
                destructive: true,
                onPressed: () => unawaited(_remove(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
