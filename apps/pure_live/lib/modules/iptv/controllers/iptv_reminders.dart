import 'dart:async' show Stream, StreamController, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart' show DsStatus, showDsToast;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/l10n/translations.dart' show t;

/// The preference the module's programme reminders (预约) are kept under.
const String kIptvRemindersKey = 'iptv.reminders';

/// A programme the viewer asked the module to remind them about.
///
/// The reference sets a reminder from the programme guide and switches to the
/// channel when the programme starts; this record is what survives a restart,
/// and the controller below is what turns its start into a moment.
@immutable
final class IptvReminder {
  /// A reminder for [title] on [channelId].
  const IptvReminder({required this.channelId, required this.title, required this.start, required this.stop});

  /// The library's channel id (stable across playlist re-imports).
  final String channelId;

  /// The programme's name, as the guide spells it.
  final String title;

  /// When the programme starts (the moment the reminder fires).
  final DateTime start;

  /// When it stops.
  final DateTime stop;

  /// Whether this is the reminder for the programme that starts at [start]
  /// on [channelId].
  bool isFor(String channelId, DateTime start) => this.channelId == channelId && this.start == start;

  Map<String, Object?> toJson() => {
    'channelId': channelId,
    'title': title,
    'start': start.millisecondsSinceEpoch,
    'stop': stop.millisecondsSinceEpoch,
  };

  static IptvReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final channelId = json['channelId'];
    final title = json['title'];
    final start = (json['start'] as num?)?.toInt();
    final stop = (json['stop'] as num?)?.toInt();
    if (channelId is! String || channelId.isEmpty || start == null || stop == null) return null;
    return IptvReminder(
      channelId: channelId,
      title: title is String ? title : '',
      start: DateTime.fromMillisecondsSinceEpoch(start),
      stop: DateTime.fromMillisecondsSinceEpoch(stop),
    );
  }
}

/// The viewer's reminders, soonest first.
///
/// A reminder is a moment, so the controller arms one timer for the next one
/// rather than polling: the guide can hold a whole night of them and the app
/// wakes exactly as many times as there are reminders. When one comes due the
/// controller says so — the player switches to the channel, the browser shows
/// the toast — and the record leaves the list, because a reminder that has
/// rung is not one the viewer still needs.
final class IptvRemindersController extends Notifier<List<IptvReminder>> {
  final StreamController<IptvReminder> _fired = StreamController<IptvReminder>.broadcast();
  Timer? _timer;
  bool _disposed = false;

  /// The reminders as they come due, in the order they were armed.
  Stream<IptvReminder> get fired => _fired.stream;

  @override
  List<IptvReminder> build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      unawaited(_fired.close());
    });
    final now = DateTime.now();
    final stored = [
      for (final reminder in _read())
        if (reminder.start.isAfter(now)) reminder,
    ]..sort((a, b) => a.start.compareTo(b.start));
    unawaited(Future<void>.microtask(_arm));
    return stored;
  }

  /// Every reminder, soonest first.
  List<IptvReminder> get reminders => state;

  /// Whether the programme starting at [start] on [channelId] already has a
  /// reminder.
  bool contains(String channelId, DateTime start) => state.any((reminder) => reminder.isFor(channelId, start));

  /// Sets a reminder for [reminder], or clears the one that answers it.
  ///
  /// Returns whether the reminder is now set, so the caller's toast says what
  /// actually happened.
  Future<bool> toggle(IptvReminder reminder) async {
    final exists = contains(reminder.channelId, reminder.start);
    if (exists) {
      state = [
        for (final entry in state)
          if (!entry.isFor(reminder.channelId, reminder.start)) entry,
      ];
    } else {
      if (!reminder.start.isAfter(DateTime.now())) return false;
      state = [
        for (final entry in state)
          if (!entry.isFor(reminder.channelId, reminder.start)) entry,
        reminder,
      ]..sort((a, b) => a.start.compareTo(b.start));
    }
    await _save();
    _arm();
    return !exists;
  }

  /// Drops every reminder.
  Future<void> clear() async {
    state = const [];
    _timer?.cancel();
    _timer = null;
    await _save();
  }

  void _arm() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final now = DateTime.now();
    final upcoming = [
      for (final reminder in state)
        if (reminder.start.isAfter(now)) reminder,
    ];
    if (upcoming.isEmpty) return;
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    _timer = Timer(upcoming.first.start.difference(now), _fireDue);
  }

  void _fireDue() {
    if (_disposed) return;
    final now = DateTime.now();
    final due = [
      for (final reminder in state)
        if (!reminder.start.isAfter(now)) reminder,
    ];
    if (due.isNotEmpty) {
      state = [
        for (final reminder in state)
          if (reminder.start.isAfter(now)) reminder,
      ];
      unawaited(_save());
      final context = rootNavigatorKey.currentContext;
      for (final reminder in due) {
        _fired.add(reminder);
        if (context != null && context.mounted) {
          showDsToast(
            context: context,
            title: t.iptv.reminderStarted(title: reminder.title),
            status: DsStatus.info,
          );
        }
      }
    }
    _arm();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kIptvRemindersKey, jsonEncode([for (final reminder in state) reminder.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<IptvReminder> _read() {
    try {
      final raw = StoragePrefs.getString(kIptvRemindersKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?IptvReminder.fromJson(entry)];
    } on Object {
      return const [];
    }
  }
}

/// The module's programme reminders.
final iptvRemindersProvider = NotifierProvider<IptvRemindersController, List<IptvReminder>>(
  IptvRemindersController.new,
);
