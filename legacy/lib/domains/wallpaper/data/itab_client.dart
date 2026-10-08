import 'dart:convert';

import 'package:pure_live/core/network/core_error.dart';
import 'package:pure_live/core/network/http_client.dart';

/// Thin client for the iTab wallpaper endpoints.
///
/// These are the requests the iTab browser extension itself sends, captured and
/// replayed: the host is `base.itab.link` (not `api.itab.link`), the answers are
/// plain JSON and **no token is involved**. The extra headers (`mode`,
/// `version`, `fp`, `origin`) are what the server checks before answering.
///
/// Requests go through the app-wide [HttpClient], so the in-app proxy setting
/// and the shared request logging apply to wallpapers too.
class ItabClient {
  ItabClient._();

  static final ItabClient instance = ItabClient._();

  /// JSON API host.
  static const String baseUrl = 'https://base.itab.link';

  /// Static file host (wallpapers, videos).
  static const String filesUrl = 'https://files.itab.link';

  /// Resolution hint. The server caps the delivered width at 2560.
  static const String resolution = '3840x2160';

  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
    'fp': 'zhVusd_0lS.1758762915',
    'mode': 'itab',
    'origin': 'chrome-extension://mhloojimgilafopcmlcikiidgbbnelip',
    'version': '2.2.25',
    'accept': 'application/json, text/plain, */*',
    'Referer': 'https://www.itab.link/',
  };

  /// GET [route] and return the JSON object it answers with.
  ///
  /// Throws [HttpError] for transport failures and [FormatException] when the
  /// body is not an object or carries a non-success `code`.
  Future<Map<String, dynamic>> getJson(String route, Map<String, dynamic> query) async {
    final data = await HttpClient.instance.getJson(
      '$baseUrl$route',
      queryParameters: <String, dynamic>{'lang': 'cn', ...query},
      header: _headers,
    );

    final Map<String, dynamic> json;
    if (data is Map) {
      json = Map<String, dynamic>.from(data);
    } else if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is! Map) {
        throw const FormatException('iTab response is not a JSON object');
      }
      json = Map<String, dynamic>.from(decoded);
    } else {
      throw const FormatException('iTab response is empty');
    }

    final code = json['code'];
    if (code is num && code != 200 && code != 0) {
      throw HttpError('iTab code=$code ${json['msg'] ?? ''}');
    }
    return json;
  }
}
