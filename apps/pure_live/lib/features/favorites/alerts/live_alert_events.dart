import 'package:live_sites/live_sites.dart' show LiveRoom;

/// One refresh pass's fresh rooms, handed to the live-alert watcher so it
/// sees a broadcast begin without polling again. [quiet] is a pass the user
/// started and is watching (manual refresh), which only updates what was
/// seen and posts nothing.
typedef LiveAlertObserver = void Function(List<LiveRoom> rooms, {required bool quiet});

/// Set by the primary window's live-alert watcher while it is mounted.
LiveAlertObserver? liveAlertObserver;
