import 'acfun_api.dart';

class _DirectorySequence {
  final cursors = <int, String>{1: ''};
  final pending = <int, Future<AcfunDirectoryPage>>{};
  int? lastPage;
}

/// Adapts application pages to the website's opaque cursor contract. Only
/// bounded cursors are retained, never rooms, signed media or visitor tokens.
class AcfunDirectory {
  AcfunDirectory({required this._api, this.maxQueries = 12, this.maxCursors = 64}) {
    if (maxQueries < 1 || maxCursors < 2) throw ArgumentError('Invalid directory cache bounds');
  }

  final AcfunApi _api;
  final int maxQueries;
  final int maxCursors;
  final _queries = <(int, String?), _DirectorySequence>{};

  Future<AcfunDirectoryPage> page({int page = 1, int count = 30, String? filters}) {
    if (page < 1) return Future.error(const AcfunApiException(AcfunFailureKind.schema));
    final key = (count.clamp(1, 60), filters);
    var sequence = _queries.remove(key);
    // A new page-one read after the previous read completes is a refresh.
    // In-flight page-one consumers share the same request rather than stampede.
    if (page == 1 && sequence?.pending[1] == null) sequence = _DirectorySequence();
    if (sequence == null) return Future.error(const AcfunApiException(AcfunFailureKind.paginationExpired));
    _queries[key] = sequence;
    while (_queries.length > maxQueries) {
      _queries.remove(_queries.keys.first);
    }
    final existing = sequence.pending[page];
    if (existing != null) return existing;
    if (sequence.lastPage != null && page > sequence.lastPage!) {
      return Future.value(const AcfunDirectoryPage([], null));
    }
    final cursor = sequence.cursors[page];
    if (cursor == null) return Future.error(const AcfunApiException(AcfunFailureKind.paginationExpired));
    final operation = _load(key, sequence, page, cursor);
    sequence.pending[page] = operation;
    return operation;
  }

  Future<AcfunDirectoryPage> _load((int, String?) key, _DirectorySequence sequence, int page, String cursor) async {
    try {
      final result = await _api.directory(cursor: cursor, count: key.$1, filters: key.$2);
      final next = result.nextCursor;
      if (next != null && (next == cursor || sequence.cursors.entries.any((e) => e.key <= page && e.value == next))) {
        throw const AcfunApiException(AcfunFailureKind.schema);
      }
      if (identical(_queries[key], sequence)) {
        if (next == null) {
          sequence.lastPage = page;
        } else {
          sequence.cursors[page + 1] = next;
          while (sequence.cursors.length > maxCursors) {
            sequence.cursors.remove(sequence.cursors.keys.first);
          }
        }
      }
      return result;
    } finally {
      sequence.pending.remove(page);
    }
  }
}
