import 'dart:math' show Random;

import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;

/// The local device's stable identity (spec §6.2).
///
/// The id is randomly generated once and persisted forever — never derived
/// from an IP, MAC address or hardware serial, which change or leak. Every
/// subsystem reads the same id through [ensure].
abstract final class LocalDeviceIdentity {
  /// Returns the persisted device id, generating and saving one on the
  /// first boot. Idempotent: concurrent and repeated calls agree.
  static Future<String> ensure(LanSyncStore store, {Random? random}) async {
    final existing = await store.loadLocalDeviceId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = generate(random ?? Random.secure());
    await store.saveLocalDeviceId(id);
    return id;
  }

  /// Generates a new id: 16 random bytes as a dashed hex string.
  static String generate(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
