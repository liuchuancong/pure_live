import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, IconButton, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenAwakeService, ScreenAwakeService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart' show PlayerId, PresentationMode;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/presentation_providers.dart'
    show RoomPresentationController, roomPresentationProvider;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/room/player_surface.dart' show PlayerSurface;
import 'package:pure_live/features/room/room_chat.dart' show RoomChatPanel;
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_details.dart'
    show copyRoomLink, openRoomExternally, roomLinkOf, shareRoom, showRoomDetails;
import 'package:pure_live/features/room/room_orientation.dart'
    show RoomOrientation, roomFrameRatio, roomOrientationProvider, showRoomOrientationDialog;
import 'package:pure_live/features/room/room_status.dart' show roomSlowProvider, slowAfter;
import 'package:pure_live/features/room/sleep_timer.dart';
import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// The live room: media_core's picture with the app's control layer over
/// it, the room's facts under it, and the chat beside it on a wide window.
///
/// The layout follows the reference's inline shapes: from 840 px the
/// picture and its facts take the left and the chat a 300–400 px column on
/// the right; narrower windows stack the chat under the picture. Fullscreen,
/// window fullscreen and PiP hand the whole page to the picture — those
/// modes are media_core's presentation drivers, so the page only follows the
/// state they publish.
final class RoomPage extends ConsumerStatefulWidget {
  /// The room to open, by platform and room id.
  const RoomPage({required this.platform, required this.roomId, super.key});

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

final class _RoomPageState extends ConsumerState<RoomPage> with WidgetsBindingObserver {
  Timer? _slowTimer;

  /// The presentation controller and player in hand, kept so the page's
  /// disposal can leave a fullscreen or a small window even when the viewer
  /// left by a route pop rather than the room's own controls.
  RoomPresentationController? _presentationController;
  PlayerId? _player;

  /// The screen wakelock while the picture plays: a live room is watched,
  /// not read, and the display should not sleep under it.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  /// Whether this background visit already asked for a small window: one
  /// entry per leave, reset when the app comes back.
  bool _autoPipRequested = false;

  /// The room's width at which the chat moves beside the picture (the
  /// reference's `wide` layout).
  static const double _wideBreakpoint = 840;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The sleep timer must stop this room, not some global notion of one.
    ref.read(sleepTimerProvider.notifier).onFire_ = _onSleepFire;
    // The room never opens from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(roomProvider.notifier).open(platform: widget.platform, roomId: widget.roomId));
    });
  }

  /// The timer fired: pause the stream (never resume a paused room) and say
  /// so.
  void _onSleepFire() {
    unawaited(ref.read(roomProvider.notifier).pause());
    if (mounted) {
      showDsToast(context: context, title: context.t.room.sleepDone);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slowTimer?.cancel();
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    try {
      ref.read(sleepTimerProvider.notifier)
        ..onFire_ = null
        ..start(null);
      // The room's provider outlives the page; leaving the route must stop
      // the stream rather than keep decoding behind the next page.
      unawaited(ref.read(roomProvider.notifier).close());
      final controller = _presentationController;
      final player = _player;
      if (controller != null && player != null) {
        unawaited(controller.exit(player));
      }
    } on Object {
      // The container is already gone (app shutdown); nothing to stop.
    }
    super.dispose();
  }

  void _watchSlow(RoomState room) {
    final connecting = room.room != null && room.handle == null && !room.playback.playing;
    if (connecting && _slowTimer == null) {
      _slowTimer = Timer(slowAfter, () {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = true;
      });
    } else if (!connecting && _slowTimer != null) {
      _slowTimer?.cancel();
      _slowTimer = null;
      // The flag feeds the overlay this build reads; flipping it after the
      // frame avoids modifying a provider mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = false;
      });
    }
  }

  /// Holds the display awake exactly while frames are playing: a paused or
  /// failed room lets the display sleep as usual.
  void _syncScreenWake(bool playing) {
    if (playing == _screenHeld) return;
    _screenHeld = playing;
    unawaited((playing ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoPipRequested = false;
      return;
    }
    // The moment the app starts leaving is the one Android's PiP entry
    // needs; by `paused` the activity is already backgrounded.
    if (state == AppLifecycleState.inactive) _maybeAutoPip();
  }

  /// "离开应用时自动小窗": a playing room becomes the system small window
  /// once per leave. Phones only — a desktop loses focus all the time and
  /// the setting names the app going away, not a window.
  void _maybeAutoPip() {
    if (_autoPipRequested || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    final room = ref.read(roomProvider);
    final handle = room.handle;
    if (handle == null || !room.playback.playing) return;
    if (!ref.read(playbackSettingsProvider).autoPipOnLeave) return;
    if (ref.read(roomPresentationProvider) != PresentationMode.normal) return;
    _autoPipRequested = true;
    unawaited(ref.read(roomPresentationProvider.notifier).togglePip(handle.id));
  }

  /// The frame's ratio: the room's own orientation choice when it made
  /// one, else the picture's width over height once the engine reports it,
  /// else the usual 16:9. A portrait stream keeps its tall shape instead of
  /// sitting letterboxed in a landscape box.
  double _pictureRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    final ratio = detected <= 0 || !detected.isFinite ? 16 / 9 : detected;
    final key = room.room?.ref.identityKey;
    final orientation = key == null ? RoomOrientation.automatic : ref.watch(roomOrientationProvider(key));
    return roomFrameRatio(orientation, detected: ratio).clamp(0.5, 2.4);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    _syncScreenWake(room.playback.playing);
    final presentation = ref.watch(roomPresentationProvider);
    final colors = DsTheme.colorsOf(context);
    // A TV remote uses the arrows to move focus and its own volume keys
    // for sound; a desktop keyboard keeps the arrows on the volume.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    _watchSlow(room);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    _presentationController = presentationController;
    _player = room.handle?.id;

    /// The back arrow and Escape: leave the presentation mode while one
    /// holds the page, otherwise leave the room.
    void leave() {
      final player = room.handle?.id;
      if (presentation != PresentationMode.normal && player != null) {
        unawaited(presentationController.exit(player));
      } else {
        context.pop();
      }
    }

    // F enters/leaves fullscreen, Escape leaves the mode (or, in the page's
    // own layout, the room), Space plays and pauses. A focused text field
    // consumes the keys first, so the composer never flips the playback.
    void nudgeVolume(double delta) {
      final handle = room.handle;
      if (handle == null) return;
      unawaited(ref.read(roomProvider.notifier).setVolume(handle.volume + delta));
    }

    final keys = <SingleActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyF): () {
        final player = room.handle?.id;
        if (player != null) unawaited(presentationController.toggleFullscreen(player));
      },
      const SingleActivator(LogicalKeyboardKey.escape): leave,
      const SingleActivator(LogicalKeyboardKey.space): () =>
          unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
      if (!tv) const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudgeVolume(0.05),
      if (!tv) const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudgeVolume(-0.05),
      const SingleActivator(LogicalKeyboardKey.keyR): () => unawaited(ref.read(roomProvider.notifier).retry()),
    };

    final player = PlayerSurface(
      roomState: room,
      barrage: ref.read(roomProvider.notifier).barrage,
      onLeave: leave,
      immersive: presentation != PresentationMode.normal,
      // The TV room starts on its play button and keeps its bars: a remote
      // has no pointer to wake them, and arrows must walk controls.
      keepControls: tv,
      autofocusFirstControl: tv,
    );

    final pictureRatio = _pictureRatio(room);

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (!wide) {
          // The reference's narrow room: the picture, the strip with the
          // room's facts, then the chat below it. The picture keeps its
          // shape but never takes the chat's last 150 px: a short window
          // shrinks it instead of overflowing the column.
          final maxPicture = math.max<double>(
            0,
            (constraints.maxHeight.isFinite ? constraints.maxHeight - 150 : 480).toDouble(),
          );
          final portrait = pictureRatio < 1;
          final ratio = portrait ? pictureRatio.clamp(0.5, 0.8) : pictureRatio.clamp(1.0, 2.4);
          final desired = portrait ? constraints.maxHeight * 0.58 : constraints.maxWidth / ratio;
          final picture = SizedBox(
            height: math.min(desired, maxPicture),
            child: ColoredBox(
              color: colors.overlay,
              child: Center(child: AspectRatio(aspectRatio: ratio, child: player)),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              picture,
              _RoomInfoBar(room: room),
              DsLine(color: colors.border),
              const Expanded(child: RoomChatPanel()),
            ],
          );
        }
        // The reference's wide room: the picture centred in the stage at its
        // own shape, and the chat column with the strip above it.
        final chatWidth = (constraints.maxWidth * 0.34).clamp(300.0, 400.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: colors.overlay,
                child: Center(
                  child: AspectRatio(aspectRatio: pictureRatio, child: player),
                ),
              ),
            ),
            Container(width: 1, color: colors.border),
            SizedBox(
              width: chatWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoomInfoBar(room: room),
                  DsLine(color: colors.border),
                  const Expanded(child: RoomChatPanel()),
                ],
              ),
            ),
          ],
        );
      },
    );

    // The page, not the body, holds the shortcuts: Space and the arrows
    // must work while an AppBar action or a chat field has focus too.
    Widget withShortcuts(Widget child) => Focus(
      // A mouse/keyboard room keeps the page itself as the shortcut
      // holder; the TV room leaves the focus to the player's first control.
      autofocus: !tv,
      child: CallbackShortcuts(bindings: keys, child: child),
    );

    // A presentation mode owns the whole page; the inline room keeps the
    // app bar with its header, follow button and menu.
    if (presentation != PresentationMode.normal) {
      return withShortcuts(ColoredBox(color: colors.overlay, child: player));
    }
    return withShortcuts(
      Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: const Color(0x00000000),
          elevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 52,
          leading: IconButton(
            tooltip: t.common.back,
            onPressed: leave,
            icon: DsIcon(DsIcons.chevronLeft, size: 20, color: colors.text),
          ),
          titleSpacing: 0,
          title: _RoomHeader(room: room),
          actions: [
            _FollowPill(room: room),
            _RoomMenu(room: room, onClose: leave),
            const SizedBox(width: DsSpace.s4),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

/// The follows the room page reads (the follow button's watched list).
final followsRoomProvider = Provider<List<LiveRoom>>((ref) {
  ref.watch(followsProvider);
  return ref.read(followsProvider).rooms;
});

/// The app bar's room header: the streamer's avatar and name, and the
/// platform · area line under it — the reference's `RoomHeader`, in the
/// app's own type and tokens.
final class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) {
      return const Row(
        spacing: DsSpace.s8,
        children: [
          DsSkeleton(width: DsSpace.s24, height: DsSpace.s24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s3,
            children: [DsSkeleton(width: 96, height: 12), DsSkeleton(width: 132, height: 9)],
          ),
        ],
      );
    }
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsAvatar(
          initials: name,
          image: avatar.isEmpty ? null : cachedImage(avatar),
          size: DsSize.sm,
          semanticLabel: name,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
              Text(
                area.isEmpty ? platform : '$platform · $area',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The follow action in the app bar: a labelled pill on a wide window, the
/// same pill on a phone (it gives way only if the header needs the room).
final class _FollowPill extends ConsumerWidget {
  const _FollowPill({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) return const SizedBox.shrink();
    final followed = ref.watch(
      followsRoomProvider.select((follows) {
        final key = detail.ref.identityKey;
        return follows.any((followed_) => followed_.ref.identityKey == key);
      }),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
      child: DsButton(
        variant: followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
        size: DsSize.sm,
        onPressed: () => unawaited(ref.read(roomProvider.notifier).toggleFollow()),
        leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconSm),
        child: Text(followed ? t.room.unfollow : t.room.follow),
      ),
    );
  }
}

/// The room's overflow menu: its details, a light refresh, passing the room
/// on (share, the platform's own page, its link), a playback retry and the
/// way out. The player's own bar keeps the picture and stream actions.
final class _RoomMenu extends ConsumerWidget {
  const _RoomMenu({required this.room, required this.onClose});

  final RoomState room;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = room.room;
    final link = detail == null ? '' : roomLinkOf(detail);
    final external = detail != null &&
        ((detail.links.webUrl?.trim().isNotEmpty ?? false) || (detail.links.appUrl?.trim().isNotEmpty ?? false));
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
      child: DsMenuAnchor(
        semanticLabel: t.common.more,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.info),
            label: Text(t.room.details),
            onPressed: () => unawaited(showRoomDetails(context)),
          ),
          if (detail != null)
            DsMenuItem(
              leading: const DsIcon(DsIcons.rectangleVertical),
              label: Text(t.room.orientation),
              onPressed: () => unawaited(showRoomOrientationDialog(context, detail)),
            ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.refreshCw),
            label: Text(t.room.refreshRoom),
            onPressed: () => unawaited(ref.read(roomProvider.notifier).refreshRoom()),
          ),
          if (detail != null)
            DsMenuItem(
              leading: const DsIcon(DsIcons.share),
              label: Text(t.room.share),
              onPressed: () => unawaited(shareRoom(context, detail)),
            ),
          if (detail != null && external)
            DsMenuItem(
              leading: const DsIcon(DsIcons.externalLink),
              label: Text(t.room.openExternal),
              onPressed: () => unawaited(openRoomExternally(context, detail)),
            ),
          if (detail != null && link.isNotEmpty)
            DsMenuItem(
              leading: const DsIcon(DsIcons.link),
              label: Text(t.room.copyLink),
              onPressed: () => unawaited(copyRoomLink(context, detail)),
            ),
          const DsMenuDivider(),
          DsMenuItem(
            leading: const DsIcon(DsIcons.undo),
            label: Text(t.common.retry),
            onPressed: () => unawaited(ref.read(roomProvider.notifier).retry()),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.x),
            label: Text(t.common.close),
            destructive: true,
            onPressed: onClose,
          ),
        ],
        builder: (context, controller, _) => DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.common.more,
          onPressed: controller.toggle,
          icon: const DsIcon(DsIcons.ellipsis),
        ),
      ),
    );
  }
}

/// The strip above the chat (the reference's `RoomInfoBar`): the room's
/// state and title on the first line, the audience figures and the sleep
/// timer on the second. It sits in the chat column on a wide window and
/// under the picture on a phone, never over the picture itself.
final class _RoomInfoBar extends ConsumerWidget {
  const _RoomInfoBar({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s6,
          children: [DsSkeleton(width: 168, height: 14), DsSkeleton(width: 96, height: 10)],
        ),
      );
    }
    final audience = detail.audience.onlineViewers ?? detail.audience.popularity ?? detail.audience.totalViewers;
    final started = detail.broadcast.startedAt;
    return DsPressable(
      semanticLabel: t.room.detailsHint,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, child) => ColoredBox(
        color: states.contains(WidgetState.hovered) ? colors.hover : colors.surface,
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s12, DsSpace.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s4,
          children: [
            Row(
              spacing: DsSpace.s6,
              children: [
                if (detail.broadcast.isRecord)
                  DsBadge(dot: false, label: Text(t.favorites.statusReplay), status: DsStatus.info)
                else if (detail.broadcast.isLiveNow)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                      ),
                      Text(
                        t.favorites.statusLiveNow,
                        style: theme.typography.caption.copyWith(color: colors.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                else
                  DsBadge(dot: false, label: Text(t.favorites.statusOfflineNow)),
                Flexible(
                  child: Text(
                    detail.content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.title.copyWith(color: colors.text),
                  ),
                ),
                DsIcon(DsIcons.chevronDown, size: theme.sizes.iconXs, color: colors.textSubtle),
              ],
            ),
            Row(
              spacing: DsSpace.s8,
              children: [
                if (audience != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s3,
                    children: [
                      DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        AudienceFormat.format(audience),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                      ),
                    ],
                  ),
                if (started != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s3,
                    children: [
                      DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        _clock(started),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                      ),
                    ],
                  ),
                const Spacer(),
                const _SleepChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

/// The sleep timer's chip: off shows a moon that opens the picker; running
/// shows the countdown and the picker's first item stops it.
final class _SleepChip extends ConsumerWidget {
  const _SleepChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final running = timer.minutes != null;
    final label = running ? '${timer.minutes} min' : t.room.sleep;
    return DsMenuAnchor(
      semanticLabel: t.room.sleep,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.room.sleep,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            height: theme.sizes.sm,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
            decoration: DsBoxDecoration(
              color: running
                  ? theme.selectedFill
                  : hovered
                  ? colors.hover
                  : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                DsIcon(
                  DsIcons.moon,
                  size: theme.sizes.iconSm,
                  color: running ? theme.onSelectedFill : colors.textMuted,
                ),
                Text(
                  label,
                  style: theme.typography.caption.copyWith(color: running ? theme.onSelectedFill : colors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
      items: [
        if (running)
          DsMenuItem(label: Text(t.room.sleepOff), onPressed: () => ref.read(sleepTimerProvider.notifier).start(null)),
        for (final minutes in const [15, 30, 60, 120, 240, 480])
          DsMenuItem(
            label: Text('$minutes min'),
            onPressed: () => ref.read(sleepTimerProvider.notifier).start(minutes),
          ),
      ],
    );
  }
}
