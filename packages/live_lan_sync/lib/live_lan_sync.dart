/// LAN device discovery and data synchronization engine.
///
/// `live_lan_sync` solves one question: how two devices on the same network
/// find each other, trust each other, and exchange generic data and files
/// safely and reliably. It does not decide what a host application syncs —
/// the host owns that through its `LanSyncDataAdapter`s, its `LanSyncStore`
/// and its own `LanSyncConfig`.
///
/// The public surface is intentionally small: configuration types, the
/// stable domain models (devices, changes, cursors, tasks, version
/// vectors), the adapter, discovery and store contracts, and the error
/// model. The Bonsoir discovery adapter, the HTTP transport and the sync
/// engine internals live under `src/` and are not part of the contract.
///
/// The design baseline is `docs/live-lan-sync-spec.md` in the PureLive
/// workspace.
library;

export 'src/adapter/adapter.dart';
export 'src/config/config.dart';
export 'src/discovery/discovery.dart';
export 'src/domain/domain.dart';
export 'src/logging/logging.dart';
export 'src/pairing/pairing.dart';
export 'src/security/security.dart';
export 'src/store/store.dart';
export 'src/sync/sync.dart';
export 'src/transfer/transfer.dart';
export 'src/transport/transport.dart';
