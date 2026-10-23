/// Probing a media address for the bytes that prove it is a stream.
///
/// "The HTTP call succeeded" and "there is something to play" are different
/// claims, and IPTV lists confuse them constantly: a dead mirror answers 200
/// with an HTML apology page, a firewall answers 200 with nothing at all, and
/// a working line answers 200 with `FLV`, an `#EXTM3U`, or 188-byte packets
/// starting `0x47`. This probe opens the address through [LiveHttp.open],
/// reads the head of the body — never the whole stream — and says which of
/// those it found, timing how long the first byte took on the way.
///
/// The transport is injected rather than assumed, so the caller decides which
/// proxy the probe travels by, which user agent it presents, and how much of
/// its connection pool this shares with the real playback. Nothing here
/// belongs to a player: the answer is a verdict about bytes, and what to do
/// with a slow or dead line is the caller's ladder.
library;

// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/src/live_http.dart';
import 'package:live_net/src/proxy.dart';
import 'package:live_net/src/request.dart';
import 'package:live_net/src/streamed_response.dart';
import 'package:live_net/src/transport_failure.dart';
import 'package:meta/meta.dart';

/// What the first bytes of a response say the body is.
enum MediaContainer {
  /// HTTP-FLV: `FLV` at offset 0.
  flv,

  /// An HLS playlist, master or media: `#EXTM3U`.
  hlsPlaylist,

  /// Raw MPEG transport stream: a `0x47` sync byte every 188 bytes.
  mpegTs,

  /// ISO base media: `ftyp`, `styp`, `moov`, `sidx` — an mp4 or a fragmented
  /// mp4, which is what most DASH and HLS video tracks carry.
  isoBmff,

  /// Matroska or WebM, by its EBML header.
  matroska,

  /// An MPEG audio frame or an `ID3` tag: a radio stream.
  mpegAudio,

  /// ADTS: raw AAC frames, another radio shape.
  adts,

  /// A DASH manifest: `<?xml` or `<MPD` at the head of the document.
  dash,

  /// Nothing above. Not automatically garbage — see [MediaProbeResult.playable]
  /// for what the probe actually concluded.
  unknown,
}

/// Whether the container names a media format this app can put in a player.
extension MediaContainerX on MediaContainer {
  /// Whether the container names something a player understands.
  bool get isMedia => this != MediaContainer.unknown;
}

/// What one probe of one address found.
@immutable
final class MediaProbeResult {
  /// A verdict.
  const MediaProbeResult({
    required this.playable,
    this.latency = Duration.zero,
    this.bytes = 0,
    this.container = MediaContainer.unknown,
    this.statusCode,
    this.inconclusive = false,
    this.message,
  });

  /// An address whose head of body was a real stream.
  const MediaProbeResult.answered({
    required Duration latency,
    required int bytes,
    required MediaContainer container,
    required int statusCode,
  }) : this(playable: true, latency: latency, bytes: bytes, container: container, statusCode: statusCode);

  /// An address that answered, or refused, in a way that is not a stream.
  const MediaProbeResult.notMedia({
    required this.message,
    this.statusCode,
    this.latency = Duration.zero,
    this.bytes = 0,
  }) : playable = false,
       container = MediaContainer.unknown,
       inconclusive = false;

  /// An address this probe cannot ask about at all.
  ///
  /// `rtmp://`, `rtsp://`, `udp://` and the plugin schemes a real IPTV list
  /// contains have no HTTP to open; saying "down" would be a lie about
  /// someone else's protocol, and saying "up" would be a guess.
  const MediaProbeResult.inconclusive(this.message)
    : playable = false,
      latency = Duration.zero,
      bytes = 0,
      container = MediaContainer.unknown,
      statusCode = null,
      inconclusive = true;

  /// Whether there is a stream behind this address.
  final bool playable;

  /// How long the first byte of the body took; zero when none arrived or the
  /// probe never got to ask.
  final Duration latency;

  /// How many bytes were read to decide.
  final int bytes;

  /// The container the bytes identified.
  final MediaContainer container;

  /// The HTTP status the server answered, null when the transport broke
  /// before one arrived.
  final int? statusCode;

  /// Whether the probe abstained because the address is not HTTP.
  final bool inconclusive;

  /// Why it is not playable, for the screen and the log.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is MediaProbeResult &&
      other.playable == playable &&
      other.latency == latency &&
      other.bytes == bytes &&
      other.container == container &&
      other.statusCode == statusCode &&
      other.inconclusive == inconclusive &&
      other.message == message;

  @override
  int get hashCode => Object.hash(playable, latency, bytes, container, statusCode, inconclusive, message);

  @override
  String toString() =>
      'MediaProbeResult(${inconclusive
          ? 'inconclusive'
          : playable
          ? 'media'
          : 'not media'}, '
      '${container.name}${statusCode == null ? '' : ', $statusCode'})';
}

/// The container [head] identifies, or [MediaContainer.unknown].
///
/// Every test is a signature at a fixed offset, not a guess from a file name:
/// a `.m3u8` that turns out to be an HTML login page is not HLS, and a
/// `.ts` on a CDN answering `video/mp4` is not a transport stream. Binary
/// shapes are read from the bytes themselves; text shapes only after nothing
/// binary matched, because `#EXTM3U` and `<MPD` are the whole of their claim.
MediaContainer sniffMediaContainer(List<int> head) {
  if (head.isEmpty) {
    return MediaContainer.unknown;
  }
  if (head.length >= 3 && head[0] == 0x46 && head[1] == 0x4c && head[2] == 0x56) {
    return MediaContainer.flv;
  }
  // A transport stream is 188-byte packets, each starting with the sync byte.
  // Two sync bytes 188 apart is a strong signal; one is enough once the
  // caller only reads that much, which is why the short read is accepted.
  if (head[0] == 0x47 && (head.length < 189 || head[188] == 0x47)) {
    return MediaContainer.mpegTs;
  }
  if (head.length >= 4 && head[0] == 0x1a && head[1] == 0x45 && head[2] == 0xdf && head[3] == 0xa3) {
    return MediaContainer.matroska;
  }
  if (head.length >= 8) {
    final box = String.fromCharCodes(head.sublist(4, 8));
    if (const ['ftyp', 'styp', 'moov', 'mdat', 'sidx', 'free', 'wide', 'jumb'].contains(box)) {
      return MediaContainer.isoBmff;
    }
  }
  if (head.length >= 2 && head[0] == 0xff && (head[1] & 0xf6) == 0xf0) {
    return MediaContainer.adts;
  }
  if ((head.length >= 3 && head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33) || // `ID3`
      (head.length >= 2 && head[0] == 0xff && (head[1] & 0xe0) == 0xe0)) {
    return MediaContainer.mpegAudio;
  }
  return _containerOfText(head);
}

/// The text-shaped containers, found by what their document starts with.
MediaContainer _containerOfText(List<int> head) {
  final text = utf8.decode(head.length > 512 ? head.sublist(0, 512) : head, allowMalformed: true).trimLeft();
  if (text.startsWith('\uFEFF')) {
    return _containerOfText(_utf8Bytes(text.substring(1)));
  }
  if (text.startsWith('#EXTM3U') || text.startsWith('#EXT')) {
    return MediaContainer.hlsPlaylist;
  }
  if (text.startsWith('<MPD') || (text.startsWith('<?xml') && text.contains('<MPD'))) {
    return MediaContainer.dash;
  }
  return MediaContainer.unknown;
}

/// [text] as UTF-8 bytes, for the one place a byte-order mark has to be
/// dropped before the signature is read.
List<int> _utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// A scheme this probe can open.
bool _isHttpScheme(String scheme) => scheme == 'http' || scheme == 'https';

/// Whether [statusCode] is a 2xx answer. The streamed-response contract
/// carries the number, not a judgement, and a probe has to make its own.
bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

/// Opens media addresses and reports what their first bytes are.
///
/// [firstBytes] bounds how much is read: enough to match a signature with
/// room to spare, and small enough that probing a hundred channels is not a
/// hundred downloads. The response is closed as soon as that much has
/// arrived, which for a live stream means the transfer is cut off while it
/// is still in its opening second.
///
/// [timeout] applies twice — as the transport's own per-phase timeout and as
/// the ceiling on the whole probe — because a server that accepts the
/// connection and then says nothing never trips a receive timeout on its own
/// until the phase deadline, and a probe that has to wait for that is a probe
/// the interface cannot show progress on.
final class MediaProbe {
  /// A probe reading through [http].
  MediaProbe({
    required this.http,
    this.firstBytes = 64 * 1024,
    this.timeout = const Duration(seconds: 8),
    this.userAgent,
    this.proxyRoute,
  });

  /// The transport the probe opens addresses with; it carries the caller's
  /// proxy policy, cookies and logging.
  final LiveHttp http;

  /// How many bytes of body are read before the address is judged.
  ///
  /// The read stops at the first chunk that reaches the cap, so what actually
  /// arrives may overshoot by one network chunk — and nothing beyond that is
  /// ever pulled off the socket.
  final int firstBytes;

  /// The ceiling on one probe.
  final Duration timeout;

  /// A user agent to present when the call brings none. Some IPTV sources
  /// answer a bare client with 403, and a probe that reports "dead" for what
  /// is really "I did not say who I was" is worse than no probe at all.
  final String? userAgent;

  /// A route to force on every probe, overriding the transport's policy.
  final ProxyRoute? proxyRoute;

  /// Probes [url], which may be any scheme; anything that is not HTTP
  /// answers [MediaProbeResult.inconclusive].
  Future<MediaProbeResult> check(String url, {Map<String, String> headers = const {}, String? site}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      return MediaProbeResult.notMedia(message: 'the address is not a URL: "$url"');
    }
    return await checkUri(uri, headers: headers, site: site);
  }

  /// Probes [url] and reads at most [firstBytes] of its body.
  Future<MediaProbeResult> checkUri(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    CancelToken? cancelToken,
  }) async {
    if (!_isHttpScheme(url.scheme)) {
      return MediaProbeResult.inconclusive('${url.scheme} is not an address this probe can open');
    }
    final token = cancelToken ?? CancelToken();
    final requestHeaders = {
      if (userAgent != null && !headers.containsKey('user-agent')) 'user-agent': userAgent!,
      ...headers,
    };
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .open(
            LiveRequest.get(
              url,
              headers: requestHeaders,
              site: site,
              timeout: timeout,
              cancelToken: token,
              proxyRoute: proxyRoute,
            ),
          )
          .timeout(timeout);
      return await _judge(response, stopwatch);
    } on TimeoutException {
      // The deadline is the caller's, so the socket goes with it: a probe
      // that timed out must not leave the stream open behind the verdict.
      token.cancel('probe timeout');
      return MediaProbeResult.notMedia(message: 'no answer within ${timeout.inSeconds}s');
    } on TransportFailure catch (failure) {
      return MediaProbeResult.notMedia(message: '${failure.label}: ${failure.description}');
    } on Object catch (error) {
      return MediaProbeResult.notMedia(message: '$error');
    } finally {
      stopwatch.stop();
    }
  }

  /// Reads the head of [response] and decides what it is.
  Future<MediaProbeResult> _judge(LiveStreamedResponse response, Stopwatch stopwatch) async {
    final head = BytesBuilder();
    var bytes = 0;
    Duration? firstByte;
    try {
      await for (final chunk in response.stream) {
        firstByte ??= stopwatch.elapsed;
        head.add(chunk);
        bytes += chunk.length;
        if (bytes >= firstBytes) {
          break;
        }
      }
    } finally {
      // Always drop what is left: a live stream would otherwise keep feeding
      // bytes into a probe that has already answered.
      await response.close();
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!_isSuccess(response.statusCode)) {
      return MediaProbeResult.notMedia(
        statusCode: response.statusCode,
        latency: firstByte ?? Duration.zero,
        bytes: bytes,
        message: 'answered ${response.statusCode}',
      );
    }
    if (bytes == 0) {
      return MediaProbeResult.notMedia(statusCode: response.statusCode, message: 'answered 200 with no body');
    }
    final container = sniffMediaContainer(head.takeBytes());
    if (container == MediaContainer.unknown && _isWebPage(contentType)) {
      return MediaProbeResult.notMedia(
        statusCode: response.statusCode,
        latency: firstByte ?? Duration.zero,
        bytes: bytes,
        message: 'answered a web page ($contentType), not a stream',
      );
    }
    if (container == MediaContainer.unknown) {
      // Bytes arrived, and nothing says they are not media: a player can
      // still sniff them. The container stays unknown so the caller knows the
      // verdict was reached by "the server sent something", not by signature.
      return MediaProbeResult.answered(
        latency: firstByte ?? stopwatch.elapsed,
        bytes: bytes,
        container: MediaContainer.unknown,
        statusCode: response.statusCode,
      );
    }
    return MediaProbeResult.answered(
      latency: firstByte ?? stopwatch.elapsed,
      bytes: bytes,
      container: container,
      statusCode: response.statusCode,
    );
  }

  /// Whether [contentType] names a document a player cannot play, which is
  /// what most dead IPTV mirrors answer instead of a stream.
  bool _isWebPage(String contentType) {
    final lowered = contentType.toLowerCase();
    return lowered.contains('text/html') || lowered.contains('text/plain') || lowered.contains('application/json');
  }
}
