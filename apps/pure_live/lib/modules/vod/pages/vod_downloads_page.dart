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
import 'package:pure_live/features/settings/settings.dart' show SettingsChoiceRow, SettingsConfigRow, openModuleItem;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadDetailsPane,
        DownloadQueueAction,
        DownloadQueueHeader,
        LiveWindow,
        NavigationItem,
        cachedImage,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;

/// Whether a finished part's file is still on disk where its row says.
///
/// Only a `done` row can be missing: a queued, paused or failed part has no
/// finished file to look for — its bytes are in the `.part` beside the target,
/// and the row is a transfer to carry on, not a file to open. Answering this
/// once per row build (one stat, never a folder scan) is what lets the queue
/// say 文件不在了 instead of offering an 打开文件 that fails.
bool _vodFileMissing(VodDownloadItem task) =>
    task.phase == VodDownloadPhase.done && !downloadFilePresent(task.filePath);

/// Takes one part's record out of the queue; the file, if it is there, stays.
///
/// Reached from the row menu and from the wide workspace's facts column, so a
/// row that only names a file the viewer moved can be cleared from wherever it
/// was noticed. The queue's remove is never silent, because 移除 reads twice —
/// as "off this list" and as "gone" — and only the second would cost bytes.
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
  // The tap can land after the dialog's host is gone (the list rebuilt
  // under it); a dead context must not reach the page's store callback.
  if (!confirmed || !context.mounted) return;
  await ref.read(vodDownloadsProvider.notifier).remove(id);
}

/// Opens the app's own preview on [task], with the queue's other finished parts
/// beside it and the danmaku the download wrote next to the video.
///
/// The row card's play button, its table twin and its menu all come through
/// here, so the run a part joins is one list rather than three that drift.
Future<void> _openVodPreview(BuildContext context, WidgetRef ref, VodDownloadItem task) async {
  final t = context.t;
  final items = _vodPreviewItems(ref.read(vodDownloadsProvider), t);
  final index = items.indexWhere((item) => item.id == task.id);
  if (index < 0) {
    showDsToast(context: context, title: t.vod.previewUnavailable, status: DsStatus.warning);
    return;
  }
  await openMediaPreview(
    context,
    title: t.vod.previewTitle,
    items: items,
    initialIndex: index,
    // A file deleted from the player leaves the row pointing at nothing: the
    // task goes with it (its bytes are already off disk), so the queue cannot
    // offer a part that will only fail to open.
    onDeleted: (item) => ref.read(vodDownloadsProvider.notifier).remove(item.id),
  );
}

/// What a row's phase says about itself, as the table's state column shows it:
/// the phase, and how far a transfer still owed bytes has got. The phase's name
/// comes from [_vodPhaseLabel], the same words the filter panel lists it by, so
/// one phase is not said two ways on one page.
Widget _vodPhaseBadge(BuildContext context, VodDownloadItem task, {required bool missing}) {
  final t = context.t;
  // A finished row whose file the viewer moved or deleted is said here, in the
  // same words the row's own caption and the facts column use: the record is
  // true of the transfer, not of the disk.
  if (task.phase == VodDownloadPhase.done && missing) {
    return DsBadge(status: DsStatus.danger, label: Text(t.common.previewFileMissing));
  }
  // A running row counts itself out loud; one that never got its total only
  // says it is moving.
  if (task.phase == VodDownloadPhase.running && task.total > 0) {
    return DsBadge(
      status: DsStatus.info,
      label: Text(t.settings.downloadPercent(percent: '${task.received * 100 ~/ task.total}')),
    );
  }
  return DsBadge(
    status: switch (task.phase) {
      VodDownloadPhase.done => DsStatus.success,
      VodDownloadPhase.running => DsStatus.info,
      VodDownloadPhase.paused => DsStatus.warning,
      VodDownloadPhase.failed => DsStatus.danger,
      VodDownloadPhase.queued => DsStatus.neutral,
    },
    label: Text(_vodPhaseLabel(t, task.phase)),
  );
}

/// The phases in the order a queue reads: what is moving, what waits for a
/// lane, what stopped on purpose, what stopped on its own, what landed.
int _vodPhaseRank(VodDownloadPhase phase) => switch (phase) {
  VodDownloadPhase.running => 0,
  VodDownloadPhase.queued => 1,
  VodDownloadPhase.paused => 2,
  VodDownloadPhase.failed => 3,
  VodDownloadPhase.done => 4,
};

/// The one verb a part's phase allows: stop a transfer, carry a waiting or
/// stopped one on, fetch a failed one again, or watch the part that landed.
///
/// The card and the table name the same verb for the same phase and say it the
/// same way, so the two shapes cannot drift apart; everything else a row can do
/// sits in [_vodRowMenu].
Widget _vodPhaseVerb(BuildContext context, WidgetRef ref, VodDownloadItem task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(vodDownloadsProvider.notifier);
  return switch (task.phase) {
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
    // A part whose file is gone has nothing to preview: the button keeps its
    // place, shows what happened and stays out of reach, so the row cannot
    // promise an opening that only fails.
    VodDownloadPhase.done => DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      icon: DsIcon(missing ? DsIcons.fileX : DsIcons.play),
      semanticLabel: missing ? t.common.previewFileMissing : t.settings.backgroundPreviewMedia,
      onPressed: missing ? null : () => unawaited(_openVodPreview(context, ref, task)),
    ),
  };
}

/// Everything one part can be asked for beyond its phase's own verb.
///
/// The card's trailing menu and the table's row menu read the same list: 详情,
/// and for a finished part the file's own ways out — open it, open the folder
/// beside it, delete it — ending in the record's removal. A part whose file went
/// away keeps the folder (what is left beside it is still worth seeing) and
/// drops the two verbs that act on a file that is not there.
List<Widget> _vodRowMenu(BuildContext context, WidgetRef ref, VodDownloadItem task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(vodDownloadsProvider.notifier);
  Future<void> deleteFile() async {
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
      await controller.remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.vod.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  return [
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
            retryLimit: ref.read(vodDownloadRetryProvider),
            retryDelay: ref.read(vodDownloadRetryDelayProvider),
            retryPending: controller.hasPendingRetry(task.id),
            onRemove: () => unawaited(_removeRecord(context, ref, task.id)),
          ),
        ),
      ),
    ),
    const DsMenuDivider(),
    if (task.phase == VodDownloadPhase.done) ...[
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
          label: Text(t.vod.downloadDeleteFile),
          destructive: true,
          onPressed: () => unawaited(deleteFile()),
        ),
        const DsMenuDivider(),
      ],
    ],
    DsMenuItem(
      leading: const DsIcon(DsIcons.trash2),
      // The one action a gone file still has: the record goes, the name says
      // so rather than 删除文件 over an empty path.
      label: Text(missing ? t.common.downloadRemoveFromList : t.settings.downloadRemove),
      destructive: true,
      onPressed: () => unawaited(_removeRecord(context, ref, task.id)),
    ),
  ];
}

/// 下载管理 — the station's download settings under Settings → 视频.
///
/// The pane carries the lanes, the download quality, the danmaku sidecar
/// toggle and the folder the files land in, then one line that says how much
/// the queue holds and opens the station's own 下载管理 page ([VodDownloadsPage])
/// for the rest. It used to draw the whole queue here too, which made one
/// thing two entrances: the settings half could not carry the speed, the group
/// verbs or the table, so the same tasks read differently depending on which
/// door the viewer came through.
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
    // What the queue has already put on disk — the line's second half, so the
    // pane says how much there is and not only how many rows.
    final finishedBytes = tasks
        .where((task) => task.phase == VodDownloadPhase.done)
        .fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
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
        // The queue itself is one row and one tap away, on the station's own
        // 下载管理 page: this pane drew the same tasks a second time, with a
        // weaker summary (no speed, no group verbs) and no room for the table,
        // so the same thing had two entrances that did not agree. Settings keeps
        // the choices and the way out; the list lives in one place.
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.download),
              title: Text(t.vod.downloadManagerTitle),
              description: Text(
                [
                  t.vod.downloadTaskCount(count: tasks.length, active: active),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  directory,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              showChevron: true,
              onPressed: () => openModuleItem(context, ref, NavigationItem.vodDownloads),
            ),
          ],
        ),
      ],
    );
  }
}

/// One part's row, as the window too narrow for a table shows it: the file's
/// name over its phase's caption and bar, with the actions that phase allows at
/// the end. The table shape reads the same phase, verb and menu through
/// [_vodPhaseBadge], [_vodPhaseVerb] and [_vodRowMenu], so the two agree.
final class _VodTaskRow extends ConsumerWidget {
  const _VodTaskRow({required this.task, this.inBlock = false, super.key});

  final VodDownloadItem task;

  /// Whether a header above names this row's archive and its cover. In a block
  /// the row drops both and reads as the part it is.
  final bool inBlock;

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
    // The file the row names, asked once: a finished part whose bytes were
    // moved elsewhere still plays no part, and its 打开 / 删除文件 items would
    // only fail.
    final missing = _vodFileMissing(task);
    return DsListRow(
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
          _vodPhaseVerb(context, ref, task, missing: missing),
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
            items: _vodRowMenu(context, ref, task, missing: missing),
          ),
        ],
      ),
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
  return t.vod.downloadEta(time: hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss');
}

/// The phase's own word, said the same way in a row's badge and in the filter
/// panel: one phase, one spelling.
String _vodPhaseLabel(Translations t, VodDownloadPhase phase) => switch (phase) {
  VodDownloadPhase.queued => t.vod.downloadPhaseQueued,
  VodDownloadPhase.running => t.settings.downloadStatusRunning,
  VodDownloadPhase.paused => t.vod.downloadPhasePaused,
  VodDownloadPhase.failed => t.vod.downloadPhaseFailed,
  VodDownloadPhase.done => t.vod.downloadPhaseDone,
};

/// The station's download manager as its own page: the queue as a table with
/// its search, its filters and its batch verbs, the finished parts opened in
/// the app's own preview, and the folder they land in.
///
/// A window too narrow for the table's columns keeps the row cards the station
/// already drew — a part's cover and its progress bar say more there than four
/// ellipsised cells would, and the head folds its verbs into 更多 instead of
/// pushing the queue away.
final class VodDownloadsPage extends ConsumerStatefulWidget {
  /// The download manager, opening on the whole queue.
  const VodDownloadsPage({super.key});

  @override
  ConsumerState<VodDownloadsPage> createState() => _VodDownloadsPageState();
}

final class _VodDownloadsPageState extends ConsumerState<VodDownloadsPage> {
  /// What the search box holds, matched against the archive, its part and the
  /// file the queue wrote.
  String _query = '';

  /// The phases ticked in the panel; none ticked reads as every phase, so an
  /// empty set is the queue's own 全部 rather than a hidden filter.
  final Set<VodDownloadPhase> _phases = {};

  /// Whether a row must still name a file the disk holds.
  bool _playableOnly = false;

  /// The table's sorted column.
  DsTableSort? _sort;

  /// The ticked rows — the batch verbs' objects.
  final Set<Object> _selected = {};

  /// The row the wide window's facts column speaks about; null lets the first
  /// visible row speak.
  String? _factsId;

  /// Asks the disk again. The queue is a live store rather than a folder read,
  /// so the one thing a refresh can add here is the stat behind 文件不在了:
  /// every finished row is asked once more whether its bytes are where the row
  /// says they are.
  int _recheck = 0;

  /// The rows on screen: searched, cut to the ticked phases, and to the files
  /// still on disk when that is ticked — in the order the store keeps them, so
  /// the table's own sort is the only thing that reorders a queue.
  List<VodDownloadItem> _visible(List<VodDownloadItem> tasks) {
    final query = _query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((_phases.isEmpty || _phases.contains(task.phase)) &&
            (!_playableOnly || (task.phase == VodDownloadPhase.done && downloadFilePresent(task.filePath))) &&
            (query.isEmpty ||
                task.title.toLowerCase().contains(query) ||
                task.part.toLowerCase().contains(query) ||
                task.fileName.toLowerCase().contains(query)))
          task,
    ];
  }

  /// The ticked rows, in the queue's order.
  List<VodDownloadItem> _picked(List<VodDownloadItem> tasks) => [
    for (final task in tasks)
      if (_selected.contains(task.id)) task,
  ];

  /// Runs [verb] over [rows], one after another: the store writes per task, so
  /// a batch is a run of writes rather than a call of its own.
  Future<void> _runOver(List<VodDownloadItem> rows, Future<void> Function(VodDownloadsController, String) verb) async {
    final controller = ref.read(vodDownloadsProvider.notifier);
    for (final task in rows) {
      await verb(controller, task.id);
    }
  }

  /// Drops the ticked records after one ask; the files they name stay on disk,
  /// which is what the body says rather than leaves to be guessed.
  Future<void> _removePicked(List<VodDownloadItem> picked) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await _runOver(picked, (controller, id) => controller.remove(id));
    if (mounted) setState(_selected.clear);
  }

  /// Deletes the ticked parts' files and records after one ask. The store's own
  /// remove answers for a file that already went away, so a batch that names
  /// more than the disk holds says so instead of quietly reporting a smaller
  /// number.
  Future<void> _deletePicked(List<VodDownloadItem> picked) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.vod.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    final controller = ref.read(vodDownloadsProvider.notifier);
    for (final task in picked) {
      try {
        await controller.remove(task.id, deleteFile: true);
      } on Object {
        if (mounted) showDsToast(context: context, title: t.vod.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
    if (mounted) setState(_selected.clear);
  }

  /// The queue's conditions, behind the head's one entry: which phases show and
  /// whether a row must still name a file the disk holds. Nothing else about a
  /// queue is a condition — where it lands is a setting, and its size is what
  /// the head already says.
  Future<void> _openFilter(List<VodDownloadItem> tasks) async {
    final t = context.t;
    final picked = {..._phases};
    var playable = _playableOnly;
    void apply() => setState(() {
      _phases
        ..clear()
        ..addAll(picked);
      _playableOnly = playable;
      _selected.clear();
    });
    await showDsPanel<void>(
      context: context,
      builder: (panelContext) => DsPanel(
        title: Text(t.settings.downloadFilterTitle),
        child: DsListSection(
          children: [
            for (final phase in VodDownloadPhase.values)
              DsListRow(
                title: Text(_vodPhaseLabel(t, phase)),
                detail: Text('${tasks.where((task) => task.phase == phase).length}'),
                trailing: DsCheckbox(
                  value: picked.contains(phase),
                  onChanged: (value) {
                    if (value == true) {
                      picked.add(phase);
                    } else {
                      picked.remove(phase);
                    }
                    apply();
                  },
                ),
              ),
            DsListRow(
              title: Text(t.settings.downloadFilterPlayable),
              trailing: DsSwitch(
                value: playable,
                onChanged: (value) {
                  playable = value;
                  apply();
                },
              ),
            ),
            DsListRow(
              title: Text(t.settings.downloadFilterReset),
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tasks = ref.watch(vodDownloadsProvider);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(vodDownloadRetryProvider);
    final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
    // A tick on a row the queue no longer holds no longer counts, and the batch
    // bar would otherwise promise an action on nothing.
    _selected.removeWhere((id) => !tasks.any((task) => task.id == id));
    final shown = _visible(tasks);
    // One stat per visible row per read, not one per cell: the same part answers
    // through its badge, its verb and its menu, and asking the disk three times
    // for one row is how a queue of a hundred parts starts to cost a frame.
    final missing = {for (final task in shown) task.id: _vodFileMissing(task)};
    final moving = tasks
        .where((task) => task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.running)
        .length;
    final stopped = tasks.any((task) => task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed);
    final finished = tasks.where((task) => task.phase == VodDownloadPhase.done).toList();
    // What the queue has already put on disk, the summary's second half.
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    // What it is pulling right now, its third half: the lanes' own total, so a
    // running row's speed is not asked of every row to be read once.
    final speed = tasks.fold<int>(0, (sum, task) => sum + task.speed);
    final picked = _picked(tasks);
    final pausable = picked
        .where((task) => task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.queued)
        .toList();
    final resumable = picked
        .where((task) => task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed)
        .toList();
    final factsTask = shown.where((task) => task.id == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final filterActive = _phases.isNotEmpty || _playableOnly;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The table starts where a queue's columns fit; below it the parts keep
        // the row cards, with their cover and their bar.
        final asTable = width >= LiveWindow.table;
        // The facts column rides beside a table only where the table still
        // keeps its columns after 340 pixels are taken from it.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        // A table says it has nothing through its own slot; the card list
        // needs the page's empty state, because a list of one block is not a
        // queue at all.
        final queue = asTable
            ? _table(
                t,
                shown,
                narrow: width < 720,
                withFacts: withFacts,
                tasks: tasks,
                isMissing: (task) => missing[task.id] ?? false,
              )
            : shown.isEmpty
            ? _empty(t, tasks, directory)
            : _cards(shown);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, DsSpace.s12, _inset, DsSpace.s8),
              child: DownloadQueueHeader(
                summary: [
                  t.vod.downloadTaskCount(count: tasks.length, active: moving),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  if (speed > 0) t.common.downloadSpeed(speed: '${formatDownloadBytes(speed)}/s'),
                ].join(' · '),
                directory: directory,
                searchHint: t.settings.downloadSearchPlaceholder,
                query: _query,
                onQuery: (value) => setState(() {
                  _query = value;
                  _selected.clear();
                }),
                filterLabel: t.settings.downloadFilterLabel,
                filterActive: filterActive,
                onFilter: () => unawaited(_openFilter(tasks)),
                actions: [
                  DownloadQueueAction(
                    label: t.settings.downloadManagerOpenFolder,
                    icon: DsIcons.folderOpen,
                    onPressed: () => unawaited(openDownloadedPath(context, directory)),
                  ),
                  if (moving > 0)
                    DownloadQueueAction(
                      label: t.vod.downloadPauseAll,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(controller.pauseAll()),
                    ),
                  if (stopped)
                    DownloadQueueAction(
                      label: t.vod.downloadResumeAll,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(controller.resumeAll()),
                    ),
                  if (finished.isNotEmpty)
                    DownloadQueueAction(
                      label: t.vod.downloadClearFinished,
                      icon: DsIcons.trash2,
                      destructive: true,
                      onPressed: () => unawaited(
                        confirmClearFinished(
                          context,
                          title: t.vod.downloadClearFinished,
                          clear: controller.clearFinished,
                        ),
                      ),
                    ),
                  DownloadQueueAction(
                    label: t.settings.downloadRecheck,
                    icon: DsIcons.refresh,
                    onPressed: () => setState(() => _recheck++),
                  ),
                ],
                selectedLabel: picked.isEmpty ? null : t.settings.downloadSelectedCount(count: picked.length),
                selectionActions: [
                  if (pausable.isNotEmpty)
                    DownloadQueueAction(
                      label: t.settings.downloadPause,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(_runOver(pausable, (controller, id) => controller.pause(id))),
                    ),
                  if (resumable.isNotEmpty)
                    DownloadQueueAction(
                      label: t.settings.downloadResume,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(_runOver(resumable, (controller, id) => controller.resume(id))),
                    ),
                  DownloadQueueAction(
                    label: t.settings.downloadRemove,
                    icon: DsIcons.trash2,
                    destructive: true,
                    onPressed: () => unawaited(_removePicked(picked)),
                  ),
                  if (picked.any((task) => task.phase == VodDownloadPhase.done))
                    DownloadQueueAction(
                      label: t.vod.downloadDeleteFile,
                      icon: DsIcons.fileX,
                      destructive: true,
                      onPressed: () => unawaited(_deletePicked(picked)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s16,
                children: [
                  Expanded(child: queue),
                  if (withFacts)
                    SizedBox(
                      width: LiveWindow.downloadDetails,
                      child: DownloadDetailsPane(
                        details: factsTask == null
                            ? null
                            : _detailsOf(
                                context,
                                factsTask,
                                t,
                                retryLimit: retry,
                                retryDelay: retryDelay,
                                retryPending: controller.hasPendingRetry(factsTask.id),
                                onRemove: () => unawaited(_removeRecord(context, ref, factsTask.id)),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The queue as the row cards: one block per archive, its head carrying the
  /// verbs for the parts it holds.
  Widget _cards(List<VodDownloadItem> shown) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: _vodQueueBlocks(
      shown,
      rowOf: (task, {required inBlock}) => _VodTaskRow(key: ValueKey(task.id), task: task, inBlock: inBlock),
    ),
  );

  /// Where the page keeps its own margin: the head and the queue read the same
  /// number, so their left edges line up.
  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  /// Nothing on screen: what the queue holds in total answers better than an
  /// empty table would, because a filtered-out task is still a task the viewer
  /// has to un-tick to see.
  Widget _empty(Translations t, List<VodDownloadItem> tasks, String directory) => Center(
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
  );

  /// The queue as a table: the part and what became of it, then the bytes, the
  /// moment and the one verb its phase allows.
  ///
  /// A narrow table drops the two columns a row can do without — the size of a
  /// part it has not finished is not the fact that decides anything, and the
  /// facts column says the rest. Pressing a row is the facts column's own verb,
  /// so a window with no facts column lets a click do what its checkbox does.
  Widget _table(
    Translations t,
    List<VodDownloadItem> rows, {
    required bool narrow,
    required bool withFacts,
    required List<VodDownloadItem> tasks,
    required bool Function(VodDownloadItem task) isMissing,
  }) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, DsSpace.s12),
      child: DsTable<VodDownloadItem>(
        semanticLabel: t.vod.downloadManagerTitle,
        style: const DsTableStyle(rowHeight: 56),
        rowsVersion: _recheck,
        columns: [
          DsTableColumn<VodDownloadItem>(
            id: 'name',
            label: t.settings.downloadColumnFile,
            value: (task) => task.title,
            sortable: true,
            width: const DsTableColumnWidth.flex(3, 160),
            // Two lines, as the library's rows do: the archive the part belongs
            // to over the part itself, which is the half a queue of thirty parts
            // actually differs on.
            cell: (context, task) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  task.part.isEmpty ? 'P${task.index}' : 'P${task.index} ${task.part}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: theme.colors.textSubtle),
                ),
              ],
            ),
          ),
          DsTableColumn<VodDownloadItem>(
            id: 'status',
            label: t.common.downloadStatus,
            sortable: true,
            comparator: (a, b) => _vodPhaseRank(a.phase).compareTo(_vodPhaseRank(b.phase)),
            width: const DsTableColumnWidth.intrinsic(min: 104),
            cell: (context, task) => _vodPhaseBadge(context, task, missing: isMissing(task)),
          ),
          if (!narrow)
            DsTableColumn<VodDownloadItem>(
              id: 'size',
              label: t.settings.downloadColumnSize,
              value: (task) => task.total > 0 ? task.total : task.received,
              text: (task) => formatDownloadBytes(task.total > 0 ? task.total : task.received),
              numeric: true,
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 88),
            ),
          if (!narrow)
            DsTableColumn<VodDownloadItem>(
              id: 'time',
              label: t.settings.downloadColumnTime,
              value: (task) => task.stamp,
              text: (task) => downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 92),
            ),
          DsTableColumn<VodDownloadItem>(
            id: 'actions',
            label: t.settings.downloadColumnActions,
            alignment: DsTableCellAlignment.end,
            // A builder-only column measures nothing, so it names its width.
            width: const DsTableColumnWidth.fixed(48),
            cell: (context, task) => _vodPhaseVerb(context, ref, task, missing: isMissing(task)),
          ),
        ],
        rows: rows,
        rowKey: (task) => task.id,
        sort: _sort,
        onSortChanged: (sort) => setState(() => _sort = sort),
        selected: _selected,
        onSelectionChanged: (next) => setState(() {
          _selected
            ..clear()
            ..addAll(next);
        }),
        onRowPressed: withFacts
            ? (task) => setState(() {
                _factsId = task.id;
              })
            : null,
        rowMenuBuilder: (context, task) => _vodRowMenu(context, ref, task, missing: isMissing(task)),
        showRowMenuButton: true,
        emptyView: _empty(t, tasks, ref.read(appPathsProvider).videos.path),
      ),
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
/// name once for the block, how many parts the archive runs to, and the verbs
/// that act on the whole block. A ten-part upload whose every action sits on
/// the row is ten taps, and a queue that counts tasks for the whole list and
/// for none of its blocks is a flat list wearing group headers.
final class _VodArchiveHead extends ConsumerWidget {
  const _VodArchiveHead({required this.group});

  /// The block being introduced.
  final _VodDownloadGroup group;

  /// Runs [verb] over every id it was handed. The store writes per task, so
  /// the ids go one after another rather than all at once.
  Future<void> _apply(
    WidgetRef ref,
    List<String> ids,
    Future<void> Function(VodDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(vodDownloadsProvider.notifier);
    for (final id in ids) {
      await verb(controller, id);
    }
  }

  /// The block's own phases, read when the action is asked for rather than when
  /// the line was painted: a task that finished in between is no longer
  /// something to pause.
  ({List<String> pausable, List<String> resumable}) _phases() => (
    pausable: [
      for (final task in group.tasks)
        if (task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.queued) task.id,
    ],
    resumable: [
      for (final task in group.tasks)
        if (task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed) task.id,
    ],
  );

  Future<void> _removeBlock(BuildContext context, WidgetRef ref, Translations t) async {
    final ids = [for (final task in group.tasks) task.id];
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadRemove,
      // Which upload, and how many of its parts: the row's own body says 这条
      // 记录, and a block would be answering for ten of them.
      description: '${group.title} · ${t.vod.downloadTaskCount(count: ids.length, active: _phases().pausable.length)}',
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
          // The shelf's own reading for the same fact, beside the rows it counts.
          Text('${t.vod.parts} · ${group.parts}', style: theme.typography.caption.copyWith(color: colors.textMuted)),
          // A head is only built for a block of several parts, so every verb here
          // already has more than one object; a part standing alone is served by
          // its own row and gets no second place to be pressed.
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
                  onPressed: () => unawaited(_apply(ref, phases.resumable, (controller, id) => controller.resume(id))),
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
  VoidCallback? onRemove,
}) {
  final total = task.total;
  // One stat, only for a row that claims a finished file.
  final missing = _vodFileMissing(task);
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
      '${formatDownloadBytes(task.speed)}/s',
      '${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    VodDownloadPhase.running => t.vod.downloadingUnknown,
    VodDownloadPhase.paused when total > 0 =>
      '${t.vod.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
    VodDownloadPhase.paused => t.vod.downloadPhasePaused,
    VodDownloadPhase.failed => '$failedBase$retryWait',
    // A finished row whose file the viewer moved or deleted says so here: the
    // record is true of the transfer, not of the disk, and the queue must not
    // go on offering 打开文件 over a path that answers nothing.
    VodDownloadPhase.done =>
      '${missing ? t.common.previewFileMissing : t.vod.downloadPhaseDone} · '
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
    onOpenFile: task.phase == VodDownloadPhase.done && !missing
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
    onRemove: onRemove,
  );
}
