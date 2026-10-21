import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomIdentity, RoomContent;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/layouts/room_desktop_layout.dart';
import 'package:pure_live/features/room/layouts/room_phone_landscape_layout.dart';
import 'package:pure_live/features/room/layouts/room_phone_portrait_layout.dart';
import 'package:pure_live/features/room/layouts/room_tablet_layout.dart';
import 'package:pure_live/features/room/layouts/room_tv_layout.dart';
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/room_shell.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The live room page — the reference's `LivePlayPage`.
///
/// This file owns nothing but the dispatch. The logic is in [RoomController]
/// (the detail, the stream, the engine, the presentation), and the drawing is
/// in one layout per shape a room is seen in: an upright phone, a phone on its
/// side, a tablet, a desktop window, a TV. Those are not one adaptive tree with
/// different numbers, because they do not put the same things on screen — a
/// sideways phone has no height for a column, and a TV has no hover to bring
/// hidden chrome back with.
final class RoomPage extends ConsumerWidget {
  /// Opens [roomId] on [siteId]; [roomName] titles the bar until the room
  /// detail arrives.
  const new({required this.siteId, required this.roomId, this.roomName = '', super.key});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A caller-provided title hint.
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = (siteId: siteId, roomId: roomId);
    final state = ref.watch(roomControllerProvider(identity));
    final controller = ref.read(roomControllerProvider(identity).notifier);
    final immersive = state.presentation != RoomPresentation.normal;
    // The sleep countdown pauses the room in the controller; the page owns the
    // announcement — the reference toasts `room_playback_timer_finished` on
    // the same beat.
    ref.listen(roomControllerProvider(identity), (previous, next) {
      if (previous != null && next.sleepEndedTick > previous.sleepEndedTick) {
        PureToast.show(context, context.t.room.timerFinished);
      }
    });

    final site = ref.watch(sitesProvider).registry.getById(siteId);
    final siteName = site?.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN') ?? siteId;
    // The route's own hint carries the bar until the detail arrives, and it
    // keeps carrying the title afterwards: kuaishou's room page has no
    // broadcast title at all (its reference leaves that field empty on
    // purpose), so a detail that knows nothing must not blank the name the
    // card, the history row or the link did know. The merge only fills holes —
    // every other field of the fresher record wins.
    final hint = LiveRoom.normalized(
      platform: siteId,
      roomId: roomId,
      content: RoomContent(title: roomName),
    );
    final room = state.room == null ? hint : state.room!.mergedWith(hint);

    return PopScope(
      // The remote's Back and the phone's gesture leave the presentation first
      // and the route second: a full-screen room that pops on the first Back
      // loses the video the user was still watching.
      canPop: !immersive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          controller.setPresentation(RoomPresentation.normal);
        }
      },
      child: CallbackShortcuts(
        bindings: _shortcuts(controller, state),
        child: _isTouch
            ? _body(identity, controller, state, room, siteName)
            : Focus(autofocus: true, child: _body(identity, controller, state, room, siteName)),
      ),
    );
  }

  Widget _body(RoomIdentity identity, RoomController controller, RoomState state, LiveRoom room, String siteName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shell = resolveRoomShell(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          formFactor: controller.formFactor,
          isTouch: _isTouch,
        );
        return switch (shell) {
          RoomShell.phonePortrait => RoomPhonePortraitLayout(
            identity: identity,
            controller: controller,
            state: state,
            room: room,
            siteName: siteName,
          ),
          RoomShell.phoneLandscape => RoomPhoneLandscapeLayout(
            identity: identity,
            controller: controller,
            state: state,
            room: room,
            siteName: siteName,
          ),
          RoomShell.tabletSplit => RoomTabletLayout(
            identity: identity,
            controller: controller,
            state: state,
            room: room,
            siteName: siteName,
          ),
          RoomShell.desktopSplit => RoomDesktopLayout(
            identity: identity,
            controller: controller,
            state: state,
            room: room,
            siteName: siteName,
          ),
          RoomShell.tvFocus => RoomTvLayout(
            identity: identity,
            controller: controller,
            state: state,
            room: room,
            siteName: siteName,
          ),
        };
      },
    );
  }

  /// Keyboard transport, the reference's `VideoKeyboardShortcuts`: at a desk a
  /// pointer is the afterthought, and a room you watch with your hands full
  /// still needs a pause.
  Map<ShortcutActivator, VoidCallback> _shortcuts(RoomController controller, RoomState state) => {
    const SingleActivator(LogicalKeyboardKey.escape): () => controller.setPresentation(RoomPresentation.normal),
    const SingleActivator(LogicalKeyboardKey.space): controller.togglePause,
    const SingleActivator(LogicalKeyboardKey.keyK): controller.togglePause,
    const SingleActivator(LogicalKeyboardKey.keyF): () => controller.setPresentation(
      state.presentation == RoomPresentation.normal ? RoomPresentation.fullscreen : RoomPresentation.normal,
    ),
    const SingleActivator(LogicalKeyboardKey.keyM): controller.toggleMute,
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => controller.setVolume(state.volume + 0.05),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () => controller.setVolume(state.volume - 0.05),
  };

  /// Keys need a focused route to land on, and a touch device has no keys —
  /// asking it to focus would steal the first tap from the pane.
  static bool get _isTouch => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.iOS => true,
    _ => false,
  };
}
