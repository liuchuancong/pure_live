import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/utils/webview_proxy_scope.dart';

import 'dailymotion_api.dart';
import 'dailymotion_link.dart';

abstract interface class DailymotionMediaResolver {
  Future<List<DailymotionQuality>> resolve(String videoId, {bool refresh = false});
}

/// Uses Dailymotion's public embedded player to obtain the current signed HLS
/// master. The CDN rejects a plain native request for the master in some
/// regions, while rendition URLs returned inside that player session remain
/// valid for native playback and recording.
final class DailymotionBrowserMediaResolver implements DailymotionMediaResolver {
  static const Duration cacheDuration = Duration(seconds: 45);
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  static Future<void> _evaluationTail = Future<void>.value();

  final Map<String, ({DateTime at, List<DailymotionQuality> qualities})> _cache = {};
  final Map<String, Future<List<DailymotionQuality>>> _inFlight = {};

  @override
  Future<List<DailymotionQuality>> resolve(String videoId, {bool refresh = false}) {
    if (!isSupported) throw const DailymotionException(DailymotionFailure.mediaUnavailable);
    final id = DailymotionLink.requireVideoId(videoId);
    final cached = _cache[id];
    if (!refresh && cached != null && DateTime.now().difference(cached.at) < cacheDuration) {
      return Future.value(cached.qualities);
    }
    final active = _inFlight[id];
    if (active != null) return active;
    final request = _serializedResolve(id).then((qualities) {
      _cache[id] = (at: DateTime.now(), qualities: qualities);
      return qualities;
    });
    _inFlight[id] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[id], request)) _inFlight.remove(id);
    });
  }

  static Future<List<DailymotionQuality>> _serializedResolve(String videoId) async {
    final predecessor = _evaluationTail;
    final release = Completer<void>();
    _evaluationTail = release.future;
    try {
      await predecessor;
      return await WebViewProxyScope.run(() => _resolveExclusive(videoId));
    } finally {
      release.complete();
    }
  }

  static Future<List<DailymotionQuality>> _resolveExclusive(String videoId) async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageCompleter = Completer<void>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://geo.dailymotion.com/player.html?video=${Uri.encodeQueryComponent(videoId)}'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: true,
          transparentBackground: true,
          mediaPlaybackRequiresUserGesture: false,
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
      await pageCompleter.future.timeout(const Duration(seconds: 20));
      final result = await controller
          .callAsyncJavaScript(functionBody: buildMediaScript(videoId))
          .timeout(const Duration(seconds: 30));
      if (result == null || result.error != null || result.value is! String) {
        throw const DailymotionException(DailymotionFailure.mediaUnavailable);
      }
      return parseMediaPayload(videoId, result.value! as String);
    } on DailymotionException {
      rethrow;
    } catch (_) {
      throw const DailymotionException(DailymotionFailure.mediaUnavailable);
    } finally {
      if (webView?.isRunning() == true) await webView!.dispose();
    }
  }

  @visibleForTesting
  static String buildMediaScript(String videoId) {
    final encodedId = jsonEncode(DailymotionLink.requireVideoId(videoId));
    return '''
const videoId = $encodedId;
const deadline = Date.now() + 18000;
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const masterPrefix = `https://cdndirector.dailymotion.com/cdn/live/video/$videoId.m3u8`;
let masterUrl = '';
while (!masterUrl && Date.now() < deadline) {
  masterUrl = performance.getEntriesByType('resource')
    .map(entry => String(entry.name || ''))
    .find(url => url.startsWith(masterPrefix)) || '';
  if (!masterUrl) await sleep(100);
}
if (!masterUrl) throw new Error('Dailymotion signed master was not observed');
const response = await fetch(masterUrl, {credentials: 'omit', cache: 'no-store'});
if (!response.ok) throw new Error('Dailymotion signed master returned ' + response.status);
const playlist = await response.text();
if (!playlist.startsWith('#EXTM3U')) throw new Error('Dailymotion master is not HLS');
return JSON.stringify({masterUrl, playlist});
''';
  }

  @visibleForTesting
  static List<DailymotionQuality> parseMediaPayload(String rawVideoId, String rawPayload) {
    final videoId = DailymotionLink.requireVideoId(rawVideoId);
    if (rawPayload.length > 768 * 1024) throw const DailymotionException(DailymotionFailure.schema);
    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) throw const DailymotionException(DailymotionFailure.schema);
      payload = decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    final masterUrl = payload['masterUrl'];
    final playlist = payload['playlist'];
    if (masterUrl is! String || playlist is! String) {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    final master = Uri.tryParse(masterUrl);
    if (master == null ||
        master.scheme != 'https' ||
        master.userInfo.isNotEmpty ||
        master.host.toLowerCase() != 'cdndirector.dailymotion.com' ||
        master.path != '/cdn/live/video/$videoId.m3u8') {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    return parseMaster(videoId, playlist);
  }

  @visibleForTesting
  static List<DailymotionQuality> parseMaster(String rawVideoId, String playlist) {
    final videoId = DailymotionLink.requireVideoId(rawVideoId);
    if (playlist.length > 512 * 1024 || !playlist.trimLeft().startsWith('#EXTM3U')) {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    final lines = const LineSplitter().convert(playlist);
    if (lines.length > 1000) throw const DailymotionException(DailymotionFailure.schema);
    final variants = <DailymotionQuality>[];
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
      if (rawUrl == null) throw const DailymotionException(DailymotionFailure.schema);
      final parsed = Uri.tryParse(rawUrl);
      if (parsed == null ||
          parsed.scheme != 'https' ||
          parsed.userInfo.isNotEmpty ||
          !parsed.path.toLowerCase().endsWith('.m3u8')) {
        throw const DailymotionException(DailymotionFailure.schema);
      }
      final host = parsed.host.toLowerCase();
      if (host != 'dmcdn.net' && !host.endsWith('.dmcdn.net')) {
        throw const DailymotionException(DailymotionFailure.schema);
      }
      if (!parsed.pathSegments.contains(videoId)) throw const DailymotionException(DailymotionFailure.identity);
      final resolution = RegExp(r'^(\d{2,5})x(\d{2,5})$').firstMatch(attributes['RESOLUTION'] ?? '');
      final width = int.tryParse(resolution?.group(1) ?? '') ?? 0;
      final height = int.tryParse(resolution?.group(2) ?? '') ?? 0;
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
      final frameRate = double.tryParse(attributes['FRAME-RATE'] ?? '') ?? 0;
      final rendition = (attributes['NAME'] ?? '').trim();
      final stableName = rendition.isNotEmpty
          ? rendition
          : height > 0
          ? '${height}p'
          : bandwidth > 0
          ? '${bandwidth}bps'
          : 'variant-${variants.length + 1}';
      final stableId = 'hls:${stableName.toLowerCase()}';
      if (!ids.add(stableId)) continue;
      variants.add(
        DailymotionQuality(
          id: stableId,
          label: '$stableName · HLS',
          sort: height * 10000000 + frameRate.round() * 100000 + bandwidth + width,
          url: parsed.replace(fragment: ''),
        ),
      );
    }
    if (variants.isEmpty) throw const DailymotionException(DailymotionFailure.mediaUnavailable);
    variants.sort((left, right) {
      final rank = right.sort.compareTo(left.sort);
      return rank != 0 ? rank : left.id.compareTo(right.id);
    });
    return List.unmodifiable(variants);
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
}
