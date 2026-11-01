/// Log behaviour.
///
/// Logs travel further than the engineer writing them expects: pairing
/// codes, tokens, signatures, key material and business payloads must never
/// reach them (spec §18, §20). `redactSecrets` and `logPayloads` encode that
/// as configuration the engine reads, and validation refuses the unsafe
/// combination. Where records go is the host's business: it hands a view of
/// its own live_log tree to a `LanSyncLogger`.
library;

import 'package:live_log/live_log.dart' show LogLevel;

/// What the engine logs and how carefully.
final class LanSyncLoggingConfig {
  /// The logging defaults.
  const new({this.level = LogLevel.info, this.redactSecrets = true, this.logPayloads = false});

  /// The least severe level the engine builds records at, on top of the
  /// host view's own tree filter.
  final LogLevel level;

  /// Whether secrets (pairing codes, tokens, key material) are masked. This
  /// must stay enabled; validation refuses to turn it off.
  final bool redactSecrets;

  /// Whether change payloads may appear in debug records. Off by default:
  /// payloads are business data the engine does not own.
  final bool logPayloads;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (!redactSecrets) {
      problems.add('logging.redactSecrets must stay enabled');
    }
    if (logPayloads && !redactSecrets) {
      problems.add('logging.logPayloads requires redactSecrets');
    }
    return problems;
  }
}
