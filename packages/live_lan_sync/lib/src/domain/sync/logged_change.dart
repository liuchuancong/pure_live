import 'package:live_lan_sync/src/domain/sync/sync_change.dart';

/// One entry of a device's change log: a change and the position it holds
/// in this device's log.
///
/// The log keeps the latest change per entity, ordered by a sequence number
/// the device assigns from one strictly increasing counter. Peers follow a
/// device's log by sequence: "everything after 120" is exactly the entities
/// that changed since the peer last looked, each in its latest state —
/// deletes included, as tombstones (spec §10.1, §11.4).
final class LoggedChange {
  /// A change at [sequence] in some device's log.
  const new({required this.sequence, required this.change});

  /// Restores an entry from its wire form.
  ///
  /// Throws when a field is missing or malformed; the engine surfaces that
  /// as a data validation failure of the whole batch.
  factory fromJson(Map<String, Object?> json) {
    final sequence = (json['sequence']! as num).toInt();
    if (sequence < 1) {
      throw const FormatException('sequence must be positive');
    }
    return LoggedChange(
      sequence: sequence,
      change: SyncChange.fromJson((json['change']! as Map<Object?, Object?>).cast<String, Object?>()),
    );
  }

  /// The entry's position in the log of the device that holds it.
  final int sequence;

  /// The change itself.
  final SyncChange change;

  /// The wire form.
  Map<String, Object?> toJson() => <String, Object?>{'sequence': sequence, 'change': change.toJson()};

  @override
  String toString() => 'LoggedChange(#$sequence, $change)';
}
