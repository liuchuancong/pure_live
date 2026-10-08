// Module: lib/src/platform_info.dart
// Purpose: The platform vocabulary and the capability matrix the rest of the app branches on.
// Author: liuchuancong
// Created: 2026-10-08
//
// Reading TargetPlatform or a plugin is Flutter-side, so this package takes plain inputs and answers
// questions. That keeps the matrix testable and stops a widget tree from growing platform checks of its
// own: ask capabilitiesFor(kind) once and pass the answer down.

/// Which operating environment the app is running in.
enum PlatformKind { android, androidTv, ios, iOSTv, macOS, windows, linux, web }

/// What the platform can be asked to do. Defaults live in one table so a new target cannot silently
/// inherit an optimistic assumption.
final class PlatformCapabilities {
  const PlatformCapabilities({
    required this.hasSecureStorage,
    required this.supportsBackgroundPlayback,
    required this.supportsPictureInPicture,
    required this.supportsFileSystemAccess,
    required this.supportsMultiWindow,
    required this.supportsRemoteControl,
    required this.isTouchPrimary,
    required this.isTelevision,
  });

  final bool hasSecureStorage;

  /// Whether audio may keep playing with the UI hidden.
  final bool supportsBackgroundPlayback;
  final bool supportsPictureInPicture;

  /// Whether the app may read and write arbitrary user files, not just its own directories.
  final bool supportsFileSystemAccess;
  final bool supportsMultiWindow;

  /// Whether a LAN remote-control endpoint makes sense on this device.
  final bool supportsRemoteControl;
  final bool isTouchPrimary;
  final bool isTelevision;

  /// A web target: no secure enclave, no background playback, no raw file system.
  static const PlatformCapabilities web = PlatformCapabilities(
    hasSecureStorage: false,
    supportsBackgroundPlayback: false,
    supportsPictureInPicture: true,
    supportsFileSystemAccess: false,
    supportsMultiWindow: false,
    supportsRemoteControl: false,
    isTouchPrimary: true,
    isTelevision: false,
  );

  static const PlatformCapabilities android = PlatformCapabilities(
    hasSecureStorage: true,
    supportsBackgroundPlayback: true,
    supportsPictureInPicture: true,
    supportsFileSystemAccess: true,
    supportsMultiWindow: true,
    supportsRemoteControl: true,
    isTouchPrimary: true,
    isTelevision: false,
  );

  static const PlatformCapabilities androidTv = PlatformCapabilities(
    hasSecureStorage: true,
    supportsBackgroundPlayback: true,
    supportsPictureInPicture: false,
    supportsFileSystemAccess: false,
    supportsMultiWindow: false,
    supportsRemoteControl: true,
    isTouchPrimary: false,
    isTelevision: true,
  );

  static const PlatformCapabilities ios = PlatformCapabilities(
    hasSecureStorage: true,
    supportsBackgroundPlayback: true,
    supportsPictureInPicture: true,
    supportsFileSystemAccess: false,
    supportsMultiWindow: false,
    supportsRemoteControl: true,
    isTouchPrimary: true,
    isTelevision: false,
  );

  static const PlatformCapabilities iosTv = PlatformCapabilities(
    hasSecureStorage: true,
    supportsBackgroundPlayback: false,
    supportsPictureInPicture: false,
    supportsFileSystemAccess: false,
    supportsMultiWindow: false,
    supportsRemoteControl: false,
    isTouchPrimary: false,
    isTelevision: true,
  );

  static const PlatformCapabilities desktop = PlatformCapabilities(
    hasSecureStorage: true,
    supportsBackgroundPlayback: true,
    supportsPictureInPicture: true,
    supportsFileSystemAccess: true,
    supportsMultiWindow: true,
    supportsRemoteControl: true,
    isTouchPrimary: false,
    isTelevision: false,
  );
}

/// Resolves a platform kind from the raw signals the app collects at startup.
///
/// [os] is the lowercase operating system name from Platform.operatingSystem; `android` plus
/// [isTelevisionDevice] is Android TV, which is a different product in every other respect.
PlatformKind detectPlatform({
  required String os,
  bool isTelevisionDevice = false,
  bool isWeb = false,
}) {
  if (isWeb) {
    return PlatformKind.web;
  }
  switch (os.toLowerCase()) {
    case 'android':
      return isTelevisionDevice ? PlatformKind.androidTv : PlatformKind.android;
    case 'ios':
      return isTelevisionDevice ? PlatformKind.iOSTv : PlatformKind.ios;
    case 'macos':
      return PlatformKind.macOS;
    case 'windows':
      return PlatformKind.windows;
    case 'linux':
      return PlatformKind.linux;
    default:
      return PlatformKind.web;
  }
}

/// The capability matrix for [kind].
PlatformCapabilities capabilitiesFor(PlatformKind kind) {
  return switch (kind) {
    PlatformKind.web => PlatformCapabilities.web,
    PlatformKind.android => PlatformCapabilities.android,
    PlatformKind.androidTv => PlatformCapabilities.androidTv,
    PlatformKind.ios => PlatformCapabilities.ios,
    PlatformKind.iOSTv => PlatformCapabilities.iosTv,
    PlatformKind.macOS || PlatformKind.windows || PlatformKind.linux => PlatformCapabilities.desktop,
  };
}
