/// Request headers shared by every adapter.
///
/// Sites do not accept a bare request: several answer 403 without a browser
/// User-Agent (Huya's search CDN), a few check the `Referer` (Bilibili's
/// live media), and most return HTML instead of JSON without an `Accept`.
/// Each adapter used to spell its own, and the ones that forgot were the ones
/// that broke — so the common set is here, and a site that needs more adds to
/// it rather than starting from nothing.
abstract final class SiteHeaders {
  /// The browser User-Agent a CDN expects. Desktop Chrome, deliberately: the
  /// mobile agents get mobile pages whose payloads differ.
  static const String browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// The headers that make a JSON endpoint answer with JSON.
  static const Map<String, String> json = {
    'accept': 'application/json, text/plain, */*',
    'user-agent': browserUserAgent,
  };

  /// The headers of a media request: the live page is the referer, and the
  /// CDN checks it for the signed play URLs.
  static Map<String, String> media(Uri page) => {
    'user-agent': browserUserAgent,
    'referer': '${page.scheme}://${page.host}/',
  };

  /// The same headers with [extra] merged over them.
  static Map<String, String> withExtra(Map<String, String> base, Map<String, String> extra) => {...base, ...extra};
}
