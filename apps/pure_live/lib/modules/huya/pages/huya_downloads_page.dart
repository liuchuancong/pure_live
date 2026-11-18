import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';
import 'package:pure_live/modules/huya/pages/huya_downloads_pane.dart'
    show huyaDetailsOf, huyaFileMissing, huyaTaskCard;
import 'package:pure_live/shared/shared.dart'
    show DownloadQueueAction, DownloadQueueHeader, LiveWindow, formatDownloadBytes;
import 'package:pure_live/shared/widgets/app_dialog.dart' show showAppConfirm;
import 'package:pure_live/shared/widgets/app_panel.dart' show AppPanel, showAppPanel;
import 'package:pure_live/shared/widgets/download_workspace.dart' show DownloadDetailsPane;

/// 虎牙视频's download queue as its own page — the station's videos on one
/// surface with the manager's own head: how big the queue is, the search, the
/// phase filter, the folder's row and the queue verbs, all over the same
/// shared download cards every manager wears. Reached from the rail, where
/// the other stations keep their download managers.
final class HuyaDownloadsPage extends ConsumerStatefulWidget {
  /// The page.
  const HuyaDownloadsPage({super.key});

  @override
  ConsumerState<HuyaDownloadsPage> createState() => _HuyaDownloadsPageState();
}

final class _HuyaDownloadsPageState extends ConsumerState<HuyaDownloadsPage> {
  String _query = '';
  final Set<HuyaDownloadPhase> _statuses = {};

  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  bool _matches(HuyaDownloadItem task) {
    if (_query.isNotEmpty) {
      final word = _query.toLowerCase();
      final hit = task.title.toLowerCase().contains(word) || task.fileName.toLowerCase().contains(word);
      if (!hit) return false;
    }
    if (_statuses.isEmpty) return true;
    return _statuses.contains(task.phase);
  }

  Future<void> _openFilter() async {
    final t = context.t;
    await showAppPanel<void>(
      context: context,
      builder: (context) => AppPanel(
        title: Text(t.settings.downloadFilterLabel),
        child: DsListSection(
          children: [
            for (final phase in HuyaDownloadPhase.values)
              DsListRow(
                title: Text(switch (phase) {
                  HuyaDownloadPhase.queued => t.settings.downloadStatusQueued,
                  HuyaDownloadPhase.running => t.settings.downloadStatusRunning,
                  HuyaDownloadPhase.paused => t.settings.downloadStatusPaused,
                  HuyaDownloadPhase.failed => t.settings.downloadStatusFailed,
                  HuyaDownloadPhase.done => t.settings.downloadStatusDone,
                }),
                trailing: _statuses.contains(phase) ? const DsIcon(DsIcons.check, size: 14) : null,
                onPressed: () => setState(() {
                  _statuses.contains(phase) ? _statuses.remove(phase) : _statuses.add(phase);
                }),
              ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearFinished(List<HuyaDownloadItem> tasks) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadClearFinished,
      description: t.settings.downloadClearFinishedBody,
      confirmLabel: t.settings.downloadClearFinished,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(huyaDownloadsProvider.notifier).clearFinished();
  }

  /// The row the wide window's facts column speaks about; null lets the first
  /// visible row speak.
  String? _factsId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final tasks = ref.watch(huyaDownloadsProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final shown = tasks.where(_matches).toList();
    final moving = tasks
        .where((task) => task.phase == HuyaDownloadPhase.running || task.phase == HuyaDownloadPhase.queued)
        .length;
    final finishedBytes = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.phase == HuyaDownloadPhase.done ? task.total : 0),
    );
    final speed = tasks.fold<int>(0, (sum, task) => sum + task.speed);
    final finishedCount = tasks.where((task) => task.phase == HuyaDownloadPhase.done).length;
    final width = MediaQuery.sizeOf(context).width;
    // The facts column rides beside the queue where the rows keep their
    // reading after 340 pixels are taken from them; the queue speaks about
    // the row on stage.
    final withFacts = width >= LiveWindow.downloadWorkspace;
    final factsTask =
        shown.where((task) => task.videoId == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final queue = shown.isEmpty
        ? Expanded(
            child: Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.download),
                title: Text(tasks.isEmpty ? t.settings.downloadQueueEmpty : t.settings.downloadFilterEmpty),
                description: Text(tasks.isEmpty ? t.huya.downloadQueueEmptyDesc : t.settings.downloadFilterEmpty),
                actions: [
                  if (_statuses.isNotEmpty)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.filter, size: 14),
                      onPressed: () => setState(_statuses.clear),
                      child: Text(t.settings.downloadFilterReset),
                    ),
                ],
              ),
            ),
          )
        : Expanded(
            child: ListView(
              padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
              children: [
                DsListSection(
                  children: [
                    for (final task in shown)
                      DsPressable(
                        semanticLabel: task.title,
                        onPressed: () => setState(() => _factsId = task.videoId),
                        builder: (context, states, child) => child!,
                        child: huyaTaskCard(context, ref, task, missing: huyaFileMissing(task)),
                      ),
                  ],
                ),
              ],
            ),
          );
    return ColoredBox(
      color: colors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(_inset, DsSpace.s12, _inset, DsSpace.s8),
            child: DownloadQueueHeader(
              summary: [
                t.settings.downloadTaskCount(count: tasks.length, active: moving),
                if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                if (speed > 0) t.common.downloadSpeed(speed: '${formatDownloadBytes(speed)}/s'),
              ].join(' · '),
              searchHint: t.settings.downloadSearchPlaceholder,
              query: _query,
              onQuery: (value) => setState(() => _query = value),
              filterLabel: t.settings.downloadFilterLabel,
              filterActive: _statuses.isNotEmpty,
              onFilter: () => unawaited(_openFilter()),
              actions: [
                DownloadQueueAction(
                  label: t.settings.downloadManagerOpenFolder,
                  icon: DsIcons.folderOpen,
                  onPressed: () => unawaited(openDownloadedPath(context, directory)),
                ),
                if (finishedCount > 0)
                  DownloadQueueAction(
                    label: t.settings.downloadClearFinished,
                    icon: DsIcons.trash2,
                    destructive: true,
                    onPressed: () => unawaited(_clearFinished(tasks)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                queue,
                if (withFacts)
                  SizedBox(
                    width: LiveWindow.downloadDetails,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, DsSpace.s20, DsSpace.s24),
                      child: DownloadDetailsPane(
                        details: factsTask == null
                            ? null
                            : huyaDetailsOf(context, ref, factsTask, missing: huyaFileMissing(factsTask)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
