import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint, showLocalMediaPreview;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;
import 'package:pure_live/shared/shared.dart' show LiveWindow, cachedImage;

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
        SettingsHint(t.vod.downloadManagerHint),
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
          )
        else
          DsListSection(
            children: [for (final task in tasks) _VodTaskRow(key: ValueKey(task.id), task: task)],
          ),
      ],
    );
  }
}

/// One part's row: the file's name over its phase's caption and bar, with
/// the actions that phase allows at the end.
final class _VodTaskRow extends ConsumerWidget {
  const _VodTaskRow({required this.task, super.key});

  final VodDownloadItem task;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final moving = task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.paused;
    final caption = switch (task.phase) {
      VodDownloadPhase.queued => t.vod.downloadPhaseQueued,
      VodDownloadPhase.running when total > 0 =>
        '${t.vod.downloading(percent: task.received * 100 ~/ total)}'
            ' · ${_formatBytes(task.speed)}/s'
            ' · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
      VodDownloadPhase.running => t.vod.downloadingUnknown,
      VodDownloadPhase.paused when total > 0 =>
        '${t.vod.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
      VodDownloadPhase.paused => t.vod.downloadPhasePaused,
      VodDownloadPhase.failed =>
        (task.error ?? '').trim().isEmpty
            ? t.vod.downloadPhaseFailed
            : '${t.vod.downloadPhaseFailed} · ${task.error!.trim()}',
      VodDownloadPhase.done =>
        '${t.vod.downloadPhaseDone} · ${_formatBytes(total > 0 ? total : task.received)}'
            ' · ${downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp))}',
    };
    // The row previews the title it downloaded: its own cover where the task
    // kept one (a task queued before covers were kept falls back to its name),
    // the part it is, and the rendition asked for.
    final preview = task.part.isEmpty ? task.title : '${task.title} · ${task.part}';
    final quality = VodQualityChoice.values.where((choice) => choice.qn == task.qn).firstOrNull;
    return DsListRow(
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
          if (quality != null)
            Text(
              quality.label(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              onPressed: () => unawaited(showLocalMediaPreview(context, path: task.filePath, title: task.fileName)),
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final tasks = ref.watch(vodDownloadsProvider);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
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
                          t.vod.downloadManagerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
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
          child: shown.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.download),
                    title: Text(tasks.isEmpty ? t.vod.downloadEmpty : t.vod.downloadFilterEmpty),
                    description: Text(tasks.isEmpty ? t.vod.downloadEmptyDesc : t.vod.downloadFilterEmptyDesc),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(left: inset, right: inset, bottom: DsSpace.s16),
                  children: [
                    DsListSection(
                      children: [for (final task in shown) _VodTaskRow(key: ValueKey(task.id), task: task)],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
