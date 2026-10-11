/// Cross-platform runtime and system-capability layer for Pure Live.
///
/// Business modules never test platforms, splice system paths or assume
/// write access: run `PlatformBootstrap.init` once, then read facts from
/// `PlatformEnvironment` and resolve directories through `StorageManager`.
/// Storage areas carry their own persistence and fallback rules
/// (`StorageArea`), file picking goes through `FileAccessService`, and
/// shutdown is coordinated by `ShutdownCoordinator`.
library;

export 'src/bootstrap/platform_bootstrap.dart';
export 'src/contracts/file_access_service.dart';
export 'src/contracts/platform_environment.dart';
export 'src/contracts/platform_exception.dart';
export 'src/contracts/storage_area.dart';
export 'src/contracts/storage_location.dart';
export 'src/contracts/storage_manager.dart';
export 'src/diagnostics/storage_diagnostics.dart';
export 'src/lifecycle/shutdown_coordinator.dart';
export 'src/runtime/desktop_distribution.dart';
export 'src/runtime/distribution_detector.dart';
export 'src/runtime/form_factor.dart';
export 'src/runtime/platform_capabilities.dart';
export 'src/runtime/platform_kind.dart';
export 'src/runtime/platform_runtime_info.dart';
export 'src/storage/atomic_file_writer.dart';
export 'src/storage/default_storage_manager.dart';
export 'src/storage/storage_policy.dart';
