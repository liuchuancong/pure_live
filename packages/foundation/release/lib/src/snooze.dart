// Module: lib/src/snooze.dart
// Purpose: The rule for asking again, so an update notice does not become a nag loop.
// Author: liuchuancong
// Created: 2026-10-11
//
// "Later" has to mean something. Without a record of what was dismissed and when, the next app start offers
// the same version again, the user says later again, and the only thing that changes is how much the dialog is
// hated. The other half of the rule is that a *newer* release ends the silence: a snooze on 4.1.0 must not
// swallow 4.2.0, which is the version that may carry the security fix.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'version.dart';

/// What the user chose last time, as recorded.
final class DismissedUpdate {
  const DismissedUpdate({required this.version, required this.at, required this.snoozeFor});

  /// The version that was dismissed.
  final AppVersion version;

  /// When it was dismissed.
  final DateTime at;

  /// How long the silence lasts. Zero means "never ask about this one again".
  final Duration snoozeFor;

  bool get isPermanent => snoozeFor == Duration.zero;

  /// True while the user's choice still covers this moment.
  bool isSilencing(DateTime now) {
    if (isPermanent) {
      return true;
    }
    return now.isBefore(at.add(snoozeFor));
  }

  /// The stored string form: `4.1.0+5100|2026-10-11T09:00:00.000Z|P7D`-shaped, and parsed strictly.
  String encode() {
    return '${version.full}|${at.toUtc().toIso8601String()}|${snoozeFor.inMinutes}';
  }

  /// Null for anything that is not this exact shape, including a value written by a newer build: an
  /// unparseable record is treated as "no choice on file", which asks once more rather than never asking.
  static DismissedUpdate? tryDecode(String? text) {
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    final parts = text.split('|');
    if (parts.length != 3) {
      return null;
    }
    final version = AppVersion.tryParse(parts[0]);
    final at = DateTime.tryParse(parts[1]);
    final minutes = int.tryParse(parts[2]);
    if (version == null || at == null || minutes == null || minutes < 0) {
      return null;
    }
    return DismissedUpdate(
      version: version,
      at: at.toUtc(),
      snoozeFor: Duration(minutes: minutes),
    );
  }

  @override
  String toString() => 'DismissedUpdate($version, at=$at, snooze=${snoozeFor.inMinutes}min)';

  @override
  bool operator ==(Object other) =>
      other is DismissedUpdate && other.version == version && other.at == at && other.snoozeFor == snoozeFor;

  @override
  int get hashCode => Object.hash(version, at, snoozeFor);
}

/// Where the choice is kept. The app binds it to its preference store; this package does not know how.
abstract interface class UpdateNoticeStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

/// The lengths a "later" button may offer.
enum SnoozeChoice {
  untilNextStart(const Duration(minutes: 20)),
  tonight(const Duration(hours: 8)),
  threeDays(const Duration(days: 3)),
  week(const Duration(days: 7)),
  never(Duration.zero);

  const SnoozeChoice(this.duration);

  final Duration duration;
}

/// The memory implementation, for a test or a build that has not wired its preferences yet.
final class InMemoryUpdateNoticeStore implements UpdateNoticeStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}

/// Decides whether an update notice may be shown.
final class UpdateNagPolicy {
  UpdateNagPolicy({required UpdateNoticeStore store, this.defaultSnooze = SnoozeChoice.week, Clock? clock})
    : _store = store,
      _clock = clock ?? systemClock;

  final UpdateNoticeStore _store;
  final SnoozeChoice defaultSnooze;
  final Clock _clock;

  /// The record on file, or null when there is none or it does not parse.
  Future<DismissedUpdate?> dismissed() async => DismissedUpdate.tryDecode(await _store.read());

  /// Whether to offer [candidate] now.
  ///
  /// A candidate *newer* than the dismissed version is always offered: the snooze is about that build, not
  /// about being left alone forever.
  Future<bool> shouldOffer(AppVersion candidate) async {
    final record = await dismissed();
    if (record == null) {
      return true;
    }
    if (candidate != record.version) {
      // A *newer* release always breaks the silence - the snooze was about that build, not about being left
      // alone. An older candidate means the record predates a rollback or a track switch, and asking is the
      // safe answer where silence is not.
      return true;
    }
    return !record.isSilencing(_clock());
  }

  /// Records the choice. [choice] defaults to the policy's own, so the button can call this without restating
  /// the length it represents.
  Future<DismissedUpdate> dismiss(AppVersion version, {SnoozeChoice? choice}) async {
    final selected = choice ?? defaultSnooze;
    final record = DismissedUpdate(version: version, at: _clock().toUtc(), snoozeFor: selected.duration);
    await _store.write(record.encode());
    return record;
  }

  /// Clears the record, which is what "check for updates now" from the settings screen should do first.
  Future<void> reset() => _store.clear();
}
