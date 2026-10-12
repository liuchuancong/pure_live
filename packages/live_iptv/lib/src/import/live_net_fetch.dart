/// Downloading playlists and guides over live_net.
///
/// The importer's `IptvFetcher` and `IptvBytesFetcher` are seams, and this is
/// the production pair of implementations: the application hands it a client
/// from its own `DioFactory`, so the proxy rules, the cookies and the redacted
/// network log of every download are the same ones the rest of the app gets.
library;

import 'package:live_iptv/src/import/iptv_importer.dart';
import 'package:live_net/live_net.dart';

/// How long one download may take before it is called dead.
///
/// A playlist is a few hundred kilobytes and a guide a few megabytes; thirty
/// seconds is enough for a slow mirror and short enough that a user waiting
/// on an import is told about it rather than left watching a spinner.
const Duration iptvFetchDefaultTimeout = Duration(seconds: 30);

/// How much of a guide is read before it is refused: 64 MiB of guide text is
/// a large week of programmes, and anything past that is a wrong address
/// (a video, a disk image) rather than a guide that got big.
const int iptvGuideByteLimit = 64 * 1024 * 1024;

/// An [IptvFetcher] that reads [http] as text.
///
/// The charset comes from the response's `content-type`, which matters: a
/// guide served as `charset=gbk` decoded as UTF-8 turns every Chinese
/// channel name into replacement characters, and the importer would then
/// match nothing and quietly store a guide of question marks.
IptvFetcher iptvFetcherFor(
  LiveHttp http, {
  Duration timeout = iptvFetchDefaultTimeout,
  String? userAgent,
  ProxyRoute? proxyRoute,
}) => (url, {headers = const {}}) async {
  final response = await http
      .send(_request(url: url, headers: headers, timeout: timeout, userAgent: userAgent, proxyRoute: proxyRoute))
      .timeout(timeout);
  if (!_isOk(response.statusCode)) {
    throw HttpStatusFailure(statusCode: response.statusCode, url: url);
  }
  return response.text;
};

/// An [IptvBytesFetcher] that reads [http] as bytes, for gzipped guides.
///
/// The body is read incrementally and refused past [limit] rather than
/// buffered without bound: `decodeGuideBytes` needs the whole document to
/// inflate it, so the size has to be checked while it arrives.
IptvBytesFetcher iptvBytesFetcherFor(
  LiveHttp http, {
  Duration timeout = iptvFetchDefaultTimeout,
  int limit = iptvGuideByteLimit,
  String? userAgent,
  ProxyRoute? proxyRoute,
}) => (url, {headers = const {}}) async {
  final request = _request(url: url, headers: headers, timeout: timeout, userAgent: userAgent, proxyRoute: proxyRoute);
  final response = await http.open(request).timeout(timeout);
  if (!_isOk(response.statusCode)) {
    await response.close();
    throw HttpStatusFailure(statusCode: response.statusCode, url: url);
  }
  final body = <int>[];
  try {
    await for (final chunk in response.stream) {
      body.addAll(chunk);
      if (body.length > limit) {
        throw const FormatException('the guide is larger than this app will read');
      }
    }
  } finally {
    // Both the happy path and the abort have to stop the transfer: a
    // cancelled download leaves the socket serving a file nobody reads.
    await response.close();
  }
  return body;
};

LiveRequest _request({
  required Uri url,
  required Map<String, String> headers,
  required Duration timeout,
  required String? userAgent,
  required ProxyRoute? proxyRoute,
}) {
  final merged = {if (userAgent != null && !headers.containsKey('user-agent')) 'user-agent': userAgent, ...headers};
  return LiveRequest.get(url, headers: merged, timeout: timeout, proxyRoute: proxyRoute);
}

/// Whether [statusCode] is a 2xx answer.
///
/// The streamed half of the HTTP contract carries the number without
/// judging it, and a non-2xx answer here is always a failure: an importer
/// that wrote the error page it was handed would replace a working playlist
/// with an HTML message.
bool _isOk(int statusCode) => statusCode >= 200 && statusCode < 300;
