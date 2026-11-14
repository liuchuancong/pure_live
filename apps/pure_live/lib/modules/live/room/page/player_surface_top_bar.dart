part of 'player_surface.dart';

/// The stream's own catalogues: quality and line.
///
/// They live in the bottom bar, beside the transport, because they change what
/// is playing rather than who is playing: the strip above the picture names the
/// room and carries its state, and a viewer looking for "why is this blurry"
/// reaches for the bar they just used to unmute it. The picture's fit sits
/// beside them on the wide bar, its catalogue the same card the
/// quality and the line drop — one popup language for the bar.
/// The picture's fit on the wide bar: the current fit's words and the chevron
/// that points the way its list opens — up, over the bar — drawn like the
/// stream's own pickers beside it, wired to the surface's picker machinery
/// rather than a menu of its own.
/// The inline room's caption, the picture's top-left: the room's title over
/// its figures (viewers, watched). The identity lives in the page's own bar —
/// this strip is the content's, so a folded chat column still leaves the
/// room nameable. It follows the bars' auto-hide: mouse away, it goes with
/// them; a tap opens the room's details.
final class _RoomTitleCaption extends ConsumerWidget {
  const _RoomTitleCaption();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final t = context.t;
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      child: PlayerGlassPill(
        child: DsPressable(
          semanticLabel: t.room.detailsHint,
          onPressed: () => unawaited(showRoomDetails(context)),
          builder: (context, states, _) => Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  detail.content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: OnVideoColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip over the picture: the way out in a glass pill, the room's name
/// in the viewer's own type, the live state and the audience beside it, and —
/// the reference's own arrangement — the stream's choices on the far end: the
/// flying danmaku's switch, the quality, the line and the picture's shape.
///
/// A picker drops its catalogue *under* the strip as a panel: resting the
/// pointer on a picker opens it, a press toggles it, a choice closes it. That
/// keeps one overlay over the picture instead of a menu per control, and lets
/// the button read "线路 2" while the panel says what that line is.
final class _PlayerTopBar extends ConsumerStatefulWidget {
  const _PlayerTopBar({
    required this.room,
    required this.onLeave,
    required this.onWake,
    this.onMore,
    this.endInset = DsSpace.s12,
  });

  final RoomState room;
  final VoidCallback onLeave;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// Opens the room's more container (the page-level panel/sheet).
  final VoidCallback? onMore;

  /// The room left where the strip's trailing verbs end: the floating chat
  /// drawer (方案B) reserves the picture's end edge, and the strip keeps out
  /// from under it.
  final double endInset;

  @override
  ConsumerState<_PlayerTopBar> createState() => _PlayerTopBarState();
}

/// The strip above the picture in the TV room: who is streaming and whether
/// it is live, plus the verbs that follow the picture there. Nothing here
/// changes what is playing — the transport, the stream's quality and the
/// picture's fit all live on the bar below, where a viewer reaching for "it
/// looks wrong" already is. The right half is the cluster of *how the picture
/// is being shown*: recording, the small window and the cast target all move
/// or copy the stream rather than choosing it, and each has a state worth
/// seeing at a glance — so a running capture breathes up here beside them.
/// The far end carries the room's own menu, so the actions the page header
/// offers do not vanish; under the narrow tier a running take's duration moves
/// under that menu, which keeps the title readable. The other immersive shapes
/// draw the floating capsule and the tool cluster instead of this strip (the
/// redesign's gcap/tcluster), and the inline room uses the cluster alone.
final class _PlayerTopBarState extends ConsumerState<_PlayerTopBar> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = widget.room.room;
    final audience = detail?.audience.onlineViewers ?? detail?.audience.popularity ?? detail?.audience.totalViewers;
    final replay = detail?.broadcast.isRecord ?? false;
    final tv = PlayerBarTier.tvOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same floor the control bar uses for its medium tier: below it a
        // strip has room for status, not for three more verbs.
        final narrow = constraints.maxWidth < 460;
        final cluster = _PresentationCluster(room: widget.room, onWake: widget.onWake, narrow: narrow);
        final onMore = widget.onMore;
        final menuPill = onMore == null
            ? const SizedBox.shrink()
            : PlayerGlassPill(
                child: PlayerBarButton(
                  icon: DsIcons.ellipsis,
                  label: t.common.more,
                  onPressed: () {
                    widget.onWake();
                    onMore();
                  },
                ),
              );
        // A narrow strip keeps only PiP; a running take moves under the
        // More pill, where its duration does not crowd the picture verbs.
        final menuColumn = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: DsSpace.s4,
                children: [
                  menuPill,
                  _NarrowRecordingUnderMenu(room: widget.room),
                ],
              )
            : menuPill;
        final capture = widget.room.handle;
        final audioPill = PlayerGlassPill(
          child: PlayerBarButton(
            icon: widget.room.audioOnly ? DsIcons.video : DsIcons.headphones,
            label: widget.room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
            selected: widget.room.audioOnly,
            onPressed: () {
              widget.onWake();
              unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !widget.room.audioOnly));
            },
          ),
        );
        final screenshotPill = capture != null && capture.canCaptureScreenshot
            ? PlayerGlassPill(
                child: PlayerBarButton(
                  icon: DsIcons.camera,
                  label: t.room.screenshot,
                  onPressed: () {
                    widget.onWake();
                    unawaited(takeRoomScreenshot(context, ref, capture));
                  },
                ),
              )
            : null;
        return Container(
          padding: EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, widget.endInset, DsSpace.s12),
          decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
          child: Row(
            spacing: tv ? DsSpace.s12 : DsSpace.s8,
            children: [
              // The TV room's way back: the page's own app bar is gone in the
              // room's full-bleed layout, so the strip carries the arrow.
              PlayerGlassPill(
                child: PlayerBarButton(icon: DsIcons.chevronLeft, label: t.common.close, onPressed: widget.onLeave),
              ),
              // The strip's left is the anchor's identity and the follow verb —
              // a fullscreen room's only follow surface, its column folded away.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _AnchorFollowChip(room: widget.room, onWake: widget.onWake),
                ),
              ),
              if (replay)
                PlayerGlassPill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                    child: Text(
                      t.favorites.statusReplay,
                      style: theme.typography.caption.copyWith(color: _onVideo, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              // The audience pill is a broadcast's number: a replay names
              // itself instead, and its figures stay in the room card and
              // the details panel.
              if (audience != null && !replay && constraints.maxWidth >= 480)
                PlayerGlassPill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s3,
                      children: [
                        DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: _onVideoSubtle),
                        Text(
                          AudienceFormat.format(audience),
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: _onVideo)),
                        ),
                      ],
                    ),
                  ),
                ),
              // The room switcher sits with the picture verbs on a wide strip;
              // a narrow one keeps the menu and PiP only.
              if (!narrow && widget.room.room != null)
                PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.arrowLeftRight,
                    label: t.room.switchRoom,
                    onPressed: () {
                      widget.onWake();
                      unawaited(showRoomSwitcher(context, current: widget.room.room!));
                    },
                  ),
                ),
              // The sound mode and a frame copy keep their own controls; the
              // strip stays one control per function.
              ?screenshotPill,
              audioPill,
              cluster,
              menuColumn,
            ],
          ),
        );
      },
    );
  }
}

/// The anchor's identity and the follow verb over the picture's top-left: a
/// glass pill the control bar's own show/hide carries, so a room whose column
/// is folded away — fullscreen above all — still offers follow and unfollow.
/// The name opens the details where the strip stands in for the room card.
final class _AnchorFollowChip extends ConsumerWidget {
  const _AnchorFollowChip({required this.room, required this.onWake});

  final RoomState room;

  /// Resets the bar's auto-hide timer after a press.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = room.room;
    if (detail == null) return const SizedBox.shrink();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final key = detail.ref.identityKey;
    final followed = ref.watch(
      followsProvider.select((follows) => follows.rooms.any((room) => room.ref.identityKey == key)),
    );
    final tv = PlayerBarTier.tvOf(context);
    return PlayerGlassPill(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s3, DsSpace.s4, DsSpace.s3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s6,
          children: [
            DsPressable(
              semanticLabel: t.room.detailsHint,
              onPressed: () {
                onWake();
                unawaited(showRoomDetails(context));
              },
              builder: (context, states, _) {
                final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: DsSpace.s3),
                  decoration: DsBoxDecoration(
                    color: lit ? _onVideoHover : null,
                    borderRadius: BorderRadius.circular(DsRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s6,
                    children: [
                      DsAvatar(
                        initials: avatarInitials(name),
                        image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                        size: tv ? DsSize.md : DsSize.sm,
                        semanticLabel: name,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tv ? 220 : 140),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (tv ? theme.typography.title : theme.typography.bodyStrong).copyWith(color: _onVideo),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            DsPressable(
              semanticLabel: followed ? t.room.unfollow : t.room.follow,
              onPressed: () {
                onWake();
                unawaited(toggleRoomFollow(context, ref));
              },
              builder: (context, states, _) {
                final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                final ink = followed ? _onVideo : OnVideoColors.foreground;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
                  decoration: BoxDecoration(
                    color: followed ? _onVideoHover : colors.accent,
                    borderRadius: BorderRadius.circular(DsRadii.pill),
                    border: Border.all(
                      color: lit ? OnVideoColors.foreground.withValues(alpha: 0.6) : OnVideoColors.clear,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconXs, color: ink),
                      Text(
                        followed ? t.room.unfollow : t.room.follow,
                        style: theme.typography.caption.copyWith(color: ink, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture's own tool cluster, floating at its top-right corner: the
/// session verbs — a frame copy, the capture, the small window and the room's
/// more container — in one glass pill (the redesign's tcluster). A wide
/// picture draws icons; a narrow one (under 460 px, the strip's own narrow
/// measure) switches to text chips and drops the small window, which has no
/// room for a fourth word. The verbs ride the bars' auto-hide with everything
/// else, and a running capture turns its chip the recorder's red.
final class _TopToolCluster extends ConsumerWidget {
  const _TopToolCluster({
    required this.room,
    required this.onWake,
    this.onMore,
    this.audioMode = false,
    this.pipChip = true,
  });

  final RoomState room;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// Opens the room's more container (the page-level panel/sheet); null
  /// leaves the more chip off — the compact window's cluster carries none.
  final VoidCallback? onMore;

  /// Whether the audio mode chip rides the cluster: the compact window's
  /// only audio verb, the page's bars being out of reach there.
  final bool audioMode;

  /// Whether the small window's verb rides the cluster; the compact window
  /// itself keeps its way out at the bottom-right corner instead.
  final bool pipChip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tv = PlayerBarTier.tvOf(context);
    final capture = room.handle;
    final canShot = capture != null && capture.canCaptureScreenshot;
    final task = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, room.room);
    final recording = task?.state == RecordingTaskState.recording;
    final pipAvailable = room.handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    final presentation = ref.watch(roomPresentationProvider);
    final audioOnly = room.audioOnly;
    final danger = colors.danger.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 460;
        final side = tv ? theme.sizes.lg : theme.sizes.sm;

        Widget chip({
          required String label,
          required VoidCallback? onPressed,
          DsIconData? icon,
          String? iconAsset,
          bool alert = false,
        }) {
          final corners = theme.radii.controlCorners(null, side);
          final ink = alert ? danger : _onVideo;
          final Widget child;
          if (small) {
            child = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: ink, fontWeight: FontWeight.w600),
            );
          } else if (iconAsset != null) {
            child = SvgPicture.asset(
              iconAsset,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
            );
          } else {
            child = DsIcon(
              icon!,
              size: tv ? theme.sizes.iconLg : theme.sizes.iconSm,
              color: alert ? danger : _onVideoMuted,
            );
          }
          final pressable = DsPressable(
            semanticLabel: label,
            onPressed: onPressed == null
                ? null
                : () {
                    onWake();
                    onPressed();
                  },
            builder: (context, states, _) {
              final focused = states.contains(WidgetState.focused);
              final hot = states.contains(WidgetState.hovered) || focused;
              return Container(
                height: side,
                padding: EdgeInsets.symmetric(horizontal: small ? DsSpace.s8 : DsSpace.s6),
                alignment: Alignment.center,
                decoration: DsBoxDecoration(color: hot ? _onVideoHover : null, borderRadius: corners),
                foregroundDecoration: tv && focused
                    ? BoxDecoration(
                        border: Border.all(color: OnVideoColors.foreground, width: 2),
                        borderRadius: corners,
                      )
                    : null,
                child: child,
              );
            },
          );
          return small ? pressable : DsTooltip(message: label, child: pressable);
        }

        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PlayerGlassPill(
            // The session verbs' glass rounds like the chips it holds, not
            // the capsule: a slight corner on the cluster's own tier.
            radius: theme.radii.control(side),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                if (canShot)
                  chip(
                    icon: DsIcons.camera,
                    label: context.t.room.screenshot,
                    onPressed: () {
                      final handle = room.handle;
                      if (handle == null || !handle.canCaptureScreenshot) return;
                      unawaited(takeRoomScreenshot(context, ref, handle));
                    },
                  ),
                if (recording)
                  RecordingIndicator(
                    startedAt: task?.startedAt,
                    label: context.t.room.stopRecording,
                    onStop: () => unawaited(toggleRoomRecording(context, ref)),
                  )
                else
                  chip(
                    icon: DsIcons.disc,
                    label: context.t.room.record,
                    onPressed: () => unawaited(toggleRoomRecording(context, ref)),
                  ),
                if (audioMode)
                  chip(
                    icon: audioOnly ? DsIcons.video : DsIcons.headphones,
                    label: audioOnly ? context.t.room.restoreVideo : context.t.room.audioOnlyMode,
                    onPressed: () => unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !audioOnly)),
                  ),
                // The way into or out of the small window; on a narrow cluster
                // it stays — leaving the window is the one verb the window
                // cannot lose.
                if (pipChip && pipAvailable && (!small || presentation == PresentationMode.pip))
                  chip(
                    icon: DsIcons.pictureInPicture2,
                    label: presentation == PresentationMode.pip ? context.t.room.pipOff : context.t.room.pipOn,
                    onPressed: () => unawaited(toggleRoomPip(context, ref)),
                  ),
                if (onMore != null) chip(icon: DsIcons.ellipsis, label: context.t.common.more, onPressed: onMore),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The duration of a narrow strip's running take, under its More pill.
///
/// The take no longer says its byte count on the picture; the time is enough
/// to know it is still moving, and a press still stops it.
final class _NarrowRecordingUnderMenu extends ConsumerWidget {
  const _NarrowRecordingUnderMenu({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, room.room);
    if (task?.state != RecordingTaskState.recording) return const SizedBox.shrink();
    return PlayerGlassPill(
      child: RecordingIndicator(
        startedAt: task!.startedAt,
        label: context.t.room.stopRecording,
        onStop: () => unawaited(toggleRoomRecording(context, ref)),
      ),
    );
  }
}

/// The immersive shapes' identity capsule (the redesign's gcap): the avatar
/// and the name over the platform and area in one glass pill, the follow verb
/// beside them, and a chevron that unfolds the room's own facts — the title,
/// the viewers, the watched time, and the share and details doors. It rides
/// the bars' auto-hide group with the rest of the chrome, and a press on the
/// identity half opens the details where the shape folds the room card into
/// the picture (a phone held sideways).
final class _ImmersiveCapsule extends ConsumerStatefulWidget {
  const _ImmersiveCapsule({required this.room, required this.onWake, required this.onBack});

  final RoomState room;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// The capsule's back arrow: the way out of the shape it rides (the page's
  /// own leave — the portrait full screen unwinds first, then the room).
  final VoidCallback onBack;

  @override
  ConsumerState<_ImmersiveCapsule> createState() => _ImmersiveCapsuleState();
}

final class _ImmersiveCapsuleState extends ConsumerState<_ImmersiveCapsule> {
  /// Whether the facts row is unfolded (the reference's `capExp`).
  bool _expanded = false;

  /// The identity half: the avatar over the name and the platform · area —
  /// the label the shapes share, pressable or inert by the caller's shape.
  Widget _capsuleIdentity({required String name, required String avatar, required String where}) {
    final theme = DsTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s6,
      children: [
        DsAvatar(
          initials: avatarInitials(name),
          image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
          size: DsSize.sm,
          semanticLabel: name,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.bodyStrong.copyWith(color: _onVideo),
            ),
            if (where.isNotEmpty)
              Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: OnVideoColors.inkSubtle),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = widget.room.room;
    if (detail == null) return const SizedBox.shrink();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final area = (detail.area?.areaName ?? '').trim();
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final where = [platform, if (area.isNotEmpty) area].join(' · ');
    final key = detail.ref.identityKey;
    final followed = ref.watch(
      followsProvider.select((follows) => follows.rooms.any((room) => room.ref.identityKey == key)),
    );
    // The reference caps the capsule at the picture's 60% width; a fixed
    // ceiling keeps a long title from stretching the pill across the screen.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: PlayerGlassPill(
        // A moderate corner, not the capsule: the unfolded facts row runs
        // wide under it, and the pill's own arc used to cut its first and
        // last words.
        radius: 10,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s3, DsSpace.s4, DsSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s6,
                children: [
                  // The back arrow leads the capsule (the reference's own):
                  // the immersive shapes and the portrait full screen have no
                  // other way back — the exit chip is gone, the strip is gone.
                  DsPressable(
                    semanticLabel: t.common.back,
                    onPressed: () {
                      widget.onWake();
                      widget.onBack();
                    },
                    builder: (context, states, _) {
                      final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                      return Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: DsBoxDecoration(
                          color: lit ? _onVideoHover : null,
                          borderRadius: BorderRadius.circular(DsRadii.pill),
                        ),
                        child: const DsIcon(DsIcons.arrowLeft, size: 16, color: _onVideo),
                      );
                    },
                  ),
                  // The identity half is a label, not a door: no tap, no
                  // details sheet — the anchor's facts stay where they are.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: DsSpace.s3),
                    child: _capsuleIdentity(name: name, avatar: avatar, where: where),
                  ),
                  // The follow verb rides the capsule: in the immersive shapes
                  // it is the only follow surface, the column being gone.
                  DsPressable(
                    semanticLabel: followed ? t.room.unfollow : t.room.follow,
                    onPressed: () {
                      widget.onWake();
                      unawaited(toggleRoomFollow(context, ref));
                    },
                    builder: (context, states, _) {
                      final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                      final ink = followed ? _onVideo : OnVideoColors.foreground;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
                        decoration: BoxDecoration(
                          color: followed ? _onVideoHover : colors.accent,
                          borderRadius: BorderRadius.circular(DsRadii.pill),
                          border: Border.all(
                            color: lit ? OnVideoColors.foreground.withValues(alpha: 0.6) : OnVideoColors.clear,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s4,
                          children: [
                            DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconXs, color: ink),
                            Text(
                              followed ? t.room.unfollow : t.room.follow,
                              style: theme.typography.caption.copyWith(color: ink, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // The facts' door: a chevron that unfolds the room's own
                  // words over the pill, the way the reference's capsule does.
                  DsPressable(
                    semanticLabel: t.room.detailsHint,
                    onPressed: () {
                      widget.onWake();
                      setState(() => _expanded = !_expanded);
                    },
                    builder: (context, states, _) {
                      final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                      return Container(
                        width: theme.sizes.sm,
                        height: theme.sizes.sm,
                        alignment: Alignment.center,
                        decoration: DsBoxDecoration(
                          color: lit ? _onVideoHover : null,
                          borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
                        ),
                        child: DsIcon(
                          _expanded ? DsIcons.chevronUp : DsIcons.chevronDown,
                          size: 14,
                          color: _onVideoMuted,
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (_expanded)
                Text.rich(
                  TextSpan(
                    style: theme.typography.caption.copyWith(color: OnVideoColors.inkSubtle),
                    children: [
                      TextSpan(text: detail.content.title),
                      const TextSpan(text: ' · '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => unawaited(shareRoom(context, detail)),
                          child: Text(
                            t.room.share,
                            style: theme.typography.caption.copyWith(
                              color: _onVideo,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' · '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => unawaited(showRoomDetails(context)),
                          child: Text(
                            t.room.detailsHint,
                            style: theme.typography.caption.copyWith(
                              color: _onVideo,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The immersive shapes' text gbtn (the reference's gbtns row): one word on a
/// glass chip at the picture's top-right, above the tool cluster. The exit
/// verb — the page's own leave, out of the mode first, then out of the room —
/// and the theatre's chat toggle both wear it.
final class _ModeExitChip extends StatelessWidget {
  const _ModeExitChip({required this.label, required this.onPressed, required this.onWake});

  final String label;
  final VoidCallback onPressed;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final side = PlayerBarTier.tvOf(context) ? theme.sizes.lg : theme.sizes.sm;
    final corners = theme.radii.controlCorners(null, side);
    final pressable = DsPressable(
      semanticLabel: label,
      onPressed: () {
        onWake();
        onPressed();
      },
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          height: side,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
          alignment: Alignment.center,
          decoration: DsBoxDecoration(color: lit ? _onVideoHover : null, borderRadius: corners),
          child: Text(
            label,
            maxLines: 1,
            style: theme.typography.caption.copyWith(color: _onVideo, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
    return DsTooltip(message: label, child: pressable);
  }
}
