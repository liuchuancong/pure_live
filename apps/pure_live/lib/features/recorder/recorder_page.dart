// The named `_AddRoomForm` constructor cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_record_core/live_record_core.dart'
    show RecordStatus, RecordTarget, RecordTask, RoomState, statusIsBusy;
import 'package:live_sites/live_sites.dart' show LiveRoomProvider, LiveSite, LiveSiteManifest;
import 'package:open_file/open_file.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/features/recorder/recorder_engine.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';
import 'package:pure_live/features/recorder/recorder_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/feed_chip.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The recorder: the rooms being watched, each with its state chip and its
/// controls, over the output directory and segment settings.
///
/// The engine behind the list is `live_record_core`'s orchestrator — this
/// page only reads its ledger and asks it to watch, stop and finish; the
/// wiring to the site graph and the FFmpeg backend lives in
/// `recorder_engine.dart`.
///
/// The reference keeps a per-status tab per state; this build carries the
/// three answers a viewer acts on (all, in progress, finished) until the
/// list grows enough to need the finer cuts.
final class RecorderPage extends ConsumerStatefulWidget {
  /// The recorder page.
  const new({super.key});

  @override
  ConsumerState<RecorderPage> createState() => _RecorderPageState();
}

final class _RecorderPageState extends ConsumerState<RecorderPage> {
  List<RecordTask> _tasks = const <RecordTask>[];
  StreamSubscription<RecordTask>? _subscription;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bind());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// Binds the ledger's change stream once the runtime has finished its
  /// recovery sweep. A runtime that failed to open shows the provider's
  /// error state; there is nothing to bind.
  Future<void> _bind() async {
    final RecorderRuntime runtime;
    try {
      runtime = await ref.read(recorderRuntimeProvider.future);
    } on Object {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _tasks = runtime.tasks);
    unawaited(_subscription?.cancel());
    _subscription = runtime.onChanged.listen((_) {
      if (!mounted) {
        return;
      }
      // The orchestrator re-emits the same mutable instance; the identity of
      // the list is what the rebuild hangs on.
      setState(() => _tasks = runtime.tasks);
    });
  }

  Future<RecorderRuntime?> _runtime() async {
    try {
      return await ref.read(recorderRuntimeProvider.future);
    } on Object {
      return null;
    }
  }

  Future<void> _addRoom() async {
    final t = context.t;
    final sites = ref.read(sitesProvider).registry.all.where((site) => site.capability<LiveRoomProvider>() != null);
    if (sites.isEmpty) {
      PureToast.show(context, t.recorder.noSites, type: PureToastType.error);
      return;
    }
    final picked = await showPureDialog<(String, String)>(
      context: context,
      title: t.recorder.addRoom,
      child: Builder(
        builder: (dialogContext) => _AddRoomForm(
          sites: sites.toList(growable: false),
          onSubmit: (platformId, roomId) => Navigator.of(dialogContext).pop((platformId, roomId)),
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    final (platformId, roomId) = picked;
    final site = ref.read(sitesProvider).registry.getById(platformId);
    final rooms = site?.capability<LiveRoomProvider>();
    if (rooms == null) {
      PureToast.show(context, t.recorder.noSites, type: PureToastType.error);
      return;
    }

    // One room lookup before the task is created: the title and the anchor's
    // own name ride on the target, and the naming layer needs the anchor for
    // the session directory.
    final room = await rooms.getRoom(roomId).then((value) => value.fold((error) => null, (value) => value));
    final anchor = room?.anchor?.name.trim();
    final title = room?.content.title.trim();
    final target = RecordTarget(
      platform: platformId,
      roomId: roomId,
      anchorName: anchor == null || anchor.isEmpty ? roomId : anchor,
      roomTitle: title == null || title.isEmpty ? null : title,
    );

    final runtime = await _runtime();
    if (runtime == null || !mounted) {
      return;
    }
    try {
      await runtime.watch(target);
      if (mounted) {
        PureToast.show(context, t.recorder.watchStarted, type: PureToastType.success);
      }
    } on Object catch (error) {
      if (mounted) {
        PureToast.show(context, t.recorder.watchFailed(error: '$error'), type: PureToastType.error);
      }
    }
  }

  Future<void> _openOutputDirectory(String root) async {
    final t = context.t;
    try {
      final result = await OpenFile.open(root.isEmpty ? Directory.systemTemp.path : root);
      if (result.type != ResultType.done && mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final runtime = ref.watch(recorderRuntimeProvider);
    final preferences = ref.watch(recorderPreferencesProvider).value ?? RecorderPreferences();
    final root = ref.watch(recorderRootProvider).value ?? preferences.outputDirectory;

    // A rebuilt runtime (a moved output directory re-opens it) rebinds the
    // ledger stream this page reads.
    ref.listen(recorderRuntimeProvider, (previous, next) {
      if (next.hasValue && previous?.value != next.value) {
        unawaited(_bind());
      }
    });

    return MainPageFrame(
      inHome: true,
      title: t.recorder.title,
      actions: [
        PureIconButton(
          tooltip: t.recorder.addRoom,
          icon: Icons.add_circle_outline,
          onPressed: runtime.hasValue ? _addRoom : null,
        ),
        PureIconButton(
          tooltip: t.recorder.openFolder,
          icon: Icons.folder_open_outlined,
          onPressed: () => _openOutputDirectory(root),
        ),
        PureIconButton(
          tooltip: t.recorder.recordSettings,
          icon: Icons.tune_outlined,
          onPressed: () => unawaited(const RecordingSettingsRoute().push<void>(context)),
        ),
      ],
      body: runtime.when(
        loading: () => PureLoading(message: t.recorder.restoring),
        error: (error, _) => PureError(
          message: t.recorder.engineFailed(error: '$error'),
          onRetry: () => ref.invalidate(recorderRuntimeProvider),
          retryLabel: t.common.retry,
        ),
        data: (_) => LayoutBuilder(
          builder: (context, constraints) {
            // The reference's task grid: one column until the window fits a
            // second 400-wide card, up to four on an ultrawide.
            final width = constraints.maxWidth;
            final columns = width >= 840 ? (width / 400).floor().clamp(1, 4) : 1;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width > 1600 ? 1600.0 : width,
                height: constraints.maxHeight,
                child: _buildTasks(context, columns),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The reference's five buckets: all, capturing (active), waiting for a
  /// slot or the stream address (waiting), finished with a file (saved), and
  /// ended broken (failed).
  static bool _inBucket(RecordTask task, int bucket) => switch (bucket) {
    1 => switch (task.status) {
      RecordStatus.recording || RecordStatus.retrying || RecordStatus.merging => true,
      _ => false,
    },
    2 => switch (task.status) {
      RecordStatus.queued || RecordStatus.resolving => true,
      _ => false,
    },
    3 => switch (task.status) {
      RecordStatus.completed || RecordStatus.stopped => true,
      _ => false,
    },
    4 => switch (task.status) {
      RecordStatus.failed || RecordStatus.interrupted => true,
      _ => false,
    },
    _ => true,
  };

  /// The visible tasks after the status filter, before ordering.
  List<RecordTask> _filtered() => [
    for (final task in _tasks)
      if (_inBucket(task, _filter)) task,
  ];

  /// The filter bar: five equal chips, each with its count (the reference's
  /// _FilterBar).
  Widget _filterBar(BuildContext context) {
    final t = context.t;
    final labels = [
      t.recorder.filterAll,
      t.recorder.filterActive,
      t.recorder.filterWaiting,
      t.recorder.filterSaved,
      t.recorder.filterFailed,
    ];
    final counts = [for (var bucket = 0; bucket < 5; bucket++) _tasks.where((task) => _inBucket(task, bucket)).length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var bucket = 0; bucket < 5; bucket++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FeedChip(
                  label: '${labels[bucket]} ${counts[bucket]}',
                  selected: _filter == bucket,
                  onTap: () => setState(() => _filter = bucket),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The task list: filter bar over the task cards in [columns] columns —
  /// the reference's _TaskGrid (one column on a phone, up to four when the
  /// window is wide). The directory and segment settings live on the
  /// recording settings page, reached from the bar.
  Widget _buildTasks(BuildContext context, int columns) {
    final t = context.t;
    final tasks = _ordered(_filtered());
    return ListView(
      padding: MainLayout.bodyPadding(context, top: 12, bottom: 32),
      children: [
        _filterBar(context),
        const PureDivider(),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: PureEmpty(
              title: t.recorder.emptyTitle,
              message: t.recorder.emptySubtitle,
              icon: Icons.video_collection_outlined,
              action: PureButton(label: t.recorder.addRoom, icon: Icons.add, onPressed: _addRoom),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final task in tasks)
                    SizedBox(
                      width: itemWidth,
                      child: RecorderTaskCard(
                        key: ValueKey(task.taskId),
                        task: task,
                        onStop: () => _stop(task),
                        onFinish: () => _finish(task),
                        onRestart: () => _restart(task),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// Busy tasks first, then the newest.
  List<RecordTask> _ordered(List<RecordTask> tasks) {
    int rank(RecordTask task) => statusIsBusy(task.status) ? 0 : 1;
    return [...tasks]..sort((left, right) {
      final byRank = rank(left).compareTo(rank(right));
      if (byRank != 0) {
        return byRank;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
  }

  Future<void> _stop(RecordTask task) async {
    final runtime = await _runtime();
    await runtime?.stopWatching(task.taskId);
  }

  Future<void> _finish(RecordTask task) async {
    final t = context.t;
    final runtime = await _runtime();
    final joined = await runtime?.finishNow(task.taskId) ?? false;
    if (!joined && mounted) {
      PureToast.show(context, t.recorder.nothingToJoin);
    }
  }

  Future<void> _restart(RecordTask task) async {
    final runtime = await _runtime();
    await runtime?.watch(task.target);
  }
}

/// One watched room: state chip, identity, the recording's running totals,
/// and the controls its state allows.
final class RecorderTaskCard extends StatelessWidget {
  /// A task card.
  const new({required this.task, required this.onStop, required this.onFinish, required this.onRestart, super.key});

  /// The task as the ledger holds it.
  final RecordTask task;

  /// Stops watching; what was captured is finished first.
  final VoidCallback onStop;

  /// Joins the finished attempts now, without waiting for the room.
  final VoidCallback onFinish;

  /// Watches the room again (a failed, stopped or completed task).
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final busy = statusIsBusy(task.status);
    final output = task.publishedFile ?? task.mergedFile;

    return PureCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _StatusChip(status: task.status),
              const Spacer(),
              Text(
                task.target.platform.toUpperCase(),
                style: theme.text.caption.copyWith(
                  color: theme.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.target.roomTitle?.isNotEmpty == true ? task.target.roomTitle! : task.target.anchorName,
            style: theme.text.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _identityLine(t),
            style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatChip(icon: Icons.timer_outlined, label: _formatDuration(task.recordedFor)),
              _StatChip(icon: Icons.storage_outlined, label: _formatBytes(task.bytesWritten)),
              _StatChip(
                icon: Icons.video_library_outlined,
                label: t.recorder.segmentsValue(count: task.segments),
              ),
            ],
          ),
          if (task.failureReason case final failure? when failure.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 15, color: theme.colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    failure,
                    style: theme.text.caption.copyWith(color: theme.colors.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (output case final file?) ...[
            const SizedBox(height: 10),
            PureBox(
              style: (state) => Style(
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                background: switch (state) {
                  InteractionState.pressed => theme.colors.fillTertiary,
                  InteractionState.hovered => theme.colors.fillQuaternary,
                  _ => null,
                },
              ),
              onTap: () => unawaited(_openFile(file, context)),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline, size: 16, color: theme.colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      file,
                      style: theme.text.caption.copyWith(color: theme.colors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (busy)
                PureButton(
                  label: t.recorder.actionStop,
                  variant: ButtonVariant.danger,
                  size: ControlSize.sm,
                  onPressed: onStop,
                ),
              if (!busy && task.pendingAttempts.isNotEmpty)
                PureButton(label: t.recorder.actionFinishNow, size: ControlSize.sm, onPressed: onFinish),
              if (!busy && !task.hasOutstandingWork)
                PureButton(
                  label: task.status == RecordStatus.failed ? t.common.retry : t.recorder.actionRestart,
                  variant: ButtonVariant.secondary,
                  size: ControlSize.sm,
                  onPressed: onRestart,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _identityLine(Translations t) {
    final room = switch (task.roomState) {
      RoomState.waiting => t.recorder.roomWaiting,
      RoomState.live => t.recorder.roomLive,
      RoomState.ended => t.recorder.roomEnded,
      RoomState.stalled => t.recorder.roomStalled,
      RoomState.unavailable => t.recorder.roomUnavailable,
      RoomState.unknown => t.recorder.roomUnknown,
    };
    return '${task.target.anchorName} · ${task.target.roomId} · $room';
  }

  static Future<void> _openFile(String path, BuildContext context) async {
    final t = context.t;
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done && context.mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (context.mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    }
  }

  static String _formatDuration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes % 60)}:${two(duration.inSeconds % 60)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

/// The state chip: the task's queue status in the colour it answers with.
final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RecordStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final (label, color) = switch (status) {
      RecordStatus.queued => (t.recorder.statusQueued, const Color(0xFF7E57C2)),
      RecordStatus.resolving => (t.recorder.statusResolving, const Color(0xFFFFB300)),
      RecordStatus.recording => (t.recorder.statusRecording, const Color(0xFF43A047)),
      RecordStatus.retrying => (t.recorder.statusRetrying, const Color(0xFFFB8C00)),
      RecordStatus.merging => (t.recorder.statusMerging, const Color(0xFF00ACC1)),
      RecordStatus.completed => (t.recorder.statusCompleted, const Color(0xFF1E88E5)),
      RecordStatus.failed => (t.recorder.statusFailed, theme.colors.error),
      RecordStatus.stopped => (t.recorder.statusStopped, theme.colors.textSecondary),
      RecordStatus.interrupted => (t.recorder.statusInterrupted, theme.colors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: theme.text.caption.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One running total, tinted.
final class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: theme.text.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// The add-room form: the platform picked from the sites that can look rooms
/// up, and the room id typed in.
final class _AddRoomForm extends ConsumerStatefulWidget {
  const _AddRoomForm({required this.sites, required this.onSubmit});

  final List<LiveSite> sites;
  final void Function(String platformId, String roomId) onSubmit;

  @override
  ConsumerState<_AddRoomForm> createState() => _AddRoomFormState();
}

final class _AddRoomFormState extends ConsumerState<_AddRoomForm> {
  late String _platformId = widget.sites.first.manifest.id;
  final TextEditingController _roomId = TextEditingController();

  @override
  void dispose() {
    _roomId.dispose();
    super.dispose();
  }

  LiveSite get _site =>
      widget.sites.firstWhere((site) => site.manifest.id == _platformId, orElse: () => widget.sites.first);

  Future<void> _choosePlatform() async {
    final t = context.t;
    final picked = await showSettingsChooser<String>(
      context,
      ref,
      title: t.recorder.platform,
      current: _platformId,
      options: [for (final site in widget.sites) (site.manifest.id, _siteName(site.manifest))],
    );
    if (picked != null) {
      setState(() => _platformId = picked);
    }
  }

  void _submit() {
    final roomId = _roomId.text.trim();
    if (roomId.isEmpty) {
      return;
    }
    widget.onSubmit(_platformId, roomId);
  }

  /// The site's display name in the viewer's locale, falling back the way the
  /// manifest's own map asks to be read.
  String _siteName(LiveSiteManifest manifest) {
    final locale = Localizations.localeOf(context);
    final names = manifest.name;
    final tag = locale.toLanguageTag();
    return names[tag] ??
        names[locale.languageCode] ??
        names['zh'] ??
        names['en'] ??
        (names.values.isEmpty ? manifest.id : names.values.first);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PureListRow(
          title: t.recorder.platform,
          subtitle: _siteName(_site.manifest),
          leading: const Icon(Icons.public, size: 20),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _choosePlatform,
        ),
        const SizedBox(height: 10),
        PureTextField(
          controller: _roomId,
          placeholder: t.recorder.roomId,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 4),
        PureButton(label: t.recorder.startWatching, onPressed: _submit),
      ],
    );
  }
}
