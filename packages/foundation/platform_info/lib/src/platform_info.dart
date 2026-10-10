// Module: lib/src/platform_info.dart
// Purpose: The platform vocabulary and the capability matrix the rest of the app branches on.
// Author: liuchuancong
// Created: 2026-10-08
//
// Reading TargetPlatform or a plugin is Flutter-side, so this package takes plain inputs and answers
// questions. That keeps the matrix testable and stops a widget tree from growing platform checks of its
// own: ask capabilitiesFor(kind) once and pass the answer down.

/// Which operating environment the app is running in.
///
/// [unknown] is a real case and not a placeholder: this enum is the input every capability branch reads, so
/// an unrecognised operating system has to answer "I do not know" rather than borrow another target's
/// answers. It used to borrow [PlatformKind.web], which was described as "the most restricted target" and is
/// not - web can enter picture-in-picture and reports itself touch-first, so a fuchsia or a rebranded
/// Android fork inherited two optimistic assumptions while being told it had no secure storage.
enum PlatformKind { android, androidTv, ios, iOSTv, macOS, windows, linux, web, unknown }

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

  /// Everything switched on in this row, as a set - the form a capability check or a report wants.
  Set<PlatformCapability> get enabled {
    return <PlatformCapability>{
      if (hasSecureStorage) PlatformCapability.secureStorage,
      if (supportsBackgroundPlayback) PlatformCapability.backgroundPlayback,
      if (supportsPictureInPicture) PlatformCapability.pictureInPicture,
      if (supportsFileSystemAccess) PlatformCapability.fileSystemAccess,
      if (supportsMultiWindow) PlatformCapability.multiWindow,
      if (supportsRemoteControl) PlatformCapability.remoteControl,
      if (isTouchPrimary) PlatformCapability.touchPrimary,
      if (isTelevision) PlatformCapability.television,
    };
  }

  bool supports(PlatformCapability capability) => enabled.contains(capability);

  /// A copy with one flag changed, so a derived row does not restate all eight.
  PlatformCapabilities copyWith({
    bool? hasSecureStorage,
    bool? supportsBackgroundPlayback,
    bool? supportsPictureInPicture,
    bool? supportsFileSystemAccess,
    bool? supportsMultiWindow,
    bool? supportsRemoteControl,
    bool? isTouchPrimary,
    bool? isTelevision,
  }) {
    return PlatformCapabilities(
      hasSecureStorage: hasSecureStorage ?? this.hasSecureStorage,
      supportsBackgroundPlayback: supportsBackgroundPlayback ?? this.supportsBackgroundPlayback,
      supportsPictureInPicture: supportsPictureInPicture ?? this.supportsPictureInPicture,
      supportsFileSystemAccess: supportsFileSystemAccess ?? this.supportsFileSystemAccess,
      supportsMultiWindow: supportsMultiWindow ?? this.supportsMultiWindow,
      supportsRemoteControl: supportsRemoteControl ?? this.supportsRemoteControl,
      isTouchPrimary: isTouchPrimary ?? this.isTouchPrimary,
      isTelevision: isTelevision ?? this.isTelevision,
    );
  }

  /// What both rows allow. An intersection is how a feature is offered on a device that has to satisfy two
  /// targets at once - a browser on a phone, a TV box that also runs a desktop build.
  PlatformCapabilities restrict(PlatformCapabilities other) {
    return PlatformCapabilities(
      hasSecureStorage: hasSecureStorage && other.hasSecureStorage,
      supportsBackgroundPlayback: supportsBackgroundPlayback && other.supportsBackgroundPlayback,
      supportsPictureInPicture: supportsPictureInPicture && other.supportsPictureInPicture,
      supportsFileSystemAccess: supportsFileSystemAccess && other.supportsFileSystemAccess,
      supportsMultiWindow: supportsMultiWindow && other.supportsMultiWindow,
      supportsRemoteControl: supportsRemoteControl && other.supportsRemoteControl,
      isTouchPrimary: isTouchPrimary && other.isTouchPrimary,
      isTelevision: isTelevision && other.isTelevision,
    );
  }

  /// The same row minus [capability], the shape an override or a kill switch needs.
  PlatformCapabilities without(PlatformCapability capability) {
    return switch (capability) {
      PlatformCapability.secureStorage => copyWith(hasSecureStorage: false),
      PlatformCapability.backgroundPlayback => copyWith(supportsBackgroundPlayback: false),
      PlatformCapability.pictureInPicture => copyWith(supportsPictureInPicture: false),
      PlatformCapability.fileSystemAccess => copyWith(supportsFileSystemAccess: false),
      PlatformCapability.multiWindow => copyWith(supportsMultiWindow: false),
      PlatformCapability.remoteControl => copyWith(supportsRemoteControl: false),
      PlatformCapability.touchPrimary => copyWith(isTouchPrimary: false),
      PlatformCapability.television => copyWith(isTelevision: false),
    };
  }

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

  /// Nothing is assumed. This is the floor an unrecognised target falls back to, and every flag is off
  /// because a capability nobody verified is worse than a feature nobody offered: on the optimistic reading
  /// the app hides its own controls, on the pessimistic one it shows a button that does nothing.
  static const PlatformCapabilities unknown = PlatformCapabilities(
    hasSecureStorage: false,
    supportsBackgroundPlayback: false,
    supportsPictureInPicture: false,
    supportsFileSystemAccess: false,
    supportsMultiWindow: false,
    supportsRemoteControl: false,
    isTouchPrimary: false,
    isTelevision: false,
  );

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

  /// A capability row is a value: a widget that rebuilds on `!=` needs two identical rows to compare equal,
  /// otherwise every derived row is "new" and the subtree rebuilds forever.
  @override
  bool operator ==(Object other) {
    return other is PlatformCapabilities &&
        other.hasSecureStorage == hasSecureStorage &&
        other.supportsBackgroundPlayback == supportsBackgroundPlayback &&
        other.supportsPictureInPicture == supportsPictureInPicture &&
        other.supportsFileSystemAccess == supportsFileSystemAccess &&
        other.supportsMultiWindow == supportsMultiWindow &&
        other.supportsRemoteControl == supportsRemoteControl &&
        other.isTouchPrimary == isTouchPrimary &&
        other.isTelevision == isTelevision;
  }

  @override
  int get hashCode => Object.hash(
    hasSecureStorage,
    supportsBackgroundPlayback,
    supportsPictureInPicture,
    supportsFileSystemAccess,
    supportsMultiWindow,
    supportsRemoteControl,
    isTouchPrimary,
    isTelevision,
  );

  @override
  String toString() => 'PlatformCapabilities(${enabled.map((cap) => cap.name).join(', ')})';
}

/// The eight switches, as an enum, for code that passes "which capability" around rather than reading one.
enum PlatformCapability {
  secureStorage,
  backgroundPlayback,
  pictureInPicture,
  fileSystemAccess,
  multiWindow,
  remoteControl,
  touchPrimary,
  television,
}

/// Resolves a platform kind from the raw signals the app collects at startup.
///
/// [os] is the lowercase operating system name from Platform.operatingSystem; `android` plus
/// [isTelevisionDevice] is Android TV, which is a different product in every other respect.
PlatformKind detectPlatform({required String os, bool isTelevisionDevice = false, bool isWeb = false}) {
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
      // Not web: an unknown target must not inherit a browser's assumptions, see [PlatformKind.unknown].
      return PlatformKind.unknown;
  }
}

/// The capability matrix for [kind].
///
/// [webIsTouchPrimary] exists because "web" says nothing about how the person is pointing: a browser on a
/// phone and a browser on a desktop are the same [PlatformKind] with opposite layout rules. The host knows
/// which one it is from MediaQuery, and passing it here keeps one table instead of letting each surface
/// re-decide what a browser is.
PlatformCapabilities capabilitiesFor(PlatformKind kind, {bool? webIsTouchPrimary}) {
  if (kind == PlatformKind.web && webIsTouchPrimary != null) {
    return PlatformCapabilities.web.copyWith(isTouchPrimary: webIsTouchPrimary);
  }
  return switch (kind) {
    PlatformKind.unknown => PlatformCapabilities.unknown,
    PlatformKind.web => PlatformCapabilities.web,
    PlatformKind.android => PlatformCapabilities.android,
    PlatformKind.androidTv => PlatformCapabilities.androidTv,
    PlatformKind.ios => PlatformCapabilities.ios,
    PlatformKind.iOSTv => PlatformCapabilities.iosTv,
    PlatformKind.macOS || PlatformKind.windows || PlatformKind.linux => PlatformCapabilities.desktop,
  };
}
