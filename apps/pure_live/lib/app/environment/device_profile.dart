import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;

import 'package:pure_live/app/environment/app_environment.dart' show platformRuntimeProvider;

/// Which kind of device the shell should build for.
///
/// The platform layer answers "phone / tablet / desktop / TV" once at boot;
/// this is the same answer in the app's own vocabulary, so feature code
/// never imports the platform package for a fact the shell already knows.
enum DeviceProfile {
  /// A desktop window: keyboard, mouse, a caption the app may draw.
  desktop,

  /// A phone: touch, a bottom bar, portrait first.
  mobile,

  /// A tablet: touch with room for a rail.
  tablet,

  /// A TV: a remote, focus travel, no pointer at all.
  tv;

  /// Translates the platform layer's form factor.
  static DeviceProfile fromFormFactor(FormFactor formFactor) => switch (formFactor) {
    FormFactor.desktop => DeviceProfile.desktop,
    FormFactor.phone => DeviceProfile.mobile,
    FormFactor.tablet => DeviceProfile.tablet,
    FormFactor.tv => DeviceProfile.tv,
  };

  /// Whether this profile owns a window with a caption.
  bool get isDesktop => this == DeviceProfile.desktop;
}

/// The device this process runs on, from the boot snapshot.
final deviceProfileProvider = Provider<DeviceProfile>(
  (ref) => DeviceProfile.fromFormFactor(ref.watch(platformRuntimeProvider).environment.runtime.formFactor),
);
