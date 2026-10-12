/// Keeping a library current: what may be refreshed, and the round that does.
///
/// One public unit per folder, as in `src/model/`: the policy the application's
/// settings produce (`iptv_sync_policy/`) and the coordinator that runs a round
/// (`iptv_sync_coordinator/`, with its report beside it).
///
/// Deliberately absent: a timer. Deciding *when* to refresh belongs to the
/// app's lifecycle — start-up, returning to the foreground, a pull on a screen
/// — and a package that started its own timer would download playlists behind
/// a window that never showed them.
library;

export 'iptv_sync_coordinator/iptv_sync_coordinator.dart';
export 'iptv_sync_policy/iptv_sync_policy.dart';
