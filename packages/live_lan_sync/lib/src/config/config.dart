/// The configuration system: one aggregate plus one file per area.
///
/// Every value a host may want to tune lives here with a documented default;
/// nothing the spec lists as configurable is hard-coded in the engine.
/// Configuration validates as a whole — `LanSyncConfig.validate` collects
/// every problem so a host fixes them in one pass, and a failed validation
/// must never be applied partially.
library;

export 'device_config.dart';
export 'discovery_config.dart';
export 'lan_sync_config.dart';
export 'logging_config.dart';
export 'security_config.dart';
export 'server_config.dart';
export 'synchronization_config.dart';
export 'transfer_config.dart';
