/// Xiaohongshu's (小红书) endpoints and constants (3.x's `XiaohongshuApi`
/// statics): the web origin of the share pages, the headers 3.x sent, the
/// platform's limits, and the quality ids as stored before the merge of the
/// two codecs' qualities.
abstract final class XiaohongshuEndpoints {
  /// Web origin: the share pages, and `Referer` with a trailing slash.
  static const String origin = 'https://www.xiaohongshu.com';

  /// The Android Chrome UA 3.x sent (`XiaohongshuApi.headers`).
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 Chrome/87.0.4280.141 Mobile Safari/537.36';

  /// What 3.x sent with the page, short-link and media requests
  /// (`XiaohongshuApi.headers`, which its `PlaybackHeaderResolver` also
  /// used), names in lower case; no cookie.
  static const Map<String, String> headers = {'referer': '$origin/', 'user-agent': userAgent};

  /// Largest page 3.x accepted (2 MiB); a larger one is api-changed.
  static const int responseLimit = 2 * 1024 * 1024;

  /// How long a search may spend on a short link, and each of its requests
  /// (3.x's search session).
  static const Duration shortLinkTimeout = Duration(seconds: 12);

  static final RegExp _roomIdPattern = RegExp(r'^[1-9][0-9]{0,19}$');

  /// Whether [value] is a broadcast room id: 1–20 digits without a leading
  /// zero.
  static bool isRoomId(String value) => _roomIdPattern.hasMatch(value);

  /// The share page of [roomId], also the room's link.
  static Uri roomUrl(String roomId) => Uri.parse('$origin/livestream/$roomId');

  /// 3.x's quality ids (codec and `quality_type`) → the ids now (the
  /// `quality_type`), for an old stored quality preference: the recorded
  /// `HD` of both codecs is one quality now. Other `quality_type`s follow
  /// the same rule ([qualityIdFromLegacy]).
  static const Map<String, String> legacyQualityIds = {'h264:HD': 'HD', 'h265:HD': 'HD'};

  static final RegExp _legacyQualityId = RegExp(r'^h26[45]:(.+)$', caseSensitive: false);

  /// The quality id for a 3.x one: `h264:<quality_type>` and
  /// `h265:<quality_type>` become `<quality_type>` ([legacyQualityIds]); any
  /// other id is kept (trimmed), so the mapping can be applied again.
  static String qualityIdFromLegacy(String id) {
    final value = id.trim();
    return legacyQualityIds[value] ?? _legacyQualityId.firstMatch(value)?.group(1) ?? value;
  }
}
