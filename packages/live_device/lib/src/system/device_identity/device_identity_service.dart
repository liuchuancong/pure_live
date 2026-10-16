import 'package:live_device/src/system/device_identity/device_identity.dart';
import 'package:live_device/src/system/device_identity/device_identity_capabilities.dart';
import 'package:live_device/src/system/device_identity/device_identity_exception.dart';

/// Reads device and operating-system identity for diagnostics.
///
/// The result is a single [DeviceIdentity] snapshot: nothing here streams,
/// caches or observes, because identity does not change during a session. Call
/// it once when a support report or analytics envelope is built rather than on
/// every frame.
///
/// Depend on this contract in feature code so the identity plugin can be
/// replaced without changing those callers.
abstract interface class DeviceIdentityService {
  /// Reads the identity of the current device and operating system.
  ///
  /// Fields the platform does not report stay null; see [DeviceIdentity] for
  /// which platform fills which field. A platform with no identity backend — or
  /// a native side that answers `notImplemented` — fails with a
  /// [DeviceIdentityException] whose `code` is `unsupported_on_platform`, so
  /// callers can treat that case as normal absence and log the rest.
  Future<DeviceIdentity> read();

  /// Returns which identity fields the current runtime platform can provide.
  ///
  /// The flags describe the platform API, not the device: a browser can still
  /// hide memory, and a hardened Android build can still return an unknown
  /// memory size.
  Future<DeviceIdentityCapabilities> getCapabilities();
}
