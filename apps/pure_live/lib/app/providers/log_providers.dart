import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LogRecord;

import 'package:pure_live/app/logging/app_log.dart' show appLogChanges, appLogMemory;

/// The in-memory log ring, replayed on listen and republished when new
/// records land. One list serves the toolbox's log page and anything else
/// that needs a diagnostic snapshot.
final StreamProvider<List<LogRecord>> appLogRecordsProvider = StreamProvider<List<LogRecord>>((ref) async* {
  yield appLogMemory.records;
  await for (final _ in appLogChanges) {
    yield appLogMemory.records;
  }
});
