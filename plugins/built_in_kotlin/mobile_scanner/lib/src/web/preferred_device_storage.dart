import 'package:web/web.dart';

/// Persists and retrieves the preferred camera device ID using localStorage.
class PreferredDeviceStorage {
  /// Construct a [PreferredDeviceStorage] instance.
  const PreferredDeviceStorage();

  static const String _kKey = 'mobile_scanner_preferred_device_id';

  /// Returns the stored device ID, or null if absent or storage is unavailable.
  String? read() {
    try {
      return window.localStorage.getItem(_kKey);
    } on Object catch (_) {
      return null;
    }
  }

  /// Persists [deviceId] for use on the next start.
  void write(String deviceId) {
    try {
      window.localStorage.setItem(_kKey, deviceId);
    } on Object catch (_) {
      // Ignore, e.g. Safari private browsing mode disables storage.
    }
  }

  /// Removes the stored device ID.
  void remove() {
    try {
      window.localStorage.removeItem(_kKey);
    } on Object catch (_) {
      // Ignore, e.g. Safari private browsing mode disables storage.
    }
  }
}
