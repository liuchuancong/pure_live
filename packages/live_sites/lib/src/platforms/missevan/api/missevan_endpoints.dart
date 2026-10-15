/// Missevan's (猫耳 FM) endpoints and constants (3.x's `MissevanApi`
/// statics): the API origin, the headers its requests and the media carry,
/// the platform's limits, the catalog's namespace groups and the one
/// quality.
abstract final class MissevanEndpoints {
  /// Web origin: the `Origin` of every request, and with a slash its
  /// `Referer`.
  static const String origin = 'https://fm.missevan.com';

  /// The API root under [origin]; endpoint paths are appended to it.
  static const String apiRoot = '/api/v2/';

  /// The user agent sent to the API and the media CDN.
  static const String userAgent = 'Mozilla/5.0';

  /// Headers of the API and media requests. No cookie: the API is anonymous;
  /// only the chat socket asks for a guest session of its own.
  static const Map<String, String> headers = {'referer': '$origin/', 'origin': origin, 'user-agent': userAgent};

  /// Where the chat's guest session is asked for (`Set-Cookie: FM_SESS`); the
  /// API and media need no cookie.
  static final Uri guestSession = Uri.https('fm.missevan.com', '/api/user/info');

  /// The site's default picture (a grey cat) that rows without a cover of
  /// their own carry as `cover_url`: a stand-in, left empty so that it never
  /// replaces a stored cover.
  static const String placeholderCover = 'https://static.maoercdn.com/avatars/icon01.png';

  /// Rows the directory answers per page; a page may carry more (promoted
  /// rooms), never a different echo.
  static const int serverPageSize = 20;

  /// Largest answer read (1 MiB).
  static const int responseLimit = 1024 * 1024;

  /// How long before `expires` a pull URL is renewed.
  static const Duration leaseLead = Duration(minutes: 1);

  /// The namespace groups the `meta/data` tabs are read into, by namespace:
  /// an area's parent group. A tab of another namespace is skipped.
  static const Map<String, String> namespaceNames = {'catalog': '分区', 'list': '团播', 'tag': '标签'};

  /// The list parameter a tab of each namespace is asked with.
  static const Map<String, String> namespaceQuery = {'catalog': 'catalog_id', 'tag': 'tag_id', 'list': 'type'};

  /// The id field of a `meta/data` tab of each namespace.
  static const Map<String, String> namespaceTabId = {'catalog': 'catalog_id', 'tag': 'tag_id', 'list': 'list_type'};

  /// Longest keyword `chatroom/search` is sent, in characters (a longer one
  /// is cut to its first characters).
  static const int maxKeywordLength = 100;

  /// Last page asked for.
  static const int maxPage = 10000;

  /// Largest page size a caller may ask for (the site's pages are fixed at
  /// [serverPageSize] rows, so the size only has to be sane).
  static const int maxPageSize = 100;

  /// The id of the one quality: the CDN's quality code the pull URLs carry
  /// (`qn=10000`, the source).
  static const String qualityId = '10000';

  /// The name of that quality.
  static const String qualityName = '原画';

  /// The quality ids as stored before the two transports became lines of one
  /// quality (case-insensitive) → the id of that quality.
  static const Map<String, String> legacyQualityIds = {'hls': qualityId, 'flv': qualityId};

  /// The quality id for [id] as stored before the merge (case-insensitive);
  /// any other id is kept.
  static String qualityIdFromLegacy(String id) => legacyQualityIds[id.trim().toLowerCase()] ?? id.trim();

  static final RegExp _idPattern = RegExp(r'^[1-9][0-9]{0,17}$');

  /// Whether [value] is a room or area id: 1–18 digits, no leading zero.
  static bool isId(String value) => _idPattern.hasMatch(value);

  /// The room's web page.
  static String roomUrl(String roomId) => '$origin/live/$roomId';

  /// The area id of the tab [id] of [namespace]: `<namespace>:<id>`, unique
  /// across the namespaces (a catalog and a tag with the same number are
  /// different areas).
  static String areaId(String namespace, int id) => '$namespace:$id';

  /// The `(namespace, id)` of a composite [areaId] ([areaId]), or null for
  /// anything else — another platform's shape, an unknown namespace or an id
  /// that is not a room number.
  static (String namespace, String id)? splitAreaId(String areaId) {
    final separator = areaId.indexOf(':');
    if (separator <= 0 || separator == areaId.length - 1) return null;
    final namespace = areaId.substring(0, separator);
    final id = areaId.substring(separator + 1);
    return namespaceQuery.containsKey(namespace) && isId(id) ? (namespace, id) : null;
  }

  /// The room of a `fm.missevan.com/live/{id}` link: http(s), that host
  /// exactly (any case), the default port, no user info, and the path
  /// `live/{id}` with at most a trailing slash; a query is allowed. Null for
  /// anything else.
  static String? roomIdFromUri(Uri? uri) {
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.toLowerCase() != 'fm.missevan.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final parts = uri.pathSegments.toList();
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    return parts.length == 2 && parts.first == 'live' && isId(parts.last) ? parts.last : null;
  }
}
