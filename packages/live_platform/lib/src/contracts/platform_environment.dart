import 'package:live_platform/src/runtime/facts/platform_capabilities.dart';
import 'package:live_platform/src/runtime/facts/platform_runtime_info.dart';

/// Answers "what am I running on and what can it do".
///
/// One object, built once at bootstrap; business modules read it instead
/// of poking at `Platform.isWindows` themselves.
abstract interface class PlatformEnvironment {
  /// The immutable runtime snapshot.
  PlatformRuntimeInfo get runtime;

  /// The resolved capability set.
  PlatformCapabilities get capabilities;
}
