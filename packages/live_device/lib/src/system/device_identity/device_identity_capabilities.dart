import 'package:live_device/src/system/device_identity/device_identity.dart';

/// Device-identity API support reported for the current runtime platform.
///
/// These flags describe what the platform information class can fill, not what
/// a particular device or browser build chooses to report. A value a platform
/// supports may still be absent at runtime when the native side returns no
/// measurement, in which case the corresponding [DeviceIdentity] field is null.
final class DeviceIdentityCapabilities {
  /// Creates an immutable capability description.
  const new({
    required this.canReadIdentity,
    required this.reportsPhysicalDevice,
    required this.reportsMemory,
    required this.reportsLogicalProcessorCount,
    required this.platformName,
  });

  /// Whether the platform exposes any device-identity information at all.
  ///
  /// False only on platforms with no backing information class; a true value
  /// still means that most individual fields may be null.
  final bool canReadIdentity;

  /// Whether the platform distinguishes real hardware from an emulator.
  ///
  /// Android and iOS only, so [DeviceIdentity.isPhysicalDevice] stays null
  /// elsewhere.
  final bool reportsPhysicalDevice;

  /// Whether the platform reports a physical-memory size.
  ///
  /// True on Android, iOS, macOS, Windows and in supporting browsers; the Linux
  /// information class reads only `os-release`, which has no memory field.
  final bool reportsMemory;

  /// Whether the platform reports a logical-processor (hardware-thread) count.
  ///
  /// True on macOS, Windows and in the browser, and each of those sources counts
  /// logical processors rather than physical cores. Android and iOS information
  /// classes publish no processor count, and reading `/proc/cpuinfo` is not part
  /// of the Linux data the plugin returns, so those runtimes leave
  /// [DeviceIdentity.logicalProcessorCount] null.
  final bool reportsLogicalProcessorCount;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}
