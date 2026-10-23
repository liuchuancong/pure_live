/// YouTube (InnerTube) endpoints, the WEB/ANDROID request contexts, the fixed
/// headers and protocol constants (ARCHITECTURE.md §7.2: endpoint shapes and
/// bodies live here; parsing lives in `parsers/`).
///
/// Every InnerTube call is a JSON `POST` to `youtubei/v1/{ep}`; the watch and
/// channel pages, the RSS feed and the HLS master are plain `GET`s. Anonymous
/// playback works through the ANDROID client context, so no API key beyond the
/// public WEB fallback is ever required.
abstract final class YoutubeEndpoints {
  /// The web origin; also the media and API requests' `Origin`.
  static const String origin = 'https://www.youtube.com';

  /// Host of the watch pages and the InnerTube API.
  static const String host = 'www.youtube.com';

  /// The public WEB `INNERTUBE_API_KEY`; also scraped from a watch page when
  /// one is read ([YoutubeEndpoints.apiKeyPattern]).
  static const String apiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  /// Desktop Chrome 140 on Windows — the UA every request (page, API and
  /// media) is sent with.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The `Accept` a watch/channel page request sends.
  static const String pageAccept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

  /// The `Accept` an InnerTube API request sends.
  static const String apiAccept = 'application/json';

  /// The `Accept-Language` every request sends.
  static const String acceptLanguage = 'en-US,en;q=0.9';

  /// The consent cookie: `SOCS=CAI` clears the EU consent interstitial so the
  /// pages return data instead of a consent wall.
  static const String cookie = 'SOCS=CAI';

  /// The Live hub channel browsed by discovery (`youtube.com/live`).
  static const String liveHubBrowseId = 'UC4R8DWoMoI7CAwX8_LjQHig';

  /// The hard-coded "Live" search filter — a base64 protobuf token sent
  /// verbatim (no runtime protobuf); `EgJAAQ==` percent-encoded.
  static const String liveSearchParams = 'EgJAAQ%3D%3D';

  /// The WEB client context of the page-like API calls (next, search, browse,
  /// live_chat, resolve_url).
  static const Map<String, Object?> webContext = <String, Object?>{
    'client': <String, Object?>{'clientName': 'WEB', 'clientVersion': '2.20260925.01.00', 'hl': 'en', 'gl': 'US'},
  };

  /// The ANDROID client context used for the anonymous player call; the
  /// DESKTOP platform with an EMBED screen returns public HLS manifests without
  /// a login.
  static const Map<String, Object?> androidContext = <String, Object?>{
    'client': <String, Object?>{
      'clientName': 'ANDROID',
      'clientVersion': '21.08.266',
      'platform': 'DESKTOP',
      'clientScreen': 'EMBED',
      'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
      'browserName': 'Chrome',
    },
    'user': <String, Object?>{'lockedSafetyMode': false},
    'request': <String, Object?>{'useSsl': true},
  };

  /// An 11-character video id.
  static final RegExp videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// A `UC` channel id (the external id InnerTube reports).
  static final RegExp channelIdPattern = RegExp(r'^UC[A-Za-z0-9_-]{22}$');

  /// The `"INNERTUBE_API_KEY":"…"` literal of a watch page.
  static final RegExp apiKeyPattern = RegExp('"INNERTUBE_API_KEY":"([^"]+)"');

  /// The InnerTube URL of endpoint [ep]; the player call carries [key].
  static Uri api(String ep, {String? key}) {
    final query = key == null ? 'prettyPrint=false' : 'prettyPrint=false&key=${Uri.encodeComponent(key)}';
    return Uri.parse('$origin/youtubei/v1/$ep?$query');
  }

  /// The watch page URL of [videoId].
  static String watchUrl(String videoId) => '$origin/watch?v=${Uri.encodeComponent(videoId.trim())}';

  /// The watch page [Uri] of [videoId].
  static Uri watchUri(String videoId) => Uri.parse(watchUrl(videoId));

  /// The page headers of [referer] (the origin when none).
  static Map<String, String> pageHeaders({String? referer}) => {
    'user-agent': userAgent,
    'accept': pageAccept,
    'accept-language': acceptLanguage,
    'cookie': cookie,
    'referer': referer ?? origin,
  };

  /// The InnerTube API headers of [referer] (the origin when none).
  static Map<String, String> apiHeaders({String? referer}) => {
    'user-agent': userAgent,
    'accept': apiAccept,
    'accept-language': acceptLanguage,
    'cookie': cookie,
    'referer': referer ?? origin,
    'origin': origin,
  };

  /// Media request headers for broadcast [videoId]: the origin, the watch page
  /// as Referer and the desktop UA (no cookie).
  static Map<String, String> mediaHeaders(String videoId) => {
    'origin': origin,
    'referer': watchUrl(videoId),
    'user-agent': userAgent,
  };

  /// The ANDROID-context player body of [videoId].
  static Map<String, Object?> playerBody(String videoId) => {
    'context': androidContext,
    'videoId': videoId.trim(),
    'contentCheckOk': true,
    'racyCheckOk': true,
  };

  /// The WEB-context `next` body of [videoId].
  static Map<String, Object?> nextBody(String videoId) => {'context': webContext, 'videoId': videoId.trim()};

  /// The WEB-context `search` first-page body for [query] (the literal Live
  /// filter sent as-is).
  static Map<String, Object?> searchPage1Body(String query) => {
    'context': webContext,
    'query': query.trim(),
    'params': liveSearchParams,
  };

  /// The WEB-context `search` follow-up body for [continuation].
  static Map<String, Object?> searchContinuationBody(String continuation) => {
    'context': webContext,
    'continuation': continuation,
  };

  /// The WEB-context `browse` body for the Live hub.
  static Map<String, Object?> browseBody() => {'context': webContext, 'browseId': liveHubBrowseId};

  /// The WEB-context `live_chat/get_live_chat` body for [continuation].
  static Map<String, Object?> liveChatBody(String continuation) => {
    'context': webContext,
    'continuation': continuation,
  };

  /// The WEB-context `updated_metadata` body of [videoId]: the live viewer count
  /// the watch page shows.
  static Map<String, Object?> metadataBody(String videoId) => {'context': webContext, 'videoId': videoId.trim()};

  /// The WEB-context `navigation/resolve_url` body for [url].
  static Map<String, Object?> resolveUrlBody(String url) => {'context': webContext, 'url': url};
}
