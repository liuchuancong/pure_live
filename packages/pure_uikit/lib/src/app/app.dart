/// The app-host module: `PureApp` mounts the design language's host, and
/// the host contract is what an app implements to plug one in.
///
/// The concrete hosts (`hosts/`) stay internal — the language picked at
/// startup chooses between them, and business code never instantiates one
/// directly.
library;

export 'pure_app.dart';
export 'pure_app_config.dart';
export 'pure_app_host.dart';
