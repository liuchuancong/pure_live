import 'dart:io';

import 'package:live_platform/src/runtime/distribution/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution/distribution_resolution.dart';
import 'package:live_platform/src/runtime/facts/form_factor.dart';
import 'package:live_platform/src/runtime/facts/platform_kind.dart';

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
    required this.appNamespace,
    this.osVersion,
    this.distributionOrigin = DistributionOrigin.undetermined,
    this.distributionConflicts = const [],
  });

  /// The namespace this application writes under — the single fact the
  /// storage, log and registration layers borrow instead of carrying their
  /// own copy of a product name. A reusable package must never hardcode
  /// it; the shell declares it once here and every reader takes it from
  /// the snapshot.
  final String appNamespace;

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

  /// Which trust tier produced [distribution] — diagnostics, not policy.
  final DistributionOrigin distributionOrigin;

  /// Lower-trust evidence that disagreed with [distribution], for the app's
  /// diagnostics log. A packaged build claiming one thing while its markers
  /// say another shows up here, per the conflict rules.
  final List<String> distributionConflicts;

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
