import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/form_factor.dart';
import 'package:live_platform/src/runtime/platform_kind.dart';

/// An immutable snapshot of the runtime environment, produced once at
/// bootstrap and never mutated afterwards.
///
/// Every fact is either detected or explicitly declared by the app shell —
/// nothing in here re-probes the system on read.
final class PlatformRuntimeInfo {
  /// A snapshot carrying all runtime facts.
  const new({
    required this.kind,
    required this.formFactor,
    required this.distribution,
    required this.isPackaged,
    required this.executableRoot,
    this.osVersion,
  });

  /// The operating system family.
  final PlatformKind kind;

  /// The device's presentation form factor (phone / tablet / desktop / TV).
  final FormFactor formFactor;

  /// How the desktop application was deployed; [DesktopDistribution.unknown]
  /// when unconfirmed.
  final DesktopDistribution distribution;

  /// Whether the app runs as an OS-managed package (MSIX, store build);
  /// package identity and container rules then apply.
  final bool isPackaged;

  /// The directory holding the running executable. Portable layouts put
  /// their data tree next to it; installed layouts must not write there.
  final Directory executableRoot;

  /// Human-readable OS version, when the platform reported one.
  final String? osVersion;

  /// Shorthand for the portable distribution decision.
  bool get isPortable => distribution == DesktopDistribution.portable;

  /// Infers the OS family from dart:io; overridable at bootstrap.
  static PlatformKind inferKind() => switch (Platform.operatingSystem) {
    'windows' => PlatformKind.windows,
    'android' => PlatformKind.android,
    'ios' => PlatformKind.ios,
    'macos' => PlatformKind.macos,
    'linux' => PlatformKind.linux,
    _ => PlatformKind.unknown,
  };
}
