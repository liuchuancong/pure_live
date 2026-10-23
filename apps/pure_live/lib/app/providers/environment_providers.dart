import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind, PlatformRuntime;

/// The boot's platform snapshot; only the bootstrap can produce it, so
/// `main` overrides this and everything downstream reads it as a fact.
final platformRuntimeProvider = Provider<PlatformRuntime>(
  (ref) => throw UnimplementedError('platformRuntimeProvider must be overridden at boot'),
);

/// The OS family this process runs on, read through the boot snapshot.
final platformKindProvider = Provider<PlatformKind>(
  (ref) => ref.watch(platformRuntimeProvider).environment.runtime.kind,
);

/// Which kind of device shell the app builds.
///
/// The platform layer answers "phone / tablet / desktop / TV" once at
/// boot; this is the same answer in the app's own vocabulary, so feature
/// code never imports the platform package for a fact the shell already
/// knows.
enum DeviceProfile {
  /// A desktop window: keyboard, mouse, a caption the app draws.
  desktop,

  /// A phone: touch, a bottom bar, portrait first.
  mobile,

  /// A TV: a remote, focus travel, no pointer at all.
  tv;

  /// Translates the platform layer's form factor. A tablet is a touch
  /// device like a phone — the mobile layout's bar, not a desktop rail.
  static DeviceProfile fromFormFactor(FormFactor formFactor) => switch (formFactor) {
    FormFactor.desktop => DeviceProfile.desktop,
    FormFactor.tablet => DeviceProfile.mobile,
    FormFactor.phone => DeviceProfile.mobile,
    FormFactor.tv => DeviceProfile.tv,
  };

  /// Whether this profile owns a window with a caption.
  bool get isDesktop => this == DeviceProfile.desktop;
}

/// The device this process runs on, from the boot snapshot.
final deviceProfileProvider = Provider<DeviceProfile>(
  (ref) => DeviceProfile.fromFormFactor(ref.watch(platformRuntimeProvider).environment.runtime.formFactor),
);
