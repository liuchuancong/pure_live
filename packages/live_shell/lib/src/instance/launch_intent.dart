import 'dart:convert';

import 'package:meta/meta.dart';

/// Something the running instance was asked to do by a second launch, a file
/// association, a protocol link or a "打开方式" hand-off.
///
/// This exists because the natural single-instance implementation — "another
/// process started, so show the window" — throws away the only interesting part
/// of that second start. For this app the interesting ones are the common cases:
/// a viewer clicks a live-room link in a browser, shares a room from another
/// app, pastes a room code, or double-clicks an `.m3u` file, and in every one of
/// those the *argument* is the request. Dropping it means the app comes to the
/// foreground on an unrelated page and the viewer repeats the action.
@immutable
sealed class LaunchIntent {
  /// An intent.
  const new();

  /// The flag a start argument carries an encoded intent in.
  static const String argumentFlag = '--pure-live-intent=';

  /// The prefix of the flag carrying the raw argv a Windows shell would have
  /// lost to quoting, kept separate so a file path never has to be JSON-escaped
  /// by hand.
  static const String _kindKey = 'kind';
  static const String _valueKey = 'value';

  /// Encodes this intent as the argv a second process should be started with.
  ///
  /// Deliberately one flag holding one JSON string: it survives quoting on all
  /// three platforms and needs no per-kind argument grammar. Never put a
  /// credential, cookie or token in it — on Linux any local process can read
  /// `/proc/<pid>/cmdline`, and on Windows the command line lands in the
  /// security audit log.
  List<String> toArguments() => [
    '$argumentFlag${jsonEncode({_kindKey: kindTag, _valueKey: payload})}',
  ];

  /// The short tag this kind is encoded under.
  String get kindTag;

  /// The intent's data, as the string put in [_valueKey].
  String? get payload;

  /// Reads the intent out of a process's arguments, null when it carries none.
  static LaunchIntent? fromArguments(Iterable<String> arguments) {
    for (final argument in arguments) {
      if (!argument.startsWith(argumentFlag)) {
        continue;
      }
      final decoded = _decode(argument.substring(argumentFlag.length));
      if (decoded != null) {
        return decoded;
      }
    }
    return null;
  }

  /// Whether these arguments carry a forwarded request at all.
  static bool carriesIntent(Iterable<String> arguments) =>
      arguments.any((argument) => argument.startsWith(argumentFlag));

  static LaunchIntent? _decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) {
      return null;
    }
    final kind = json[_kindKey];
    final value = json[_valueKey];
    if (kind is! String) {
      return null;
    }
    // Anything unreadable is treated as "no intent", which leaves the second
    // instance to do the ordinary thing — show the app — rather than opening a
    // half-parsed link or failing to start at all.
    if (kind == ShowMainWindow.kind) {
      return ShowMainWindow(route: value is String ? value : null);
    }
    if (kind == NewWindow.kind) {
      return NewWindow(route: value is String ? value : null);
    }
    if (kind == ShowRecorder.kind) {
      return const ShowRecorder();
    }
    if (value is! String || value.isEmpty) {
      return null;
    }
    if (kind == OpenFile.kind) {
      return OpenFile(value);
    }
    if (kind == OpenRoomLink.kind) {
      final link = Uri.tryParse(value);
      return link == null ? null : OpenRoomLink(link);
    }
    return null;
  }
}

/// Bring the main window back, optionally navigating to [route].
@immutable
final class ShowMainWindow extends LaunchIntent {
  /// A request to show the app.
  const new({this.route});

  /// The intent's tag.
  static const String kind = 'show';

  /// Where to land, null meaning "leave it on whatever page it was".
  final String? route;

  @override
  String get kindTag => kind;

  @override
  String? get payload => route;

  @override
  bool operator ==(Object other) => other is ShowMainWindow && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

/// Open a room the viewer reached through a link or a share sheet.
@immutable
final class OpenRoomLink extends LaunchIntent {
  /// A request to open one room link.
  const new(this.link);

  /// The intent's tag.
  static const String kind = 'room';

  /// The room's address, in whatever form the platform's handler received it.
  final Uri link;

  @override
  String get kindTag => kind;

  @override
  String? get payload => link.toString();

  @override
  bool operator ==(Object other) => other is OpenRoomLink && other.link == link;

  @override
  int get hashCode => link.hashCode;
}

/// Import a file the shell handed the app: an `.m3u` list, an EPG, a backup.
@immutable
final class OpenFile extends LaunchIntent {
  /// A request to import [path].
  const new(this.path);

  /// The intent's tag.
  static const String kind = 'file';

  /// The file's path.
  final String path;

  @override
  String get kindTag => kind;

  @override
  String? get payload => path;

  @override
  bool operator ==(Object other) => other is OpenFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Open a second window at [route] rather than moving the main one.
@immutable
final class NewWindow extends LaunchIntent {
  /// A request for another window.
  const new({this.route});

  /// The intent's tag.
  static const String kind = 'new-window';

  /// What to show in it.
  final String? route;

  @override
  String get kindTag => kind;

  @override
  String? get payload => route;

  @override
  bool operator ==(Object other) => other is NewWindow && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

/// Show the recorder's window, the destination of a "stop recording" tray item
/// and of the completion notification.
@immutable
final class ShowRecorder extends LaunchIntent {
  /// A request to show the recorder.
  const new();

  /// The intent's tag.
  static const String kind = 'recorder';

  @override
  String get kindTag => kind;

  @override
  String? get payload => null;

  @override
  bool operator ==(Object other) => other is ShowRecorder;

  @override
  int get hashCode => kind.hashCode;
}

/// Whether an argument list is a *headless* start that must not open a window
/// at all: `--help`, `--version`, a CLI subcommand, or a headless session.
///
/// Checked before the single-instance lock and before any UI initialisation.
/// A GUI process that gets as far as creating a window (or a display connection)
/// cannot cleanly retreat, and on a machine with no display server that is the
/// difference between printing a version and hanging until something kills it.
bool isHeadlessStart(Iterable<String> arguments) {
  for (final argument in arguments) {
    if (argument == '--hidden' || argument == '--headless') {
      continue;
    }
    if (argument == '--help' ||
        argument == '-h' ||
        argument == '--version' ||
        argument == '-V' ||
        argument.startsWith('--cli')) {
      return true;
    }
  }
  return false;
}

/// Whether this start asks to come up invisible, straight into the tray.
///
/// Three platforms reach this state differently — a flag we pass ourselves, an
/// `.desktop` file's `Exec` line, and macOS's own "was opened as hidden" record
/// of what the user set in its Login Items panel — so the caller asks
/// [wasRequestedHidden] with whatever the OS reported in addition to its args.
bool wasRequestedHidden({required Iterable<String> arguments, bool openedAsHiddenBySystem = false}) =>
    openedAsHiddenBySystem || arguments.contains('--hidden');

/// What a second process should hand over when its own command line carried no
/// request.
///
/// Launching an app that is already running **is** the request: the viewer
/// double-clicked the icon and expects a window, which is the convention every
/// desktop follows (macOS reactivation, single-instance Windows apps raising
/// themselves). Forwarding nothing leaves the app hidden in the tray with a second
/// process that quietly did nothing — the exact "clicked it twice, nothing
/// happened" report that has no error to find.
///
/// `--hidden` is honoured, because a sign-in relaunch must not throw a window at
/// somebody who asked for none.
LaunchIntent? intentForHandoff(Iterable<String> arguments) {
  final explicit = LaunchIntent.fromArguments(arguments);
  if (explicit != null) {
    return explicit;
  }
  return arguments.contains('--hidden') ? null : const ShowMainWindow();
}
