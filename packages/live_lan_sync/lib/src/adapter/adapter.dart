/// The business-data contract a host implements per scope.
///
/// The engine never touches the host's databases: it exchanges generic
/// change records, and the adapter on each end translates between those and
/// the business repository (spec §12). Adapters depend on their business
/// module, never on UI, and declare which conflict policies they can honour.
library;

export 'lan_sync_data_adapter.dart';
export 'lan_sync_file_adapter.dart';
