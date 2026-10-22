/// The app-host module: `PureApp` mounts the Fluent host, and the host
/// contract is what an app implements to plug one in.
///
/// The concrete host (`hosts/`) stays internal — every design language falls
/// back to it, and business code never instantiates one directly.
library;

export 'pure_app.dart';
export 'pure_app_config.dart';
export 'pure_app_host.dart';
