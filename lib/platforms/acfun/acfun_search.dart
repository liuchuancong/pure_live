import 'dart:math';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';

import 'acfun_api.dart';

typedef AcfunSearchRequest = Future<String> Function(Uri uri, CancelToken cancel);

class AcfunSearchPage {
  const AcfunSearchPage({required this.rooms, required this.total});
  final List<LiveRoom> rooms;
  final int total;
}

class _SearchSequence {
  List<LiveRoom> remaining = [];
  int nextApplicationPage = 1;
  int nextServerPage = 1;
  bool finished = false;
  Future<List<LiveRoom>>? inFlight;
  int? inFlightPage;
  CancelToken? cancel;
}

/// The official anonymous author search returns BigPipe JSON+HTML, not the
/// live directory API. Parse content only; never evaluate its script fields.
class AcfunSearchClient {
  AcfunSearchClient({AcfunSearchRequest? request, this.timeout = const Duration(seconds: 8), this.maxQueries = 8})
    : _request = request ?? _defaultRequest {
    if (maxQueries < 1) throw ArgumentError('Invalid search cache bound');
  }

  static const serverPageSize = 30;
  static const _separator = '/*<!-- fetch-stream -->*/';
  final AcfunSearchRequest _request;
  final Duration timeout;
  final int maxQueries;
  final _queries = <(String, int), _SearchSequence>{};

  static Future<String> _defaultRequest(Uri uri, CancelToken cancel) => HttpClient.instance.getText(
    uri.toString(),
    cancel: cancel,
    header: {'User-Agent': AcfunApi.userAgent, 'Referer': 'https://www.acfun.cn/search'},
  );

  Future<AcfunSearchPage> _page(String keyword, int page, CancelToken cancel) async {
    final uri = Uri.https('www.acfun.cn', '/search', {
      'keyword': keyword,
      'type': 'user',
      'pCursor': '$page',
      'quickViewId': 'up-list',
      'reqID': '1',
      'ajaxpipe': '1',
    });
    return parsePage(await _request(uri, cancel), page: page);
  }

  Future<List<LiveRoom>> search(String keyword, {int page = 1, int pageSize = 30}) {
    final query = keyword.trim();
    if (query.isEmpty) return Future.value([]);
    if (query.length > 512 || page < 1) return Future.error(const AcfunApiException(AcfunFailureKind.schema));
    final key = (query, pageSize.clamp(1, 60));
    var sequence = _queries.remove(key);
    if (page == 1 && !(sequence?.inFlightPage == 1 && sequence?.inFlight != null)) {
      sequence?.cancel?.cancel('AcFun search refreshed');
      sequence = _SearchSequence();
    }
    if (sequence == null) return Future.error(const AcfunApiException(AcfunFailureKind.paginationExpired));
    _queries[key] = sequence;
    while (_queries.length > maxQueries) {
      _queries.remove(_queries.keys.first)?.cancel?.cancel('AcFun search context expired');
    }
    final existing = sequence.inFlight;
    if (existing != null) {
      return sequence.inFlightPage == page
          ? existing
          : Future.error(const AcfunApiException(AcfunFailureKind.paginationExpired));
    }
    if (sequence.finished && sequence.remaining.isEmpty && page >= sequence.nextApplicationPage) {
      return Future.value([]);
    }
    if (page != sequence.nextApplicationPage) {
      return Future.error(const AcfunApiException(AcfunFailureKind.paginationExpired));
    }
    sequence.inFlightPage = page;
    return sequence.inFlight = _execute(key, sequence);
  }

  Future<List<LiveRoom>> _execute((String, int) key, _SearchSequence sequence) async {
    final cancel = CancelToken();
    sequence.cancel = cancel;
    try {
      return await _collect(key, sequence, cancel).timeout(timeout);
    } on AcfunApiException {
      rethrow;
    } catch (_) {
      throw const AcfunApiException(AcfunFailureKind.transport);
    } finally {
      // Future.timeout alone does not cancel the underlying socket/request.
      if (!cancel.isCancelled) cancel.cancel('AcFun search request finished');
      sequence.cancel = null;
      sequence.inFlight = null;
      sequence.inFlightPage = null;
    }
  }

  Future<List<LiveRoom>> _collect((String, int) key, _SearchSequence sequence, CancelToken cancel) async {
    // Website pages can contain 29 rows while data-total still says 100.
    // Consume actual rows, not guessed offsets, and never let a sparse page
    // falsely tell SearchController that there are no further results.
    var remaining = List<LiveRoom>.from(sequence.remaining);
    var nextServerPage = sequence.nextServerPage;
    var finished = sequence.finished;
    var requests = 0;
    final result = <LiveRoom>[];
    while (result.length < key.$2) {
      if (cancel.isCancelled) throw const AcfunApiException(AcfunFailureKind.transport);
      if (remaining.isEmpty) {
        if (finished) break;
        if (++requests > 4) throw const AcfunApiException(AcfunFailureKind.schema);
        final data = await _page(key.$1, nextServerPage, cancel);
        remaining = List<LiveRoom>.from(data.rooms);
        finished = nextServerPage * serverPageSize >= data.total;
        nextServerPage++;
      }
      final take = min(key.$2 - result.length, remaining.length);
      result.addAll(remaining.take(take));
      remaining = remaining.skip(take).toList();
    }
    if (cancel.isCancelled || !identical(_queries[key], sequence)) {
      throw const AcfunApiException(AcfunFailureKind.transport);
    }
    // Commit only a fully resolved page. Errors/timeouts leave the caller able
    // to retry without losing the already-buffered authors or advancing early.
    sequence.remaining = remaining;
    sequence.nextServerPage = nextServerPage;
    sequence.finished = finished;
    sequence.nextApplicationPage++;
    return result;
  }

  static AcfunSearchPage parsePage(String body, {required int page}) {
    if (body.length > 2 * 1024 * 1024 || page < 1) throw const AcfunApiException(AcfunFailureKind.schema);
    final end = body.indexOf(_separator);
    final data = AcfunApi.object(end < 0 ? body : body.substring(0, end));
    final content = data['html'];
    if (content is! String) throw const AcfunApiException(AcfunFailureKind.schema);
    final fragment = html.parseFragment(content);
    final totalNode = fragment.querySelector('.total-num[data-total]');
    if (totalNode == null) throw const AcfunApiException(AcfunFailureKind.schema);
    final cards = fragment.querySelectorAll('.search-up');
    var total = AcfunApi.integer(totalNode.attributes['data-total']);
    final explicitEmpty = fragment.querySelector('.empty-page') != null;
    if (total == null &&
        AcfunApi.text(totalNode.attributes['data-total']).isEmpty &&
        totalNode.text.replaceAll(RegExp(r'\s'), '') == '共0条结果' &&
        explicitEmpty &&
        cards.isEmpty) {
      total = 0;
    }
    if (total == null ||
        total < 0 ||
        cards.length > serverPageSize ||
        cards.length > min(serverPageSize, max(0, total - (page - 1) * serverPageSize))) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    if (cards.isEmpty && !explicitEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    for (final card in cards) {
      final meta = AcfunApi.object(card.attributes['data-up-exposure-log']);
      final id = AcfunApi.normalizeAuthorId(AcfunApi.text(meta['up_id']));
      final anchor = card.querySelector('.up__main__name a');
      final uri = Uri.tryParse(anchor?.attributes['href'] ?? '');
      if (anchor == null ||
          uri == null ||
          (uri.hasScheme && !{'http', 'https'}.contains(uri.scheme)) ||
          (uri.hasAuthority && !{'www.acfun.cn', 'acfun.cn'}.contains(uri.host)) ||
          uri.userInfo.isNotEmpty ||
          uri.path != '/u/$id' ||
          anchor.text.trim().isEmpty ||
          !seen.add(id)) {
        throw const AcfunApiException(AcfunFailureKind.schema);
      }
      final flag = meta['is_on_live'];
      final live = flag is String ? flag.trim().isNotEmpty : (flag is bool ? flag : null);
      final followerText = card.querySelector('.info__danmaku-count')?.text ?? '';
      final follower = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?[万亿]?)\s*粉丝\s*$').firstMatch(followerText)?.group(1) ?? '';
      rooms.add(
        LiveRoom(
          platform: 'acfun',
          roomId: id,
          userId: id,
          link: '${AcfunApi.origin}/live/$id',
          nick: anchor.text.trim(),
          avatar: AcfunApi.imageUrl(card.querySelector('img.up__avatar')?.attributes['src']),
          introduction: card.querySelector('.up__main__intro')?.text.trim(),
          watching: '',
          followers: follower,
          audienceMetricType: AudienceMetricType.unknown,
          status: live,
          liveStatus: live == null ? LiveStatus.unknown : (live ? LiveStatus.live : LiveStatus.offline),
        ),
      );
    }
    return AcfunSearchPage(rooms: List.unmodifiable(rooms), total: total);
  }
}
