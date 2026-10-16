import 'package:device_info_plus/device_info_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_device/src/system/device_identity/device_identity.dart';
import 'package:live_device/src/system/device_identity/device_identity_capabilities.dart';
import 'package:live_device/src/system/device_identity/device_identity_exception.dart';
import 'package:live_device/src/system/device_identity/device_identity_memory.dart';
import 'package:live_device/src/system/device_identity/device_identity_service.dart';

/// Default [DeviceIdentityService] implementation backed by `device_info_plus`.
///
/// The plugin's per-platform information classes, its error types and its unit
/// differences all stop at this file; application and feature packages should
/// depend on [DeviceIdentityService] and read [DeviceIdentity] instead.
///
/// Reads branch on [kIsWeb] and [defaultTargetPlatform] rather than on the
/// `dart:io` `Platform` class, so the service keeps working where `Platform` is
/// unavailable and stays testable by overriding the target platform. Only the
/// getter belonging to the active platform is touched: reading another platform's
/// getter reaches a channel that cannot answer and fails with a plugin exception.
final class PlatformDeviceIdentityService implements DeviceIdentityService {
  /// Creates a service that reads through the plugin's default implementation.
  const new();

  /// Stable code for "this runtime has no identity backend".
  static const String _unsupportedCode = 'unsupported_on_platform';

  /// Instantiating the plugin does no work, so a fresh object per read is safe
  /// and keeps this service const-constructible.
  plugin.DeviceInfoPlugin get _plugin => plugin.DeviceInfoPlugin();

  @override
  Future<DeviceIdentity> read() {
    if (kIsWeb) {
      return _guard(() async => _fromWeb(await _plugin.webBrowserInfo));
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _guard(() async => _fromAndroid(await _plugin.androidInfo)),
      TargetPlatform.iOS => _guard(() async => _fromIos(await _plugin.iosInfo)),
      TargetPlatform.linux => _guard(() async => _fromLinux(await _plugin.linuxInfo)),
      TargetPlatform.macOS => _guard(() async => _fromMacOs(await _plugin.macOsInfo)),
      TargetPlatform.windows => _guard(() async => _fromWindows(await _plugin.windowsInfo)),
      TargetPlatform.fuchsia => Future<DeviceIdentity>.error(_noBackend(_platformName())),
    };
  }

  @override
  Future<DeviceIdentityCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const DeviceIdentityCapabilities(
        canReadIdentity: true,
        reportsPhysicalDevice: false,
        reportsMemory: true,
        reportsLogicalProcessorCount: true,
        platformName: 'web',
      );
    }

    final platform = defaultTargetPlatform;
    final canReadIdentity = switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia => false,
    };
    final reportsPhysicalDevice = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.fuchsia => false,
    };
    final reportsMemory = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
    final reportsLogicalProcessorCount = switch (platform) {
      TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };

    return DeviceIdentityCapabilities(
      canReadIdentity: canReadIdentity,
      reportsPhysicalDevice: reportsPhysicalDevice,
      reportsMemory: reportsMemory,
      reportsLogicalProcessorCount: reportsLogicalProcessorCount,
      platformName: platform.name,
    );
  }

  /// Android reports the manufacturer and a user-set device name; its version is
  /// a single release string, so no numeric components are filled. The physical
  /// memory already crosses the channel in megabytes.
  DeviceIdentity _fromAndroid(plugin.AndroidDeviceInfo info) => DeviceIdentity(
    model: _text(info.model),
    manufacturer: _text(info.manufacturer),
    marketingName: _text(info.name),
    systemName: 'Android',
    systemVersion: _text(info.version.release),
    memoryMegabytes: positiveMegabytes(info.physicalRamSize),
    isPhysicalDevice: info.isPhysicalDevice,
    platformName: _platformName(),
  );

  /// iOS reports the commercial model name rather than the coarse `model`
  /// identifier, and the device name the owner chose. `utsname` and the physical
  /// disk sizes describe the same machine from a second angle and stay unread.
  DeviceIdentity _fromIos(plugin.IosDeviceInfo info) => DeviceIdentity(
    model: _text(info.modelName),
    marketingName: _text(info.name),
    systemName: _text(info.systemName),
    systemVersion: _text(info.systemVersion),
    memoryMegabytes: positiveMegabytes(info.physicalRamSize),
    isPhysicalDevice: info.isPhysicalDevice,
    platformName: _platformName(),
  );

  /// Windows has no hardware model in its information class, so the product name
  /// stands in; `computerName` is the machine label the user sees. The version
  /// exists only as separate numbers and is joined for [DeviceIdentity.systemVersion].
  ///
  /// The plugin computes Windows data synchronously, but its public `windowsInfo`
  /// getter still hands back a `Future`, so this read is awaited like the others.
  DeviceIdentity _fromWindows(plugin.WindowsDeviceInfo info) => DeviceIdentity(
    model: _text(info.productName),
    hostname: _text(info.computerName),
    systemName: 'Windows',
    systemVersion: _windowsVersion(info),
    majorVersion: _versionComponent(info.majorVersion),
    minorVersion: _versionComponent(info.minorVersion),
    logicalProcessorCount: _count(info.numberOfCores),
    memoryMegabytes: positiveMegabytes(info.systemMemoryInMegabytes),
    platformName: _platformName(),
  );

  /// macOS reports a hardware identifier plus a marketing model name. The
  /// product version is joined so the string and the numeric components describe
  /// the same numbering space; the Darwin `osRelease` and `kernelVersion` are
  /// deliberately not surfaced.
  DeviceIdentity _fromMacOs(plugin.MacOsDeviceInfo info) => DeviceIdentity(
    model: _text(info.model),
    marketingName: _text(info.modelName),
    hostname: _text(info.hostName),
    systemName: 'macOS',
    systemVersion: _macOsVersion(info),
    majorVersion: _versionComponent(info.majorVersion),
    minorVersion: _versionComponent(info.minorVersion),
    logicalProcessorCount: _count(info.activeCPUs),
    memoryMegabytes: megabytesFromBytes(info.memorySize),
    platformName: _platformName(),
  );

  /// Linux exposes `os-release` only: no hardware model, no memory, no logical
  /// processor count, and the single machine identifier it offers is a persistent
  /// id that this package never reads.
  DeviceIdentity _fromLinux(plugin.LinuxDeviceInfo info) => DeviceIdentity(
    systemName: _text(info.name) ?? 'Linux',
    systemVersion: _text(info.version) ?? _text(info.versionId),
    platformName: _platformName(),
  );

  /// In a browser the only safe identity is the coarse machine budget. The
  /// user-agent, `platform` and `vendor` strings stay unread: they fingerprint the
  /// browser build rather than describe a device.
  DeviceIdentity _fromWeb(plugin.WebBrowserInfo info) => DeviceIdentity(
    systemName: _text(info.browserName.name),
    logicalProcessorCount: _count(info.hardwareConcurrency),
    memoryMegabytes: megabytesFromGibibytes(info.deviceMemory),
    platformName: _platformName(),
  );

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DeviceIdentityException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalize(error), stackTrace);
    }
  }

  /// Native answers that all mean "no identity backend here" share the
  /// `unsupported_on_platform` code: a build without the plugin reports
  /// `MissingPluginException`, a channel that refuses the call reports
  /// [PlatformException], and an unregistered implementation reports
  /// [UnimplementedError]. Anything else is a real read failure.
  static DeviceIdentityException _normalize(Object error) {
    final platform = _platformName();
    return switch (error) {
      MissingPluginException() => _noBackend(platform),
      PlatformException(:final code, :final message) => DeviceIdentityException(
        code: _unsupportedCode,
        message: 'The $platform identity channel refused the read: ${message ?? code}.',
        details: <String, Object?>{'platform': platform, 'platformCode': code},
        cause: error,
      ),
      UnimplementedError() => _noBackend(platform),
      _ => DeviceIdentityException(
        code: 'read_identity_failed',
        message: 'Could not read the device identity on $platform.',
        details: <String, Object?>{'platform': platform, 'errorType': error.runtimeType.toString()},
        cause: error,
      ),
    };
  }

  static DeviceIdentityException _noBackend(String platform) => DeviceIdentityException(
    code: _unsupportedCode,
    message: 'The $platform runtime does not expose device identity information.',
    details: <String, Object?>{'platform': platform},
  );

  /// A browser reports the host operating system as the target platform, so
  /// [kIsWeb] has to win before [defaultTargetPlatform] is consulted.
  static String _platformName() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  static String _windowsVersion(plugin.WindowsDeviceInfo info) =>
      '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';

  static String _macOsVersion(plugin.MacOsDeviceInfo info) {
    final base = '${info.majorVersion}.${info.minorVersion}';
    final patch = info.patchVersion;
    return patch > 0 ? '$base.$patch' : base;
  }

  /// Empty strings are how several platform builds spell "not available", and
  /// callers should not have to distinguish them from a missing value.
  static String? _text(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Keeps a count only when the platform reported one; the information classes
  /// use `-1` and `0` for unknown.
  static int? _count(int? value) => value == null || value <= 0 ? null : value;

  /// Keeps a version component, dropping only the negative unknown sentinel.
  /// Zero is a real minor version on Windows 10 and 11.
  static int? _versionComponent(int? value) => value == null || value < 0 ? null : value;
}
