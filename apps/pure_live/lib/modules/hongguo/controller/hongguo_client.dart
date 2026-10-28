import 'dart:convert' show jsonDecode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, DirectRoute, LiveHttp, LiveRequest;

import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';

/// The station could not answer: the service is down, the key was refused,
/// or the answer was not the shape the station expects. The message is safe
/// to show as sent.
final class HongguoFailure implements Exception {
  /// Creates the failure.
  const HongguoFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}

/// How a filter dimension's `select_items` key reaches the browse endpoint's
/// own query parameters.
const Map<String, String> _kBrowseParams = {
  'category_dim_theme': 'theme',
  'category_dim_role': 'setting',
  'category_dim_epoch': 'background',
  'sort': 'sort',
  'gender': 'gender',
  'online_time': 'days',
  'creation_status': 'status',
};

/// The companion service's client: browse, filter panels, boards, the new
/// shelf, search, episode lists and the playable stream URLs.
///
/// Everything hard — the source's request signing, the DRM the CDN's bytes
/// carry — happens inside the service; this side only speaks its small JSON
/// surface and hands the player the mp4 the service decrypts.
final class HongguoClient {
  /// Creates a client over [http] answering at [settings].
  HongguoClient({required this.http, required this.settings});

  /// The transport every ask goes through.
  final LiveHttp http;

  /// The service the asks speak to; the settings provider hands a fresh
  /// client on every change, so this is only read, never set.
  final HongguoSettings settings;

  /// One shelf's listing under a filter selection: theme/setting/background
  /// (the panel's three category dimensions), the sort, the audience, the
  /// freshness window and — on the comic shelf — the status.
  ///
  /// The endpoint answers a whole window at once (there is no offset to
  /// walk); a larger [limit] is how a page asks for more, so callers keep
  /// raising it until the answer comes back short.
  Future<List<HongguoSeries>> browse({
    required HongguoGenre genre,
    Map<String, String> selection = const {},
    int limit = 30,
  }) async {
    final query = <String, String>{'genre': genre.wire, 'limit': '$limit'};
    for (final entry in selection.entries) {
      final parameter = _kBrowseParams[entry.key];
      if (parameter != null && entry.value.isNotEmpty) query[parameter] = entry.value;
    }
    final json = await _getJson('/browse', query);
    return _seriesList(json['items']);
  }

  /// One shelf's live selector panel: the dimensions and their options.
  Future<List<HongguoFilterRow>> filters(HongguoGenre genre) async {
    final json = await _getJson('/filters', {'genre': genre.wire});
    return [
      for (final row in json['rows'] is List<Object?> ? json['rows']! as List<Object?> : const <Object?>[])
        if (row is Map<String, Object?>) HongguoFilterRow.fromJson(row),
    ];
  }

  /// One comic board, ranked.
  Future<List<HongguoSeries>> rank(HongguoBoard board, {int limit = 30}) async {
    final json = await _getJson('/rank', {'board': board.wire, 'limit': '$limit'});
    return _seriesList(json['items']);
  }

  /// One shelf's newest arrivals. Only the live-action shelf has a real
  /// 今日 marker; the other two answer their seven-day window whatever
  /// [onlyToday] says.
  Future<List<HongguoSeries>> latest(HongguoGenre genre, {bool onlyToday = true, int limit = 60}) async {
    final json = await _getJson('/latest', {
      'genre': genre.wire,
      'only_today': onlyToday ? 'true' : 'false',
      'limit': '$limit',
    });
    return _seriesList(json['items']);
  }

  /// One page of search hits; the cursor the answer carries continues the
  /// same query.
  Future<({List<HongguoSeries> items, bool hasMore, String? nextCursor})> searchPage(
    String query, {
    String? cursor,
  }) async {
    final json = await _getJson('/search/page', {'q': query, if (cursor != null && cursor.isNotEmpty) 'cursor': cursor});
    final next = json['next_cursor'];
    return (
      items: _seriesList(json['results']),
      hasMore: json['has_more'] == true,
      nextCursor: next is String ? next : null,
    );
  }

  /// One series' metadata and its episode list.
  Future<HongguoSeriesDetail> episodes(String seriesId) async {
    final json = await _getJson('/episodes', {'series_id': seriesId});
    return HongguoSeriesDetail.fromJson(json);
  }

  /// The playable mp4 for one episode: the service's decrypted, rangeable
  /// stream, with the key riding as a query parameter the way a `<video>`
  /// element needs it.
  String streamUrl({String? vid, String? seriesId, int? episode}) {
    final base = _baseUri();
    final query = <String, String>{
      if (vid != null && vid.isNotEmpty) 'vid': vid,
      if (seriesId != null && seriesId.isNotEmpty) 'series_id': seriesId,
      if (episode != null) 'ep': '$episode',
      'quality': settings.quality.wire,
      if (settings.apiKey.isNotEmpty) 'api_key': settings.apiKey,
    };
    return base.replace(path: '${base.path}/stream', queryParameters: query).toString();
  }

  /// Whether the service answers at all; the root needs no key, so this is
  /// the settings page's test.
  Future<void> ping() async {
    await _getJson('/', const {});
  }

  Uri _baseUri() {
    var base = Uri.parse(
      settings.serverUrl.trim().isEmpty ? HongguoSettings.standard.serverUrl : settings.serverUrl.trim(),
    );
    if (base.path.endsWith('/')) {
      base = base.replace(path: base.path.substring(0, base.path.length - 1));
    }
    return base;
  }

  Future<Map<String, Object?>> _getJson(String path, Map<String, String> query) async {
    final uri = _baseUri().replace(
      path: '${_baseUri().path}$path',
      queryParameters: query.isEmpty ? null : query,
    );
    try {
      final response = await http.send(
        LiveRequest.get(
          uri,
          headers: {'accept': 'application/json', if (settings.apiKey.isNotEmpty) 'x-api-key': settings.apiKey},
          timeout: const Duration(seconds: 20),
          // The companion service is this machine's own, and the reference's
          // backend likewise leaves its local sign service out of
          // HONGGUO_PROXY: a proxy client asked for a loopback address
          // usually refuses the connection. Direct whatever the app's proxy
          // setting is.
          proxyRoute: const DirectRoute(),
        ),
      );
      if (!response.isOk) {
        throw HongguoFailure(_failureText(response.statusCode, response.text));
      }
      try {
        final decoded = jsonDecode(response.text);
        if (decoded is Map<String, Object?>) return decoded;
      } on Object {
        // Falls through to the shape failure below.
      }
      throw const HongguoFailure('The companion service did not answer an object');
    } on HongguoFailure {
      rethrow;
    } on Object catch (error) {
      throw HongguoFailure('$error');
    }
  }

  /// The service's own words for a refusal, when it sent any: FastAPI's
  /// `detail`, or the raw status when it did not.
  static String _failureText(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
        if (detail is Map<String, Object?> && detail['detail'] is String) {
          return detail['detail']! as String;
        }
      }
    } on Object {
      // A non-JSON refusal is reported by status alone.
    }
    return 'HTTP $statusCode';
  }

  static List<HongguoSeries> _seriesList(Object? json) {
    if (json is! List<Object?>) return const [];
    return [
      for (final item in json)
        if (item is Map<String, Object?>) HongguoSeries.fromJson(item),
    ];
  }
}

/// The station's client, rebuilt whenever its settings change.
final hongguoClientProvider = Provider<HongguoClient>((ref) {
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  ref.onDispose(http.close);
  return HongguoClient(http: http, settings: ref.watch(hongguoSettingsProvider));
});
