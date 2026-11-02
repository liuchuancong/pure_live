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
import 'package:pure_live/features/settings/settings.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show DownloadDetails, DownloadFilterOption, DownloadWorkspace, LiveWindow, cachedImage, showDownloadDetails;

/// 下载管理 — the station's download queue under Settings → 视频.
///
/// The settings half carries the lanes, the download quality, the danmaku
/// sidecar toggle and the folder the files land in; the task half is one row
/// per part with the phase's own actions — pause and resume while it moves,
/// retry after a failure, and the finished file's preview and clean-up. The
/// same rows live on the sidebar's own 下载管理 page ([VodDownloadsPage]).
final class VodDownloadsPane extends ConsumerWidget {
  /// The pane shown under Settings → Videos → 下载.
  const VodDownloadsPane({super.key});

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.vod.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.videos, selected);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: saved ? t.vod.downloadDirectoryUpdated : t.vod.downloadDirectoryFailed,
        status: saved ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.vod.downloadDirectoryFailed, status: DsStatus.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tasks = ref.watch(vodDownloadsProvider);
    final lanes = ref.watch(vodDownloadSettingsProvider);
    final quality = ref.watch(vodDownloadQualityProvider);
    final retry = ref.watch(vodDownloadRetryProvider);
    final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
    final danmaku = ref.watch(vodDownloadDanmakuProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final active = tasks
        .where((task) => task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.running)
        .length;
    final finished = tasks.any((task) => task.phase == VodDownloadPhase.done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.vod.downloadSettingsTitle),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.download),
              title: t.vod.downloadMaxConcurrent,
              description: t.vod.downloadMaxConcurrentDesc,
              value: lanes,
              options: [for (var count = 1; count <= 5; count++) DsSelectOption(value: count, label: '$count')],
              onChanged: (value) => ref.read(vodDownloadSettingsProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.vod.downloadRetry,
              description: t.vod.downloadRetryDesc,
              value: retry,
              options: [
                for (final count in VodDownloadRetryController.choices)
                  DsSelectOption(
                    value: count,
                    label: count == 0 ? t.vod.downloadRetryOff : t.vod.downloadRetryTimes(count: count),
                  ),
              ],
              onChanged: (value) => ref.read(vodDownloadRetryProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.timer),
              title: t.vod.downloadRetryDelay,
              description: t.vod.downloadRetryDelayDesc,
              value: retryDelay,
              options: [
                for (final seconds in VodDownloadRetryDelayController.choices)
                  DsSelectOption(value: seconds, label: '${seconds}s'),
              ],
              // A row without a retry to wait between stays visible, greyed:
              // a missing row reads as a missing feature.
              onChanged: retry == 0 ? null : (value) => ref.read(vodDownloadRetryDelayProvider.notifier).select(value),
            ),
            SettingsChoiceRow<VodQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.vod.downloadQuality,
              description: t.vod.downloadQualityDesc,
              value: quality,
              options: [
                for (final choice in VodQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (value) => ref.read(vodDownloadQualityProvider.notifier).select(value),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.captions),
              title: t.vod.downloadDanmaku,
              description: t.vod.downloadDanmakuDesc,
              control: DsSwitch(
                value: danmaku,
                onChanged: (value) => ref.read(vodDownloadDanmakuProvider.notifier).set(value: value),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.vod.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(_pickDirectory(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.vod.downloadDirectoryDefault),
              description: Text(t.vod.downloadDirectoryDefaultDesc),
              onPressed: () => unawaited(ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.videos)),
            ),
          ],
        ),
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                t.vod.downloadTaskCount(count: tasks.length, active: active),
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
                    title: t.vod.downloadClearFinished,
                    clear: () => ref.read(vodDownloadsProvider.notifier).clearFinished(),
                  ),
                ),
                child: Text(t.vod.downloadClearFinished),
              ),
          ],
        ),
        if (tasks.isEmpty)
          DsEmptyState(
            icon: const DsIcon(DsIcons.download),
            title: Text(t.vod.downloadEmpty),
            description: Text(t.vod.downloadEmptyDesc),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _vodQueueBlocks(
              tasks,
              rowOf: (task, {required inBlock}) => _VodTaskRow(key: ValueKey(task.id), task: task, inBlock: inBlock),
            ),
          ),
      ],
    );
  }
}

/// One part's row: the file's name over its phase's caption and bar, with
/// the actions that phase allows at the end.
final class _VodTaskRow extends ConsumerWidget {
  const _VodTaskRow({required this.task, this.selected = false, this.onSelect, this.inBlock = false, super.key});

  final VodDownloadItem task;

  /// Whether a header above names this row's archive and its cover. In a block
  /// the row drops both and reads as the part it is.
  final bool inBlock;

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
    await ref.read(vodDownloadsProvider.notifier).remove(task.id);
  }

  Future<void> _deleteFile(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.vod.downloadDeleteFile,
      description: t.vod.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(vodDownloadsProvider.notifier).remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.vod.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  /// Opens the app's own preview on this part, with the queue's other
  /// finished parts beside it and the danmaku the download wrote next to the
  /// video. A part whose file went away after the row was built is said so
  /// rather than quietly showing a neighbour.
  Future<void> _openPreview(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final items = _vodPreviewItems(ref.read(vodDownloadsProvider), t);
    final index = items.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      showDsToast(context: context, title: t.vod.previewUnavailable, status: DsStatus.warning);
      return;
    }
    await openMediaPreview(context, title: t.vod.previewTitle, items: items, initialIndex: index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final moving = task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.paused;
    // The row states the same facts the details do, built by the same
    // function — including the wait before a pending automatic retry.
    final caption = _detailsOf(
      context,
      task,
      t,
      retryLimit: ref.watch(vodDownloadRetryProvider),
      retryDelay: ref.watch(vodDownloadRetryDelayProvider),
      retryPending: controller.hasPendingRetry(task.id),
    ).status;
    // The row previews the title it downloaded: its own cover where the task
    // kept one (a task queued before covers were kept falls back to its name),
    // the part it is, and the rendition asked for. Inside a block the archive's
    // name and its cover belong to the header above it, so the row says only
    // which part it is — the shelf's own `P3 分集名` reading.
    final preview = task.part.isEmpty ? task.title : '${task.title} · ${task.part}';
    final part = task.part.isEmpty ? 'P${task.index}' : 'P${task.index} ${task.part}';
    final quality = VodQualityChoice.values.where((choice) => choice.qn == task.qn).firstOrNull;
    return DsListRow(
      selected: selected,
      onPressed: onSelect,
      leading: inBlock
          ? null
          : DsAvatar(
              initials: task.title,
              image: task.cover.isEmpty ? null : cachedImage(task.cover),
              size: DsSize.md,
              toneIndex: DsAvatar.toneFor(task.id),
              semanticLabel: preview,
            ),
      title: Text(inBlock ? part : preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          if (quality != null)
            Text(
              quality.label(t),
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
            VodDownloadPhase.running => DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.pause),
              semanticLabel: t.settings.downloadPause,
              onPressed: () => unawaited(controller.pause(task.id)),
            ),
            VodDownloadPhase.queued || VodDownloadPhase.paused => DsButton.icon(
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.play),
              semanticLabel: t.settings.downloadResume,
              onPressed: () => unawaited(controller.resume(task.id)),
            ),
            VodDownloadPhase.failed => DsButton.icon(
              size: DsSize.sm,
              icon: const DsIcon(DsIcons.rotateCw),
              semanticLabel: t.common.retry,
              onPressed: () => unawaited(controller.resume(task.id)),
            ),
            VodDownloadPhase.done => DsButton.icon(
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
                final hovered = states.contains(WidgetState.hovered);
                return Padding(
                  padding: const EdgeInsets.all(DsSpace.s4),
                  child: DsIcon(
                    DsIcons.ellipsisVertical,
                    size: theme.sizes.iconSm,
                    color: hovered ? colors.text : colors.textSubtle,
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
                      retryLimit: ref.watch(vodDownloadRetryProvider),
                      retryDelay: ref.watch(vodDownloadRetryDelayProvider),
                      retryPending: ref.read(vodDownloadsProvider.notifier).hasPendingRetry(task.id),
                    ),
                  ),
                ),
              ),
              const DsMenuDivider(),
              if (task.phase == VodDownloadPhase.done) ...[
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
                  label: Text(t.vod.downloadDeleteFile),
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

/// The remaining time the caption carries when it can be computed at all:
/// a known speed and bytes still owed — otherwise the fact is left out
/// rather than guessed.
String? _etaOf(Translations t, {required int speed, required int total, required int received}) {
  if (speed <= 0 || received >= total) return null;
  final seconds = (total - received) ~/ speed;
  final hours = seconds ~/ 3600;
  final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return t.vod.downloadEta(time: hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss');
}

/// What the manager's filter shows.
enum _VodDownloadFilter {
  all,

  /// The queue and everything still owed a file: running, waiting, paused
  /// and the ones that failed.
  active,

  /// The parts that finished and can be watched.
  done;

  String label(Translations t) => switch (this) {
    _VodDownloadFilter.all => t.vod.downloadFilterAll,
    _VodDownloadFilter.active => t.vod.downloadFilterActive,
    _VodDownloadFilter.done => t.vod.downloadFilterDone,
  };
}

/// The station's download manager as its own page: the folder the files land
/// in, the queue with its filters and batch actions, and the finished videos
/// with their in-app preview — the same rows the settings pane carries.
final class VodDownloadsPage extends ConsumerStatefulWidget {
  /// The download manager, opening on the whole queue.
  const VodDownloadsPage({super.key});

  @override
  ConsumerState<VodDownloadsPage> createState() => _VodDownloadsPageState();
}

final class _VodDownloadsPageState extends ConsumerState<VodDownloadsPage> {
  _VodDownloadFilter _filter = _VodDownloadFilter.all;

  /// The row whose facts sit in the wide workspace's right column; null lets
  /// the first visible row speak.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final tasks = ref.watch(vodDownloadsProvider);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(vodDownloadRetryProvider);
    final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
    final moving = tasks
        .where((task) => task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.running)
        .length;
    final stopped = tasks.any((task) => task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed);
    final finished = tasks.where((task) => task.phase == VodDownloadPhase.done).toList();
    // What the queue has already put on disk, the counter's second half.
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    final shown = switch (_filter) {
      _VodDownloadFilter.all => tasks,
      _VodDownloadFilter.active => tasks.where((task) => task.phase != VodDownloadPhase.done).toList(),
      _VodDownloadFilter.done => finished,
    };
    final selectedTask =
        (_selectedId == null ? null : tasks.where((task) => task.id == _selectedId).firstOrNull) ??
        (shown.isEmpty ? null : shown.first);
    Widget queueList({required bool wide}) => shown.isEmpty
        ? Center(
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.download),
              title: Text(tasks.isEmpty ? t.vod.downloadEmpty : t.vod.downloadFilterEmpty),
              description: Text(tasks.isEmpty ? t.vod.downloadEmptyDesc : t.vod.downloadFilterEmptyDesc),
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
            children: _vodQueueBlocks(
              shown,
              rowOf: (task, {required inBlock}) => _VodTaskRow(
                key: ValueKey(task.id),
                task: task,
                inBlock: inBlock,
                selected: wide && task.id == selectedTask?.id,
                onSelect: wide ? () => setState(() => _selectedId = task.id) : null,
              ),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        // A manager with room for three panes reads like a workspace: the
        // filters, the queue, and the selected task's facts. A narrower one
        // keeps the list and the sheet the row menu already offers.
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
                            // opened it; what only this page can answer is how
                            // big the queue is and where the files land.
                            Text(
                              [
                                t.vod.downloadTaskCount(count: tasks.length, active: moving),
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
                                  child: Text(t.vod.downloadPauseAll),
                                ),
                              if (stopped)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: () => unawaited(controller.resumeAll()),
                                  child: Text(t.vod.downloadResumeAll),
                                ),
                              if (finished.isNotEmpty)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: () => unawaited(
                                    confirmClearFinished(
                                      context,
                                      title: t.vod.downloadClearFinished,
                                      clear: controller.clearFinished,
                                    ),
                                  ),
                                  child: Text(t.vod.downloadClearFinished),
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
                        child: DsSegmentedControl<_VodDownloadFilter>(
                          value: _filter,
                          onChanged: (filter) => setState(() => _filter = filter),
                          semanticLabel: t.vod.downloadManagerTitle,
                          segments: [
                            for (final filter in _VodDownloadFilter.values)
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
                  ? DownloadWorkspace<_VodDownloadFilter>(
                      options: [
                        for (final value in _VodDownloadFilter.values)
                          DownloadFilterOption(
                            value: value,
                            icon: switch (value) {
                              _VodDownloadFilter.all => DsIcons.list,
                              _VodDownloadFilter.active => DsIcons.download,
                              _VodDownloadFilter.done => DsIcons.checkCircle,
                            },
                            label: value.label(t),
                            count: switch (value) {
                              _VodDownloadFilter.all => tasks.length,
                              _VodDownloadFilter.active =>
                                tasks.where((task) => task.phase != VodDownloadPhase.done).length,
                              _VodDownloadFilter.done => finished.length,
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

/// The preview page's list for the station's queue: every part that finished,
/// in the queue's own order. A part whose file was cleaned out of the folder
/// stays in the list — the page greys it and says the file is gone, which is
/// what a viewer who just deleted it needs to hear — while a part that never
/// finished has nothing to show and stays out.
List<MediaPreviewItem> _vodPreviewItems(List<VodDownloadItem> tasks, Translations t) {
  final items = <MediaPreviewItem>[];
  for (final task in tasks) {
    if (task.phase != VodDownloadPhase.done) continue;
    final quality = VodQualityChoice.values.where((choice) => choice.qn == task.qn).firstOrNull;
    items.add(
      MediaPreviewItem(
        id: task.id,
        title: task.part.isEmpty ? task.title : '${task.title} · ${task.part}',
        path: task.filePath,
        subtitle: [
          if (quality != null) quality.label(t),
          if (task.total > 0) _formatBytes(task.total),
          downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
        ].join(' · '),
        cover: task.cover,
      ),
    );
  }
  return items;
}

/// One archive's block of the queue: its name, its cover where the queue kept
/// one, how many parts it has, and the parts this list holds of it.
final class _VodDownloadGroup {
  _VodDownloadGroup({required this.title, required this.cover, required this.parts, required this.tasks});

  /// The archive's title, written once for the block.
  final String title;

  /// The archive's cover; the first task in the block that carries one.
  String cover;

  /// How many parts the archive lists.
  final int parts;

  /// The parts, in the queue's own order.
  final List<VodDownloadItem> tasks;
}

/// The queue read by archive: one block per title, in the order the list first
/// names one, the parts inside a block kept as the list has them. A viewer who
/// queued a whole multi-P upload got one row per part, each repeating the same
/// archive title and pasting the same cover thirty times — the file's part is
/// what differs between them, so that is what the row says.
List<_VodDownloadGroup> _vodDownloadGroups(Iterable<VodDownloadItem> tasks) {
  final order = <String>[];
  final blocks = <String, _VodDownloadGroup>{};
  for (final task in tasks) {
    final key = task.bvid.isNotEmpty ? task.bvid : (task.epId > 0 ? 'ep${task.epId}' : task.title);
    final block = blocks[key];
    if (block == null) {
      blocks[key] = _VodDownloadGroup(title: task.title, cover: task.cover, parts: task.parts, tasks: [task]);
      order.add(key);
    } else {
      block.tasks.add(task);
      // A task queued before the queue kept covers still names its archive;
      // the first picture the block holds is the block's.
      if (block.cover.isEmpty) block.cover = task.cover;
    }
  }
  return [for (final key in order) blocks[key]!];
}

/// The line over one archive's parts: its cover where the queue has one, its
/// name once for the block, and how many parts the archive runs to.
final class _VodArchiveHead extends StatelessWidget {
  const _VodArchiveHead({required this.group});

  /// The block being introduced.
  final _VodDownloadGroup group;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
          // The shelf's own reading for the same fact, beside the rows it counts.
          Text('${t.vod.parts} · ${group.parts}', style: theme.typography.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}

/// The queue as blocks of the same archive: an archive whose several parts are
/// all here gets one head and its parts under it; a task standing alone keeps
/// the row it already was, because a layer naming one file names nothing.
/// [rowOf] builds the row so a page can hand its own selection through.
List<Widget> _vodQueueBlocks(
  List<VodDownloadItem> tasks, {
  required Widget Function(VodDownloadItem task, {required bool inBlock}) rowOf,
}) {
  final blocks = <Widget>[];
  for (final group in _vodDownloadGroups(tasks)) {
    final grouped = group.tasks.length > 1;
    if (grouped) blocks.add(_VodArchiveHead(group: group));
    blocks.add(
      Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.s8),
        child: DsListSection(children: [for (final task in group.tasks) rowOf(task, inBlock: grouped)]),
      ),
    );
  }
  return blocks;
}

/// The facts the right column, the 详情 sheet and the row's own caption show
/// for [task] — one construction, so the three cannot drift. [retryLimit] and
/// [retryDelay] let a failed row say when the queue will come back for it
/// instead of leaving the wait silent.
DownloadDetails _detailsOf(
  BuildContext context,
  VodDownloadItem task,
  Translations t, {
  int retryLimit = 0,
  int retryDelay = 0,
  bool retryPending = false,
}) {
  final total = task.total;
  // A failed row says what went wrong and, when the queue still owes it an
  // automatic retry, how long the wait is.
  final failedBase = (task.error ?? '').trim().isEmpty
      ? t.vod.downloadPhaseFailed
      : '${t.vod.downloadPhaseFailed} · ${task.error!.trim()}';
  final retryWait = retryPending && retryLimit > 0
      ? ' · ${t.common.downloadRetryPending(delay: retryDelay, left: (retryLimit - task.attempts).clamp(0, 1 << 20))}'
      : '';
  final caption = switch (task.phase) {
    VodDownloadPhase.queued => t.vod.downloadPhaseQueued,
    VodDownloadPhase.running when total > 0 => [
      t.vod.downloading(percent: task.received * 100 ~/ total),
      '${_formatBytes(task.speed)}/s',
      '${_formatBytes(task.received)} / ${_formatBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    VodDownloadPhase.running => t.vod.downloadingUnknown,
    VodDownloadPhase.paused when total > 0 =>
      '${t.vod.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
    VodDownloadPhase.paused => t.vod.downloadPhasePaused,
    VodDownloadPhase.failed => '$failedBase$retryWait',
    VodDownloadPhase.done =>
      '${t.vod.downloadPhaseDone} · ${_formatBytes(total > 0 ? total : task.received)}'
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
    onOpenFile: task.phase == VodDownloadPhase.done
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
  );
}
