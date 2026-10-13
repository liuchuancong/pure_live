import 'package:live_shell/src/instance/launch_intent.dart';
import 'package:live_shell/src/window_role/window_role.dart';
import 'package:live_shell/src/window_set/secondary_windows.dart';

/// The part of a launch request only the application can answer.
///
/// Split from the router because the router can do the window work — bring a
/// window up, open another one — and cannot possibly know what a room link
/// means, where a playlist should land, or which widget is "the recorder".
abstract interface class LaunchSink {
  /// Shows the room behind [link].
  Future<void> showRoom(Uri link);

  /// Imports the playlist, guide or backup at [path].
  Future<void> importFile(String path);

  /// Moves the primary window to [route].
  Future<void> navigate(String route);

  /// Brings up the recording window.
  Future<void> showRecorder();
}

/// Turns a request that arrived from outside into the action it asked for.
///
/// This is the piece that decides whether the app feels desktop-correct when
/// something else launches it: a clicked room link, a double-clicked `.m3u`, an
/// "Open with" choice from the file manager, a browser handler, a tray item. The
/// failure mode to design against is the one every single-instance
/// implementation reaches for by default — **bring the window forward and drop
/// the argument** — which turns each of those into "I clicked it and the app
/// just showed the page it was already on".
///
/// Two orderings matter and both are load-bearing:
///
/// * The primary is revealed **before** the sink is asked to do anything with
///   the payload. A room cannot be opened into a window that is not on screen,
///   and a handoff that navigates a hidden window leaves the viewer staring at a
///   taskbar icon that appears to do nothing.
/// * [NewWindow] does the opposite: it must **not** raise the primary. Someone
///   asking for another window wants it next to what they are already looking
///   at; stealing the primary's focus would be a refusal dressed as a success.
class LaunchRouter {
  /// A router that opens windows through [windows] and asks the app through
  /// [sink].
  new({required this.windows, required this.revealMain, required this.sink});

  /// Where secondary windows come from.
  final SecondaryWindows windows;

  /// Brings the primary window forward, from wherever it is.
  final Future<void> Function() revealMain;

  /// The application's side of each request.
  final LaunchSink sink;

  /// Handles one request.
  ///
  /// Returns nothing on purpose: the caller that read it off a socket or a menu
  /// has no way to act on a failure, and a half-completed window raise is still
  /// better than a request that silently did nothing.
  Future<void> route(LaunchIntent intent) async {
    switch (intent) {
      case ShowMainWindow(:final String? route):
        await revealMain();
        if (route != null) {
          await sink.navigate(route);
        }
      case OpenRoomLink(:final Uri link):
        await revealMain();
        await sink.showRoom(link);
      case OpenFile(:final String path):
        await revealMain();
        await sink.importFile(path);
      case NewWindow(:final String? route):
        await windows.open(role: WindowRole.panel, route: route);
      case ShowRecorder():
        await revealMain();
        await sink.showRecorder();
    }
  }
}
