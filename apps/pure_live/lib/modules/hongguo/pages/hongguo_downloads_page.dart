import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/features/media_preview/media_preview_page.dart' show openMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsHint;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show DownloadDetails, DownloadFilterOption, DownloadWorkspace, LiveWindow, cachedImage, showDownloadDetails;

/// 下载管理 — the station's download queue under Settings → 红果短剧.
///
/// The settings half carries the lanes, the download tier and the folder the
/// files land in; the task half is one row per episode with the phase's own
/// actions. The same rows live on the sidebar's own 下载管理 page
/// ([HongguoDownloadsPage]).
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tasks = ref.watch(hongguoDownloadsProvider);
    final lanes = ref.watch(hongguoDownloadSettingsProvider);
    final quality = ref.watch(hongguoDownloadQualityProvider);
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final active = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    final finished = tasks.any((task) => task.phase == HongguoDownloadPhase.done);
    // The bytes already on disk, the counter's second half.
    final finishedBytes = tasks
        .where((task) => task.phase == HongguoDownloadPhase.done)
        .fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsHint(t.hongguo.downloadManagerHint),
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
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                [
                  t.hongguo.downloadTaskCount(count: tasks.length, active: active),
                  if (finishedBytes > 0) _formatBytes(finishedBytes),
                ].join(' · '),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
            if (finished)
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(
                  confirmClearFinished(
                    context,
                    title: t.hongguo.downloadClearFinished,
                    clear: () => ref.read(hongguoDownloadsProvider.notifier).clearFinished(),
                  ),
                ),
                child: Text(t.hongguo.downloadClearFinished),
              ),
          ],
        ),
        if (tasks.isEmpty)
          DsEmptyState(
            icon: const DsIcon(DsIcons.download),
            title: Text(t.hongguo.downloadEmpty),
            description: Text(t.hongguo.downloadEmptyDesc),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.folderOpen, size: 14),
                onPressed: () => unawaited(openDownloadedPath(context, directory)),
                child: Text(t.settings.downloadManagerOpenFolder),
              ),
            ],
          )
        else
          DsListSection(
            children: [for (final task in tasks) _HongguoTaskRow(key: ValueKey(task.id), task: task)],
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
              DsListSection(
                children: [
                  for (final task in shown)
                    _HongguoTaskRow(
                      key: ValueKey(task.id),
                      task: task,
                      selected: wide && task.id == selectedTask?.id,
                      onSelect: wide ? () => setState(() => _selectedId = task.id) : null,
                    ),
                ],
              ),
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
                            Text(
                              t.hongguo.downloadManagerTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: colors.text),
                            ),
                            Text(
                              [
                                t.hongguo.downloadTaskCount(count: tasks.length, active: moving),
                                if (totalSpeed > 0) t.common.downloadSpeed(speed: '${_formatBytes(totalSpeed)}/s'),
                                if (finishedBytes > 0) _formatBytes(finishedBytes),
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
          if (task.total > 0) _formatBytes(task.total),
          downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
        ].join(' · '),
        cover: task.cover,
      ),
    );
  }
  return items;
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
}) {
  final total = task.total;
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
      '${_formatBytes(task.speed)}/s',
      '${_formatBytes(task.received)} / ${_formatBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    HongguoDownloadPhase.running => t.hongguo.downloadingUnknown,
    HongguoDownloadPhase.paused when total > 0 =>
      '${t.hongguo.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
    HongguoDownloadPhase.paused => t.hongguo.downloadPhasePaused,
    HongguoDownloadPhase.failed => '$failedBase$retryWait',
    HongguoDownloadPhase.done =>
      '${t.hongguo.downloadPhaseDone} · ${_formatBytes(total > 0 ? total : task.received)}'
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
    onOpenFile: task.phase == HongguoDownloadPhase.done
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
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

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
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
    // The tap can land after the dialog's host is gone (the list rebuilt
    // under it); a dead context must not reach the page's store callback.
    if (!confirmed || !context.mounted) return;
    await ref.read(hongguoDownloadsProvider.notifier).remove(task.id);
  }

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
    await openMediaPreview(context, title: t.hongguo.previewTitle, items: items, initialIndex: index);
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
    // The row previews the drama it downloaded: the series' poster where the
    // task kept one, its name where it predates covers, the episode's title
    // instead of the file name, and the tallest rendition asked for.
    final preview = task.part.isEmpty ? task.title : '${task.title} · ${task.part}';
    return DsListRow(
      selected: selected,
      onPressed: onSelect,
      leading: DsAvatar(
        initials: task.title,
        image: task.cover.isEmpty ? null : cachedImage(task.cover),
        size: DsSize.md,
        toneIndex: DsAvatar.toneFor(task.id),
        semanticLabel: preview,
      ),
      title: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            HongguoDownloadPhase.done => DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.play),
              semanticLabel: t.settings.backgroundPreviewMedia,
              onPressed: () => unawaited(_openPreview(context, ref)),
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
                    ),
                  ),
                ),
              ),
              const DsMenuDivider(),
              if (task.phase == HongguoDownloadPhase.done) ...[
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
                DsMenuItem(
                  leading: const DsIcon(DsIcons.trash2),
                  label: Text(t.hongguo.downloadDeleteFile),
                  destructive: true,
                  onPressed: () => unawaited(_deleteFile(context, ref)),
                ),
                const DsMenuDivider(),
              ],
              DsMenuItem(
                leading: const DsIcon(DsIcons.trash2),
                label: Text(t.settings.downloadRemove),
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

/// Bytes as a person reads them: the biggest unit that stays whole.
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '${value.round()} B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}
