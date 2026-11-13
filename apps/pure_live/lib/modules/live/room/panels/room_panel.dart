import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';

import 'package:pure_live/modules/live/room/page/room_details.dart' show RoomDetailsPanel;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show roomSleepTimerChoices, sleepTimerProvider;

/// The room's side panels: the sheets that linger beside the picture while
/// the viewer keeps watching. One at a time — inside the page the bus owns
/// the exclusion, and a widget opened from outside the room page (a card's
/// menu, the multi-view surface) gets the sheet directly, since there is no
/// page around to host and sequence it.
///
/// The room's momentary dialogs (the switcher, the shortcut help, the
/// orientation pick) keep their own show functions: they close on a pick,
/// carry per-call data, and modality already keeps them singular.
enum RoomPanelKind {
  /// The room's details: the streamer and the way back, the state, the
  /// figures, the links.
  details,

  /// The sleep timer's choices.
  sleepTimer,
}

/// The panel open in the room, or null.
final class RoomPanelController extends ValueNotifier<RoomPanelKind?> {
  /// Creates the controller with no panel open.
  new() : super(null);

  /// Opens [kind], closing another one.
  void open(RoomPanelKind kind) {
    if (value != kind) value = kind;
  }

  /// Closes the panel.
  void close() => value = null;
}

/// Hands the room's widgets the page's [RoomPanelController]: present above
/// the page's tree, null outside it (an open then falls back to a plain
/// sheet).
class RoomPanelScope extends InheritedNotifier<RoomPanelController> {
  /// Creates the scope around [child].
  const new({required RoomPanelController super.notifier, required super.child, super.key});

  /// The page's controller, or null outside the room page.
  static RoomPanelController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RoomPanelScope>()?.notifier;
}

/// The route name every room panel travels under, so the page can sweep a
/// panel off the stack before another one shows.
String roomPanelRouteName(RoomPanelKind kind) => 'room-panel-${kind.name}';

/// Whether [route] is a room panel's own route.
bool isRoomPanelRoute(Route<Object?> route) => route.settings.name?.startsWith('room-panel-') ?? false;

/// The sheet a panel renders as, wherever it is hosted. The page's host and
/// the lone-button fallback build the same thing from here, so the two
/// hosts cannot drift apart.
Widget roomPanelSheet(BuildContext sheetContext, RoomPanelKind kind) => switch (kind) {
  RoomPanelKind.details => DsPanel(title: Text(sheetContext.t.room.details), child: const RoomDetailsPanel()),
  RoomPanelKind.sleepTimer => DsPanel(
    title: Text(sheetContext.t.room.sleep),
    child: Consumer(
      builder: (context, ref, _) {
        final timer = ref.watch(sleepTimerProvider);
        return Column(
          children: [
            // A running timer leads with its own figure: the viewer who set
            // one comes back to ask how long is left, not to set it again.
            if (timer.endsAt case final endsAt?) _SleepRemaining(endsAt: endsAt),
            ...roomSleepTimerChoices(context, ref),
          ],
        );
      },
    ),
  ),
};

/// The running timer's own line: how long the room has left, ticking with
/// the second so the wait reads as a wait (the controller's state only
/// steps once a minute). The controller clearing the timer disposes the
/// row with its watch.
final class _SleepRemaining extends StatefulWidget {
  const _SleepRemaining({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_SleepRemaining> createState() => _SleepRemainingState();
}

final class _SleepRemainingState extends State<_SleepRemaining> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return const SizedBox.shrink();
    final time = '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          DsIcon(DsIcons.timer, size: 14, color: colors.textMuted),
          Text(
            context.t.room.sleepRemaining(time: time),
            style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The one open verb for the room's side panels. Inside the page the panel
/// is hosted there — one at a time, the page sweeps the previous one off
/// before the next shows; anywhere else it is a plain sheet.
Future<void> openRoomPanel(BuildContext context, RoomPanelKind kind) async {
  final controller = RoomPanelScope.maybeOf(context);
  if (controller == null) {
    await showDsPanel<void>(
      context: context,
      routeSettings: RouteSettings(name: roomPanelRouteName(kind)),
      builder: (sheetContext) => roomPanelSheet(sheetContext, kind),
    );
    return;
  }
  controller.open(kind);
}

/// Opens the room details: the reference's "直播间详情" laid over the page,
/// never over the picture. Everything a viewer may want to know about the
/// room and do about it lives there — the streamer and the way back to the
/// platform, the state and the full title, the figures, the notice and the
/// introduction, the room number and the link, plus share and open.
Future<void> showRoomDetails(BuildContext context) => openRoomPanel(context, RoomPanelKind.details);

/// The sleep timer's choices as a panel, for the surfaces that carry
/// actions in a list rather than a hover menu.
Future<void> showRoomSleepTimer(BuildContext context) => openRoomPanel(context, RoomPanelKind.sleepTimer);
