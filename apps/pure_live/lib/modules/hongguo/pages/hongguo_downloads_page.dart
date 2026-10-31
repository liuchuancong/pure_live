import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/settings/pages/local_media_page.dart' show showLocalMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsHint;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/shared/shared.dart' show LiveWindow, cachedImage;

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
          )
        else
          DsListSection(
            children: [for (final task in tasks) _HongguoTaskRow(key: ValueKey(task.id), task: task)],
          ),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final tasks = ref.watch(hongguoDownloadsProvider);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
    final moving = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    final stopped = tasks.any(
      (task) => task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed,
    );
    final finished = tasks.where((task) => task.phase == HongguoDownloadPhase.done).toList();
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    final shown = switch (_filter) {
      _HongguoDownloadFilter.all => tasks,
      _HongguoDownloadFilter.active => tasks.where((task) => task.phase != HongguoDownloadPhase.done).toList(),
      _HongguoDownloadFilter.done => finished,
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
                          t.hongguo.downloadManagerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                        Text(
                          [
                            t.hongguo.downloadTaskCount(count: tasks.length, active: moving),
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
          child: shown.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.download),
                    title: Text(tasks.isEmpty ? t.hongguo.downloadEmpty : t.hongguo.downloadFilterEmpty),
                    description: Text(tasks.isEmpty ? t.hongguo.downloadEmptyDesc : t.hongguo.downloadFilterEmptyDesc),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(left: inset, right: inset, bottom: DsSpace.s16),
                  children: [
                    DsListSection(
                      children: [for (final task in shown) _HongguoTaskRow(key: ValueKey(task.id), task: task)],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One episode's row: the file's name over its phase's caption and bar, with
/// the actions that phase allows at the end.
final class _HongguoTaskRow extends ConsumerWidget {
  const _HongguoTaskRow({required this.task, super.key});

  final HongguoDownloadItem task;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final moving = task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.paused;
    final caption = switch (task.phase) {
      HongguoDownloadPhase.queued => t.hongguo.downloadPhaseQueued,
      HongguoDownloadPhase.running when total > 0 =>
        '${t.hongguo.downloading(percent: task.received * 100 ~/ total)}'
            ' · ${_formatBytes(task.speed)}/s'
            ' · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
      HongguoDownloadPhase.running => t.hongguo.downloadingUnknown,
      HongguoDownloadPhase.paused when total > 0 =>
        '${t.hongguo.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${_formatBytes(task.received)} / ${_formatBytes(total)}',
      HongguoDownloadPhase.paused => t.hongguo.downloadPhasePaused,
      HongguoDownloadPhase.failed =>
        (task.error ?? '').trim().isEmpty
            ? t.hongguo.downloadPhaseFailed
            : '${t.hongguo.downloadPhaseFailed} · ${task.error!.trim()}',
      HongguoDownloadPhase.done =>
        '${t.hongguo.downloadPhaseDone} · ${_formatBytes(total > 0 ? total : task.received)}'
            ' · ${downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp))}',
    };
    // The row previews the drama it downloaded: the series' poster where the
    // task kept one, its name where it predates covers, the episode's title
    // instead of the file name, and the tallest rendition asked for.
    final preview = task.part.isEmpty ? task.title : '${task.title} · ${task.part}';
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
          Text(
            '${task.maxHeight}P',
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
