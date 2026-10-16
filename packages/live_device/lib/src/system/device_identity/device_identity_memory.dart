// Memory-unit normalization shared by the device-identity implementation.
//
// The identity sources do not agree on units, so every value is normalized to
// whole megabytes before it reaches DeviceIdentity:
//
//   * Android and iOS hand over megabytes already; the native side divides
//     ActivityManager.MemoryInfo.totalMem and NSProcessInfo.physicalMemory by
//     1048576 before the value crosses the channel.
//   * macOS hands over the raw hw.memsize byte count.
//   * Windows hands over systemMemoryInMegabytes.
//   * The browser hands over the approximate navigator.deviceMemory value in
//     gibibytes.
//
// These helpers are package-internal. They are not exported from
// package:live_device/live_device.dart and exist so the conversion can be
// tested without a plugin channel.

const int _bytesPerMegabyte = 1024 * 1024;
const int _megabytesPerGibibyte = 1024;

/// Normalizes a platform memory reading that is already expressed in megabytes.
///
/// A platform that does not know its memory reports zero or a `-1` sentinel, so
/// neither survives as a value.
int? positiveMegabytes(int? megabytes) {
  if (megabytes == null || megabytes <= 0) {
    return null;
  }
  return megabytes;
}

/// Converts a [bytes] count, such as the macOS `hw.memsize` value, to megabytes.
///
/// Rounds up so a machine that reports any memory at all never reads as having
/// none. Null or non-positive input means the platform did not report memory.
int? megabytesFromBytes(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return null;
  }
  return (bytes + _bytesPerMegabyte - 1) ~/ _bytesPerMegabyte;
}

/// Converts the browser's approximate [gibibytes] reading to megabytes.
///
/// The browser rounds this value down to a power of two, and Safari and Firefox
/// do not expose it, so a browser reading is context rather than a fact.
int? megabytesFromGibibytes(double? gibibytes) {
  if (gibibytes == null || !gibibytes.isFinite || gibibytes <= 0) {
    return null;
  }
  return (gibibytes * _megabytesPerGibibyte).round();
}
