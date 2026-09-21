import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'rumble_api.dart';
import 'rumble_link.dart';

abstract interface class RumblePageResolver {
  Future<RumbleRoom> resolve(String videoKey, {bool includeMedia = true, bool refresh = false});
}

/// Resolves the live page in an official browser session. Rumble's public
/// player obtains a session-specific HLS master that is intermittently blocked
/// for plain HTTP clients, so playback discovery stays in the page context.
final class RumbleBrowserPageResolver implements RumblePageResolver {
  static const Duration cacheDuration = Duration(seconds: 30);
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  static Future<void> _evaluationTail = Future<void>.value();

  final Map<String, ({DateTime at, RumbleRoom room})> _cache = {};
  final Map<String, Future<RumbleRoom>> _inFlight = {};

  @override
  Future<RumbleRoom> resolve(String videoKey, {bool includeMedia = true, bool refresh = false}) {
    if (!isSupported) throw const RumbleException(RumbleFailure.mediaUnavailable);
    final key = RumbleLink.requireVideoKey(videoKey);
    final cacheKey = '$key:${includeMedia ? 'media' : 'metadata'}';
    final cached = _cache[cacheKey];
    if (!refresh && cached != null && DateTime.now().difference(cached.at) < cacheDuration) {
      return Future.value(cached.room);
    }
    final active = _inFlight[cacheKey];
    if (active != null) return active;
    final request = _serializedResolve(key, includeMedia: includeMedia).then((room) {
      _cache[cacheKey] = (at: DateTime.now(), room: room);
      return room;
    });
    _inFlight[cacheKey] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[cacheKey], request)) _inFlight.remove(cacheKey);
    });
  }

  static Future<RumbleRoom> _serializedResolve(String videoKey, {required bool includeMedia}) async {
    final predecessor = _evaluationTail;
    final release = Completer<void>();
    _evaluationTail = release.future;
    try {
      await predecessor;
      return await _resolveExclusive(videoKey, includeMedia: includeMedia);
    } finally {
      release.complete();
    }
  }

  static Future<RumbleRoom> _resolveExclusive(String videoKey, {required bool includeMedia}) async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageCompleter = Completer<void>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(RumbleLink.videoUrl(videoKey))),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: true,
          transparentBackground: true,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: RumbleApi.userAgent,
        ),
        onWebViewCreated: (controller) {
          if (!controllerCompleter.isCompleted) controllerCompleter.complete(controller);
        },
        onLoadStop: (controller, url) {
          if (!pageCompleter.isCompleted) pageCompleter.complete();
        },
      );
      await webView.run();
      final controller = await controllerCompleter.future.timeout(const Duration(seconds: 12));
      await pageCompleter.future.timeout(const Duration(seconds: 25));
      await Future<void>.delayed(const Duration(seconds: 2));
      final result = await controller
          .callAsyncJavaScript(functionBody: buildPageScript(videoKey, includeMedia: includeMedia))
          .timeout(const Duration(seconds: 35));
      if (result == null || result.error != null || result.value is! String) {
        throw const RumbleException(RumbleFailure.mediaUnavailable);
      }
      return parsePagePayload(videoKey, result.value! as String, requireMedia: includeMedia);
    } on RumbleException {
      rethrow;
    } catch (_) {
      throw const RumbleException(RumbleFailure.mediaUnavailable);
    } finally {
      if (webView?.isRunning() == true) await webView!.dispose();
    }
  }

  @visibleForTesting
  static String buildPageScript(String videoKey, {required bool includeMedia}) {
    final key = RumbleLink.requireVideoKey(videoKey);
    final encodedKey = jsonEncode(key);
    final encodedPath = jsonEncode('/$key.html');
    return '''
const expectedKey = $encodedKey;
const expectedPath = $encodedPath;
const includeMedia = ${includeMedia ? 'true' : 'false'};
const deadline = Date.now() + 22000;
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
while ((location.pathname.toLowerCase() !== expectedPath || !document.querySelector('script[type="application/ld+json"]')) && Date.now() < deadline) {
  await sleep(150);
}
if (location.pathname.toLowerCase() !== expectedPath) throw new Error('Rumble page identity mismatch');
let video = null;
for (const script of document.querySelectorAll('script[type="application/ld+json"]')) {
  try {
    const decoded = JSON.parse(script.textContent || '');
    const values = Array.isArray(decoded) ? decoded : [decoded];
    video = values.find(value => value && value['@type'] === 'VideoObject') || video;
  } catch (_) {}
}
if (!video) throw new Error('Rumble VideoObject missing');
const canonical = new URL(String(video.url || ''), location.href);
if (canonical.pathname.toLowerCase() !== expectedPath) throw new Error('Rumble canonical identity mismatch');
const clean = value => String(value || '').trim().replace(/\\s+/g, ' ');
const streamText = clean(document.querySelector('.media-description-info-stream-time')?.textContent).toLowerCase();
const live = streamText.includes('streaming now') || streamText.includes('live now');
let currentViewers = clean(document.querySelector('.live-video-view-count-status')?.textContent);
if (live && !currentViewers) {
  const viewerDeadline = Date.now() + 3500;
  while (!currentViewers && Date.now() < viewerDeadline) {
    await sleep(100);
    currentViewers = clean(document.querySelector('.live-video-view-count-status')?.textContent);
  }
}
const author = document.querySelector('a.media-by--a[rel="author"], a[rel="author"]');
const channel = author ? new URL(author.getAttribute('href') || '', location.href).pathname : '';
const interaction = Array.isArray(video.interactionStatistic) ? video.interactionStatistic[0] : video.interactionStatistic;
let masterUrl = '';
let playlist = '';
if (includeMedia && live) {
  while (!masterUrl && Date.now() < deadline) {
    masterUrl = performance.getEntriesByType('resource')
      .map(entry => String(entry.name || ''))
      .find(url => url.includes('/live-hls') && url.includes('/playlist.m3u8')) || '';
    if (!masterUrl) await sleep(100);
  }
  if (!masterUrl) throw new Error('Rumble HLS master was not observed');
  const response = await fetch(masterUrl, {credentials: 'include', cache: 'no-store'});
  if (!response.ok) throw new Error('Rumble HLS master returned ' + response.status);
  playlist = await response.text();
  if (!playlist.startsWith('#EXTM3U')) throw new Error('Rumble master is not HLS');
}
return JSON.stringify({
  videoKey: expectedKey,
  title: clean(video.name) || clean(document.querySelector('h1.h1')?.textContent),
  description: clean(video.description),
  thumbnail: Array.isArray(video.thumbnailUrl) ? String(video.thumbnailUrl[0] || '') : String(video.thumbnailUrl || ''),
  embedUrl: String(video.embedUrl || ''),
  channel,
  channelName: clean(document.querySelector('.media-heading-name')?.textContent),
  category: clean(document.querySelector('.video-category-tag-primary')?.textContent),
  followers: clean(document.querySelector('.media-heading-num-followers')?.textContent),
  currentViewers,
  totalViews: interaction ? interaction.userInteractionCount : null,
  live,
  masterUrl,
  playlist
});
''';
  }

  @visibleForTesting
  static RumbleRoom parsePagePayload(String rawVideoKey, String rawPayload, {required bool requireMedia}) {
    final videoKey = RumbleLink.requireVideoKey(rawVideoKey);
    if (rawPayload.length > 1024 * 1024) throw const RumbleException(RumbleFailure.schema);
    final Map<String, dynamic> payload;
    try {
      final value = jsonDecode(rawPayload);
      if (value is! Map) throw const RumbleException(RumbleFailure.schema);
      payload = value.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException {
      throw const RumbleException(RumbleFailure.schema);
    }
    if (payload['videoKey'] != videoKey || payload['live'] is! bool) {
      throw const RumbleException(RumbleFailure.identity);
    }
    final state = payload['live'] as bool ? RumbleState.live : RumbleState.offline;
    final channel = _channelFromPath(_string(payload['channel']));
    final cover = _image(_string(payload['thumbnail']));
    final embedId = _embedId(_string(payload['embedUrl']));
    final qualities = state == RumbleState.live && requireMedia ? _parseMedia(payload) : const <RumbleQuality>[];
    return RumbleRoom(
      videoKey: videoKey,
      channel: channel,
      channelName: _firstText([payload['channelName'], channel]),
      title: _firstText([payload['title'], payload['channelName'], channel]),
      description: _string(payload['description']),
      cover: cover,
      avatar: cover,
      category: _string(payload['category']),
      followers: RumbleApi.parseAudience(_string(payload['followers'])),
      currentViewers: RumbleApi.parseAudience(_string(payload['currentViewers'])),
      totalViews: _integer(payload['totalViews']),
      state: state,
      embedId: embedId,
      qualities: qualities,
    );
  }

  static List<RumbleQuality> _parseMedia(Map<String, dynamic> payload) {
    final masterUrl = _string(payload['masterUrl']);
    final playlist = _string(payload['playlist']);
    final master = Uri.tryParse(masterUrl);
    if (master == null ||
        master.scheme != 'https' ||
        master.userInfo.isNotEmpty ||
        !const {'rumble.com', 'www.rumble.com'}.contains(master.host.toLowerCase()) ||
        !RegExp(r'^/live-hls(?:-dvr)?/[A-Za-z0-9_-]+/playlist\.m3u8$').hasMatch(master.path)) {
      throw const RumbleException(RumbleFailure.schema);
    }
    return parseMaster(playlist);
  }

  @visibleForTesting
  static List<RumbleQuality> parseMaster(String playlist) {
    if (playlist.length > 512 * 1024 || !playlist.trimLeft().startsWith('#EXTM3U')) {
      throw const RumbleException(RumbleFailure.schema);
    }
    final lines = const LineSplitter().convert(playlist);
    if (lines.length > 1000) throw const RumbleException(RumbleFailure.schema);
    final qualities = <RumbleQuality>[];
    final ids = <String>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final attributes = _attributes(line.substring('#EXT-X-STREAM-INF:'.length));
      String? rawUrl;
      while (++index < lines.length) {
        final candidate = lines[index].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#')) break;
        rawUrl = candidate;
        break;
      }
      if (rawUrl == null) throw const RumbleException(RumbleFailure.schema);
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          !uri.path.toLowerCase().endsWith('.m3u8') ||
          !_isMediaHost(uri.host)) {
        throw const RumbleException(RumbleFailure.schema);
      }
      final resolution = RegExp(r'^(\d{2,5})x(\d{2,5})$').firstMatch(attributes['RESOLUTION'] ?? '');
      final width = int.tryParse(resolution?.group(1) ?? '') ?? 0;
      final height = int.tryParse(resolution?.group(2) ?? '') ?? 0;
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
      final name = (attributes['NAME'] ?? '').trim();
      final label = name.isNotEmpty
          ? name
          : height > 0
          ? '${height}p'
          : bandwidth > 0
          ? '${(bandwidth / 1000).round()} kbps'
          : 'Variant ${qualities.length + 1}';
      final id = height > 0 ? 'hls:${height}p' : 'hls:${bandwidth > 0 ? bandwidth : qualities.length + 1}';
      if (!ids.add(id)) continue;
      qualities.add(
        RumbleQuality(
          id: id,
          label: '$label · HLS',
          sort: height * 10000000 + bandwidth + width,
          url: uri.replace(fragment: ''),
        ),
      );
    }
    if (qualities.isEmpty) throw const RumbleException(RumbleFailure.mediaUnavailable);
    qualities.sort((left, right) {
      final rank = right.sort.compareTo(left.sort);
      return rank != 0 ? rank : left.id.compareTo(right.id);
    });
    return List.unmodifiable(qualities);
  }

  static Map<String, String> _attributes(String raw) {
    final attributes = <String, String>{};
    for (final match in RegExp(r'(?:^|,)([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(raw)) {
      var value = match.group(2) ?? '';
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      attributes[match.group(1)!] = value;
    }
    return attributes;
  }

  static bool _isMediaHost(String host) {
    final value = host.toLowerCase();
    return value == 'rumble.cloud' ||
        value.endsWith('.rumble.cloud') ||
        value == 'rmbl.ws' ||
        value.endsWith('.rmbl.ws');
  }

  static String _channelFromPath(String raw) {
    final segments = Uri(path: raw).pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length != 2 || !const {'c', 'user'}.contains(segments.first.toLowerCase())) return '';
    return RumbleLink.parseChannel('https://rumble.com/${segments.first}/${segments[1]}') ?? '';
  }

  static String _embedId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || !const {'rumble.com', 'www.rumble.com'}.contains(uri.host)) return '';
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length != 2 || segments.first.toLowerCase() != 'embed') return '';
    return RegExp(r'^v[0-9a-z]+$', caseSensitive: false).hasMatch(segments[1]) ? segments[1].toLowerCase() : '';
  }

  static String _image(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    return _isMediaHost(uri.host) || const {'rumble.com', 'www.rumble.com'}.contains(uri.host.toLowerCase())
        ? uri.toString()
        : '';
  }

  static int? _integer(Object? value) {
    final result = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    return result != null && result >= 0 && result <= 0x7fffffff ? result : null;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    throw const RumbleException(RumbleFailure.schema);
  }

  static String _string(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const RumbleException(RumbleFailure.schema);
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length > 65536) throw const RumbleException(RumbleFailure.schema);
    return text;
  }
}
