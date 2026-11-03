import 'package:live_net/live_net.dart' show HttpStatusFailure, TransportFailure;

import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// One line per site, failure kind and error type for the life of the process.
final Set<String> _notedSilences = {};

/// Why a music call gave up, written to the log before the caller returns the
/// empty answer the page shows.
///
/// Every adapter here used to swallow into a bare `null`, and that made a
/// decode bug look exactly like a platform with no data: two lyric paths
/// stayed broken for several rounds without a single line on disk. The
/// `kind` field says which side failed — `platform` for a call that never got
/// a usable answer, `reader` for an answer that arrived and we could not
/// parse, which is always our bug.
///
/// The same site fires again on every keystroke of search autocomplete, so a
/// repeat is dropped after the first line: the diagnosis is in that first
/// record and its stack, while the ring and the file keep room for the rest.
void noteMusicSourceSilence(String where, Object error, StackTrace stackTrace) {
  final kind = switch (error) {
    HttpStatusFailure() || TransportFailure() => 'platform',
    _ => 'reader',
  };
  if (!_notedSilences.add('$where|$kind|${error.runtimeType}')) return;
  appLog.error(
    'music source $where silenced a $kind failure',
    fields: {'where': where, 'kind': kind},
    error: error,
    stackTrace: stackTrace,
  );
}
