/// The stable, business-agnostic domain models.
///
/// Everything here travels the wire or persists in the host's store, so the
/// models are plain immutable data with explicit JSON contracts. Nothing in
/// this folder knows what a "favorite" or a "playlist" is.
library;

export 'conflict/conflict.dart';
export 'device/device.dart';
export 'errors/errors.dart';
export 'events/lan_sync_event.dart';
export 'protocol/protocol.dart';
export 'sync/sync.dart';
export 'transfer/transfer.dart';
