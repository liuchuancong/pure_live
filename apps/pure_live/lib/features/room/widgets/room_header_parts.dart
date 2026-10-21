import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowRepository;
import 'package:live_record_core/live_record_core.dart' show RecordTarget, RecordTask, statusIsBusy;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/recorder/recorder_engine.dart' show RecorderRuntime;
import 'package:pure_live/features/recorder/recorder_providers.dart' show recorderRuntimeProvider;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/features/room/room_dialogs.dart';
import 'package:pure_live/features/room/room_playlist.dart';
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity, danmakuSessionProvider;
import 'package:pure_live/features/room/room_share_code.dart' show OwnClipboardTexts, encodeRoomShareCode;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The pieces the room header is built from. The layouts arrange them their
/// own way — a phone spends its width on the stream, a desktop can afford the
/// name and the actions on one line — so these carry content, not a bar.

/// The anchor and the room line under it, the reference's header title, plus
/// the previous/next switch when the room was opened from a list.
final class RoomIdentityBadge extends ConsumerWidget {
  /// A badge for [room] on a site shown as [siteName].
  const new({required this.room, required this.siteName, this.size = 40, this.titleStyle, super.key});

  /// The room detail as known right now (may be the route's stub).
  final LiveRoom room;

  /// The platform's display name, already localized.
  final String siteName;

  /// The avatar edge.
  final double size;

  /// The name's style; a TV raises it.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final anchor = room.anchor;
    final area = room.area?.areaName;
    final style = titleStyle ?? theme.text.subtitle;
    // The list the room was entered from; a deep link or a clipboard paste
    // leaves nothing to step through.
    final playlist = ref.watch(roomPlaylistProvider);
    final linked = playlist != null && RoomPlaylist.sameRoom(playlist.currentRoom, room);
    return Row(
      children: [
        PureAvatar(name: anchor?.name, src: _imageOf(anchor?.avatarUrl), size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                anchor == null || anchor.name.isEmpty ? room.ref.roomId : anchor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              Text(
                area == null || area.isEmpty ? siteName : '$siteName · $area',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
            ],
          ),
        ),
        if (linked && playlist.switchable)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${playlist.index + 1}/${playlist.rooms.length}',
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
              PureIconButton(
                key: const ValueKey('room-previous'),
                icon: Icons.skip_previous,
                tooltip: context.t.room.previousRoom,
                size: ControlSize.sm,
                onPressed: () => switchRoom(context, ref, -1),
              ),
              PureIconButton(
                key: const ValueKey('room-next'),
                icon: Icons.skip_next,
                tooltip: context.t.room.nextRoom,
                size: ControlSize.sm,
                onPressed: () => switchRoom(context, ref, 1),
              ),
            ],
          ),
      ],
    );
  }

  static ImageProvider? _imageOf(String? url) {
    final value = url?.trim() ?? '';
    return value.isEmpty ? null : CachedNetworkImageProvider(value);
  }
}

/// Follows and un-follows the room, inert until the canonical detail arrived —
/// following a stub would store a title-less record.
final class RoomFollowButton extends ConsumerStatefulWidget {
  /// A follow toggle for [room]; [compact] draws the icon-only form a narrow
  /// bar spends on it.
  const new({required this.room, this.compact = false, super.key});

  /// The room as known right now.
  final LiveRoom room;

  /// Whether to drop the label and keep the glyph.
  final bool compact;

  @override
  ConsumerState<RoomFollowButton> createState() => _RoomFollowButtonState();
}

final class _RoomFollowButtonState extends ConsumerState<RoomFollowButton> {
  StreamSubscription<void>? _changes;
  bool _followed = false;

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _changes = _repository.changes.listen((_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    await _repository.load();
    if (mounted) {
      setState(() => _followed = _repository.isFollowed(widget.room));
    }
  }

  Future<void> _toggle() async {
    if (_followed) {
      await _repository.unfollow(widget.room);
    } else {
      await _repository.follow(widget.room);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.room.anchor != null || widget.room.content.title.isNotEmpty;
    if (widget.compact) {
      return PureIconButton(
        icon: _followed ? Icons.favorite : Icons.favorite_border,
        tooltip: _followed ? context.t.room.followed : context.t.room.follow,
        selected: _followed,
        enabled: enabled,
        onPressed: enabled ? () => unawaited(_toggle()) : null,
      );
    }
    return PureButton(
      label: _followed ? context.t.room.followed : context.t.room.follow,
      icon: _followed ? Icons.favorite : Icons.favorite_border,
      variant: _followed ? ButtonVariant.secondary : ButtonVariant.primary,
      size: ControlSize.sm,
      onPressed: enabled ? () => unawaited(_toggle()) : null,
    );
  }
}

/// Starts and stops a recording of this room through the recorder runtime, the
/// reference's `RecordActionButton`.
///
/// The task is the source of truth: the button reads the runtime's own list
/// rather than a local flag, so a task started from the recorder page shows up
/// here as already running.
final class RoomRecordButton extends ConsumerStatefulWidget {
  /// A record toggle for [identity], named by [room].
  const new({required this.identity, required this.room, super.key});

  /// The room to record.
  final RoomIdentity identity;

  /// The detail as known right now, for the task's display name.
  final LiveRoom room;

  @override
  ConsumerState<RoomRecordButton> createState() => _RoomRecordButtonState();
}

final class _RoomRecordButtonState extends ConsumerState<RoomRecordButton> {
  StreamSubscription<RecordTask>? _changes;
  List<RecordTask> _tasks = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    final runtime = await _runtime();
    if (!mounted || runtime == null) {
      return;
    }
    setState(() => _tasks = runtime.tasks);
    unawaited(_changes?.cancel());
    _changes = runtime.onChanged.listen((_) => unawaited(_reload()));
  }

  Future<RecorderRuntime?> _runtime() async {
    try {
      return await ref.read(recorderRuntimeProvider.future);
    } on Object {
      // A recorder that cannot open (no writable root, a dead backend) leaves
      // the button inert rather than failing the room.
      return null;
    }
  }

  RecordTask? get _task {
    for (final task in _tasks) {
      if (task.target.platform == widget.identity.siteId && task.target.roomId == widget.identity.roomId) {
        return task;
      }
    }
    return null;
  }

  Future<void> _toggle() async {
    final runtime = await _runtime();
    if (runtime == null) {
      return;
    }
    final task = _task;
    if (task != null && statusIsBusy(task.status)) {
      await runtime.stopWatching(task.taskId);
    } else {
      final anchor = widget.room.anchor?.name.trim();
      final title = widget.room.content.title.trim();
      await runtime.watch(
        RecordTarget(
          platform: widget.identity.siteId,
          roomId: widget.identity.roomId,
          anchorName: anchor == null || anchor.isEmpty ? widget.identity.roomId : anchor,
          roomTitle: title.isEmpty ? null : title,
        ),
      );
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final status = _task?.status;
    final busy = status != null && statusIsBusy(status);
    return PureIconButton(
      icon: busy ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
      tooltip: busy ? context.t.room.stopRecording : context.t.room.record,
      selected: busy,
      enabled: widget.room.anchor != null || widget.room.content.title.isNotEmpty,
      onPressed: () => unawaited(_toggle()),
    );
  }
}

/// The header's overflow: what has no button of its own but belongs in the
/// room, the reference's `LivePlayMenuButton`.
final class RoomOverflowMenu extends ConsumerWidget {
  /// The menu for [identity] driven by [controller] and read from [state].
  const new({required this.identity, required this.controller, required this.state, super.key});

  /// The room the menu acts on.
  final RoomIdentity identity;

  /// The page logic the items call.
  final RoomController controller;

  /// The snapshot the items read.
  final RoomState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immersive = state.presentation != RoomPresentation.normal;
    return PureMenu(
      items: [
        PureMenuItem(
          id: 'barrage',
          label: state.barrageOn ? context.t.room.barrageOff : context.t.room.barrageOn,
          icon: Icons.comment_outlined,
          onTap: () => controller.setBarrage(on: !state.barrageOn),
        ),
        // The reference's menu carries the sleep timer and the volume dialog as
        // first-class items; both live in the room, not in settings.
        PureMenuItem(
          id: 'timer',
          label: state.sleepTimerActive ? context.t.room.sleepTimerOn : context.t.room.sleepTimer,
          icon: Icons.bedtime_outlined,
          onTap: () => unawaited(showRoomTimerDialog(context, identity)),
        ),
        PureMenuItem(
          id: 'volume',
          label: context.t.room.roomVolume,
          icon: Icons.volume_up_outlined,
          onTap: () => unawaited(showRoomVolumeDialog(context, identity)),
        ),
        PureMenuItem(
          id: 'shield',
          label: context.t.room.shield,
          icon: Icons.block_outlined,
          onTap: () => unawaited(_openShield(context, ref)),
        ),
        PureMenuItem(
          id: 'toolbox',
          label: context.t.room.toolbox,
          icon: Icons.build_outlined,
          onTap: () => unawaited(const ToolboxRoute().push<void>(context)),
        ),
        PureMenuItem(
          id: 'copy',
          label: context.t.room.copyLink,
          icon: Icons.link,
          onTap: () => unawaited(_copyLink(context)),
        ),
        // The 口令 is the other half of the same action: a code the app can
        // read back out of a chat message or a note, where a bare URL needs a
        // browser.
        PureMenuItem(
          id: 'share-code',
          label: context.t.room.shareCode,
          icon: Icons.emoji_emotions_outlined,
          onTap: () => unawaited(_copyShareCode(context)),
        ),
        PureMenuItem(
          id: 'fullscreen',
          label: immersive ? context.t.room.exitFullscreen : context.t.room.fullscreen,
          icon: immersive ? Icons.fullscreen_exit : Icons.fullscreen,
          onTap: () => controller.setPresentation(immersive ? RoomPresentation.normal : RoomPresentation.fullscreen),
        ),
      ],
      child: const PureIconButton(icon: Icons.apps, tooltip: ''),
    );
  }

  Future<void> _openShield(BuildContext context, WidgetRef ref) async {
    await const ShieldRoute().push<void>(context);
    ref.invalidate(danmakuSessionProvider(identity));
  }

  /// Copies the room's own address: the platform's web page, falling back to
  /// the identity pair the toolbox also accepts.
  Future<void> _copyLink(BuildContext context) async {
    final links = state.room?.links;
    final url = links?.webUrl ?? links?.shareUrl ?? '${identity.siteId}/${identity.roomId}';
    // Remembered so the clipboard check does not offer the app its own find.
    OwnClipboardTexts.remember(url);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      PureToast.show(context, context.t.room.linkCopied);
    }
  }

  /// Copies the room's share code, or says so when the room is not named well
  /// enough to point at (the reference's `share_failed`).
  Future<void> _copyShareCode(BuildContext context) async {
    final t = context.t;
    final room = state.room;
    final code = room == null ? '' : encodeRoomShareCode(room);
    if (code.isEmpty) {
      if (context.mounted) {
        PureToast.show(context, t.room.shareCodeFailed, type: PureToastType.warning);
      }
      return;
    }
    OwnClipboardTexts.remember(code);
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      PureToast.show(context, t.room.shareCodeCopied);
    }
  }
}
