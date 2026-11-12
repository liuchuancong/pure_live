/// Downloading playlists and guides over live_net.
///
/// The importer's `IptvFetcher` and `IptvBytesFetcher` are seams, and this is
/// the production pair of implementations: the application hands it a client
/// from its own `DioFactory`, so the proxy rules, the cookies and the redacted
/// network log of every download are the same ones the rest of the app gets.
library;

import 'dart:async' show TimeoutException, Timer, unawaited;

import 'package:live_iptv/src/import/iptv_importer.dart';
import 'package:live_iptv/src/playlist/text_decode/text_decode.dart';
import 'package:live_net/live_net.dart';

/// How long one playlist download may take before it is called dead.
///
/// A playlist is a few hundred kilobytes; thirty seconds is enough for a
/// slow mirror and short enough that a user waiting on an import is told
/// about it rather than left watching a spinner.
const Duration iptvFetchDefaultTimeout = Duration(seconds: 30);

/// How long one guide download may take before it is called dead.
///
/// Guides are the big ones, served by mirrors that stream for minutes on a
/// bad evening - a public lite table measured past forty seconds one night -
/// and the word the viewer needs then is "slow", not "failed". The guide
/// fetcher defaults to this; the playlist fetcher keeps the short one.
const Duration iptvGuideFetchTimeout = Duration(seconds: 90);

/// How long the streamed body of one download may take, whole.
///
/// The dial timeout above only covers the wait for the response's head;
/// the transport reads the rest as it arrives, with no deadline of its own.
/// A server that answers at once and then trickles — or simply stops —
/// used to hold the import open forever; the budget is what turns that
/// into a verdict. Guides get the wide one, playlists their short one.
const Duration iptvGuideBodyBudget = Duration(minutes: 5);

/// How long the streamed body may go without delivering a byte.
///
/// The judge of a stalled transfer rather than a slow one: a server that
/// is still sending passes, however slowly; one that has stopped — a dead
/// mirror, a proxy that dropped the connection mid-flight — is aborted
/// here instead of hanging the import past any budget.
const Duration iptvChunkIdleTimeout = Duration(seconds: 15);

/// How much of a guide is read before it is refused: 64 MiB of guide text is
/// a large week of programmes, and anything past that is a wrong address
/// (a video, a disk image) rather than a guide that got big.
const int iptvGuideByteLimit = 64 * 1024 * 1024;

/// How much of a playlist is read before it is refused: the largest public
/// lists (every channel of every country) are a few MiB, so 32 MiB is a
/// wrong address — a stream opened as a list — rather than a list.
const int iptvPlaylistByteLimit = 32 * 1024 * 1024;

/// An [IptvFetcher] that reads [http] as text.
///
/// The bytes are decoded by [decodeIptvText] with the response's
/// `content-type` charset as the hint, which matters: a list served as
/// `charset=gbk` — or saved as GBK and served with no charset at all —
/// decoded as UTF-8 turns every Chinese channel name into replacement
/// characters, and a guide read that way matches nothing and quietly
/// stores a guide of question marks.
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
  return decodeIptvText(response.bodyBytes, charset: charsetOfContentType(response.headers['content-type'])).text;
};

/// An [IptvBytesFetcher] that reads [http] as bytes, for gzipped guides.
///
/// The body is read incrementally and refused past [limit] rather than
/// buffered without bound: `decodeGuideBytes` needs the whole document to
/// inflate it, so the size has to be checked while it arrives.
IptvBytesFetcher iptvBytesFetcherFor(
  LiveHttp http, {
  Duration timeout = iptvGuideFetchTimeout,
  Duration bodyBudget = iptvGuideBodyBudget,
  Duration chunkIdle = iptvChunkIdleTimeout,
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
  // The dial above is judged, but the body read is the transport's own and
  // carries no deadline: the budget (whole transfer) and the idle judge
  // (no byte for a while) are what end a stalled or trickling stream.
  var expired = false;
  final budget = bodyBudget <= Duration.zero
      ? null
      : Timer(bodyBudget, () {
          expired = true;
          // Closing is what unblocks the loop below; the verdict itself is
          // thrown once the loop has left.
          unawaited(response.close());
        });
  final body = <int>[];
  try {
    await for (final chunk in response.stream.timeout(chunkIdle)) {
      body.addAll(chunk);
      if (body.length > limit) {
        throw const FormatException('the guide is larger than this app will read');
      }
    }
  } on TimeoutException {
    throw TimeoutFailure('the stream sent nothing for ${chunkIdle.inSeconds}s');
  } on Object catch (error) {
    // The abort can surface as the adapter's own error; the budget's
    // verdict is the honest one to report.
    if (expired) {
      throw TimeoutFailure('the transfer ran past its ${bodyBudget.inSeconds}s budget', cause: error);
    }
    rethrow;
  } finally {
    budget?.cancel();
    // Both the happy path and the abort have to stop the transfer: a
    // cancelled download leaves the socket serving a file nobody reads.
    await response.close();
  }
  if (expired) {
    throw TimeoutFailure('the transfer ran past its ${bodyBudget.inSeconds}s budget');
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
