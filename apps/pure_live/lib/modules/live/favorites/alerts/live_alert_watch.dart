import 'dart:async' show Future, unawaited;
import 'dart:convert';
import 'dart:io' show File, FileSystemException;

import 'package:live_sites/live_sites.dart' show LiveRoom;

import 'package:pure_live/modules/live/favorites/alerts/live_alerts.dart' show LiveAlertSeen;

/// The notification's words, in the app's language at the last write, with
/// `{name}`/`{platform}`/`{roomId}` placeholders the background fills.
typedef LiveAlertTexts = ({String bodyTemplate, String fallbackTemplate});

/// One covered follow, the row the background check reads: its identity and
/// the two names a notification needs, no live state of any kind.
final class LiveAlertRoom {
  /// Creates the row.
  const LiveAlertRoom({required this.platform, required this.roomId, required this.name, required this.platformLabel});

  /// Reads [json]; null when it is not a row.
  static LiveAlertRoom? fromJson(Object? json) {
    if (json is! Map) return null;
    final platform = json['platform'];
    final roomId = json['roomId'];
    if (platform is! String || roomId is! String || platform.isEmpty || roomId.isEmpty) return null;
    return LiveAlertRoom(
      platform: platform,
      roomId: roomId,
      name: json['name'] is String ? json['name']! as String : '',
      platformLabel: json['platformLabel'] is String ? json['platformLabel']! as String : platform,
    );
  }

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

  /// The streamer's display name; an empty string when none is known.
  final String name;

  /// The platform's own name, the word the notification body carries.
  final String platformLabel;

  /// The room's identity key, the state map's key.
  String get identityKey => '$platform:$roomId';

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'platform': platform,
    'roomId': roomId,
    'name': name,
    'platformLabel': platformLabel,
  };

  /// Fills [texts] for this room: the notification's title and body, the
  /// same shapes the in-app watcher posts with.
  ({String title, String body}) contentOf(LiveAlertTexts texts, {String? liveTitle}) {
    final name = this.name.trim();
    final title = (liveTitle ?? '').trim();
    final filled = title.isEmpty
        ? texts.fallbackTemplate.replaceAll('{platform}', platformLabel).replaceAll('{roomId}', roomId)
        : title;
    final body = texts.bodyTemplate.replaceAll('{platform}', platformLabel).replaceAll('{name}', name);
    return (title: filled, body: body);
  }
}

/// What the app and the background check share: the follows covered, what
/// is known of each (so a broadcast is told once, whoever saw it first) and
/// the words of the notification. The check opens no database and uses no
/// cookies.
final class LiveAlertWatch {
  /// Creates the state.
  const LiveAlertWatch({required this.rooms, required this.states, required this.texts, this.nextCheck});

  /// Reads [json]; null when it is not a state of this version.
  static LiveAlertWatch? fromJson(Object? json) {
    if (json is! Map || json['v'] != version) return null;
    DateTime? time(Object? value) => value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
    final texts = json['texts'];
    if (texts is! Map) return null;
    final bodyTemplate = texts['body'];
    final fallbackTemplate = texts['fallback'];
    if (bodyTemplate is! String || fallbackTemplate is! String) return null;
    final rows = <LiveAlertRoom>[];
    for (final entry in json['rooms'] is List ? json['rooms']! as List<Object?> : const <Object?>[]) {
      final row = LiveAlertRoom.fromJson(entry);
      if (row != null) rows.add(row);
    }
    final states = <String, LiveAlertSeen>{};
    final saved = json['states'];
    if (saved is Map) {
      for (final MapEntry(:key, :value) in saved.entries) {
        if (value is! Map) continue;
        final seenAt = time(value['seenAt']);
        final live = value['live'];
        final name = key is String ? key : null;
        if (seenAt == null || live is! bool || name == null) continue;
        states[name] = (
          live: live,
          startedAt: time(value['startedAt']),
          endedAt: time(value['endedAt']),
          seenAt: seenAt,
        );
      }
    }
    return LiveAlertWatch(
      rooms: rows,
      states: states,
      texts: (bodyTemplate: bodyTemplate, fallbackTemplate: fallbackTemplate),
      nextCheck: time(json['nextCheck']),
    );
  }

  /// The file's version.
  static const int version = 1;

  /// The follows covered.
  final List<LiveAlertRoom> rooms;

  /// What is known of each room (the tracker's `states` map).
  final Map<String, LiveAlertSeen> states;

  /// The notification's words.
  final LiveAlertTexts texts;

  /// Until when the app checks itself: the background check does nothing
  /// before then.
  final DateTime? nextCheck;

  /// The row of [room], or null when it is not covered.
  LiveAlertRoom? roomOf(LiveRoom room) {
    final key = '${room.ref.platform}:${room.ref.roomId}';
    for (final row in rooms) {
      if (row.identityKey == key) return row;
    }
    return null;
  }

  /// A copy with [states].
  LiveAlertWatch withStates(Map<String, LiveAlertSeen> states) =>
      LiveAlertWatch(rooms: rooms, states: states, texts: texts, nextCheck: nextCheck);

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'v': version,
    'nextCheck': nextCheck?.millisecondsSinceEpoch,
    'texts': {'body': texts.bodyTemplate, 'fallback': texts.fallbackTemplate},
    'rooms': [for (final room in rooms) room.toJson()],
    'states': {
      for (final MapEntry(:key, :value) in states.entries)
        key: {
          'live': value.live,
          'startedAt': value.startedAt?.millisecondsSinceEpoch,
          'endedAt': value.endedAt?.millisecondsSinceEpoch,
          'seenAt': value.seenAt.millisecondsSinceEpoch,
        },
    },
  };
}

/// The file the app and the background check share.
final class LiveAlertWatchFile {
  /// Creates the store over [file].
  LiveAlertWatchFile(this.file);

  /// The file name in the app's data area.
  static const String name = 'live_alert_watch.json';

  /// The file.
  final File file;

  /// The state; null when there is none or it cannot be read.
  Future<LiveAlertWatch?> read() async {
    try {
      if (!file.existsSync()) return null;
      return LiveAlertWatch.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      return null;
    }
  }

  /// Writes [watch] whole: a temporary file renamed over the old one, so a
  /// reader never sees half of it. Each write has a temporary file of its
  /// own — the app and the background check run beside each other, and two
  /// writes sharing one name cut each other short. Writes through one store
  /// land in the order they were asked for.
  Future<void> write(LiveAlertWatch watch) => _inTurn(() async {
    final temporary = File('${file.path}.${_serial++}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await temporary.parent.create(recursive: true);
      await temporary.writeAsString(jsonEncode(watch.toJson()), flush: true);
      await temporary.rename(file.path);
    } on Object {
      try {
        unawaited(temporary.delete());
      } on FileSystemException {
        // Gone already.
      }
      rethrow;
    }
  });

  /// Removes the state (the switch turned off).
  Future<void> clear() async {
    try {
      unawaited(file.delete());
    } on FileSystemException {
      // Gone already.
    }
  }

  static int _serial = 0;
  Future<void> _last = Future<void>.value();

  Future<void> _inTurn(Future<void> Function() work) {
    final done = _last.then((_) => work());
    _last = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }
}

/// One watch write nobody waits on: the file is the record, not the flow.
void writeLiveAlertWatch(LiveAlertWatchFile file, LiveAlertWatch watch) =>
    unawaited(file.write(watch).catchError((Object _) {}));
