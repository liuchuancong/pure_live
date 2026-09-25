import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/utils/webview_proxy_scope.dart';

import 'nimotv_api.dart';

abstract interface class NimoTvDirectoryResolver {
  Future<List<NimoTvRoom>> resolve();
}

/// Reads the finite public recommendation snapshot rendered by NimoTV's own
/// homepage client. The catalog is delivered over the site's WUP/WebSocket
/// session, so a headless official page is more stable than persisting binary
/// request envelopes whose routing fields change independently of the app.
class NimoTvBrowserDirectoryResolver implements NimoTvDirectoryResolver {
  static const String pageUrl = 'https://www.nimo.tv/';
  static const Duration cacheDuration = Duration(seconds: 45);

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  static Future<void> _evaluationTail = Future<void>.value();

  List<NimoTvRoom>? _cached;
  DateTime? _cachedAt;
  Future<List<NimoTvRoom>>? _inFlight;

  @override
  Future<List<NimoTvRoom>> resolve() {
    if (!isSupported) throw UnsupportedError('NimoTV browser directory resolver is not supported');
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < cacheDuration) {
      return Future.value(cached);
    }
    final active = _inFlight;
    if (active != null) return active;
    final request = _serializedResolve();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<List<NimoTvRoom>> _serializedResolve() async {
    final predecessor = _evaluationTail;
    final release = Completer<void>();
    _evaluationTail = release.future;
    try {
      await predecessor;
      final rooms = await WebViewProxyScope.run(_resolveExclusive);
      _cached = rooms;
      _cachedAt = DateTime.now();
      return rooms;
    } finally {
      release.complete();
    }
  }

  static Future<List<NimoTvRoom>> _resolveExclusive() async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageCompleter = Completer<void>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
        // A mobile WebView UA is redirected to m.nimo.tv, which has none of
        // the homepage cards the directory script reads (Android only).
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: true,
          transparentBackground: true,
          userAgent: NimoTvApi.desktopUserAgent,
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
          .callAsyncJavaScript(functionBody: buildDirectoryScript())
          .timeout(const Duration(seconds: 25));
      if (result == null || result.error != null || result.value is! String) {
        throw StateError('NimoTV browser directory returned an invalid result');
      }
      return parseDirectoryPayload(result.value! as String);
    } finally {
      if (webView?.isRunning() == true) await webView!.dispose();
    }
  }

  @visibleForTesting
  static String buildDirectoryScript() => r'''
const deadline = Date.now() + 15000;
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const clean = value => String(value || '').trim().replace(/\s+/g, ' ');
const parseAudience = value => {
  const normalized = clean(value).toLowerCase().replace(/,/g, '');
  const match = normalized.match(/^([0-9]+(?:\.[0-9]+)?)([km]?)$/);
  if (!match) return null;
  const multiplier = match[2] === 'm' ? 1000000 : match[2] === 'k' ? 1000 : 1;
  const result = Math.round(Number(match[1]) * multiplier);
  return Number.isSafeInteger(result) && result >= 0 ? result : null;
};
const readRooms = () => {
  const seen = new Set();
  const rooms = [];
  for (const card of document.querySelectorAll('.nimo-card-body')) {
    const playerId = card.querySelector('.nimo-player[id^="home-hot-"]')?.id || '';
    const idMatch = playerId.match(/^home-hot-([1-9][0-9]{0,19})$/);
    let roomId = idMatch ? idMatch[1] : '';
    const roomLink = Array.from(card.querySelectorAll('a[href]')).find(anchor => {
      try {
        const url = new URL(anchor.href, location.href);
        return url.hostname === 'www.nimo.tv' && /^\/live\/[1-9][0-9]{0,19}\/?$/.test(url.pathname);
      } catch (_) {
        return false;
      }
    });
    if (!roomId && roomLink) roomId = new URL(roomLink.href, location.href).pathname.split('/')[2] || '';
    if (!/^[1-9][0-9]{0,19}$/.test(roomId) || seen.has(roomId)) continue;
    const meta = card.querySelector('.nimo-rc_meta');
    const title = clean(meta?.querySelector('.nimo-rc_meta__title')?.textContent);
    const nickname = clean(
      meta?.querySelector('.nimo-rc_meta__nick-name')?.getAttribute('title') ||
      meta?.querySelector('.nimo-rc_meta__nick-name')?.textContent
    );
    if (!title || !nickname) continue;
    const avatar = meta?.querySelector('img')?.currentSrc || meta?.querySelector('img')?.src || '';
    const category = Array.from(meta?.querySelectorAll('.nimo-rc_meta__labels-item') || [])
      .map(element => clean(element.textContent))
      .filter(Boolean)
      .join(' / ');
    const viewerCount = parseAudience(meta?.querySelector('.nimo-rc_meta__audience .text')?.textContent);
    rooms.push({roomId, nickname, avatar, title, category, viewerCount});
    seen.add(roomId);
  }
  return rooms;
};
let rooms = readRooms();
while (!rooms.length && Date.now() < deadline) {
  await sleep(100);
  rooms = readRooms();
}
if (!rooms.length) throw new Error('NimoTV homepage returned no public rooms');
return JSON.stringify(rooms);
''';

  @visibleForTesting
  static List<NimoTvRoom> parseDirectoryPayload(String raw) {
    if (raw.length > NimoTvApi.responseLimit) throw const NimoTvException(NimoTvFailure.schema);
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    if (decoded is! List || decoded.isEmpty || decoded.length > 100) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    final seen = <String>{};
    final rooms = <NimoTvRoom>[];
    for (final value in decoded) {
      if (value is! Map) throw const NimoTvException(NimoTvFailure.schema);
      final data = value.map((key, value) => MapEntry(key.toString(), value));
      final roomId = _roomId(data['roomId']);
      if (!seen.add(roomId)) continue;
      final nickname = _requiredText(data['nickname']);
      final avatar = _image(data['avatar']);
      final title = _requiredText(data['title']);
      final category = _optionalText(data['category']);
      final viewerCount = _viewerCount(data['viewerCount']);
      rooms.add(
        NimoTvRoom(
          roomId: roomId,
          anchorId: '',
          nickname: nickname,
          avatar: avatar,
          // The homepage renders moving previews without a stable poster URL.
          // Reuse the public avatar rather than inventing a cover address.
          cover: avatar,
          title: title,
          category: category,
          viewerCount: viewerCount,
          state: NimoTvState.live,
          qualities: const [],
        ),
      );
    }
    if (rooms.isEmpty) throw const NimoTvException(NimoTvFailure.schema);
    return List.unmodifiable(rooms);
  }

  static String _roomId(Object? value) {
    final text = value is String ? value.trim() : '';
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(text)) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    return text;
  }

  static String _requiredText(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const NimoTvException(NimoTvFailure.schema);
    return text;
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const NimoTvException(NimoTvFailure.schema);
    final text = value.trim();
    if (text.length > 8192) throw const NimoTvException(NimoTvFailure.schema);
    return text;
  }

  static String _image(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    final host = uri.host.toLowerCase();
    if (!(host == 'nimo.tv' || host.endsWith('.nimo.tv') || host.endsWith('.nimostatic.tv'))) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    return uri.replace(scheme: 'https', port: null).toString();
  }

  static int? _viewerCount(Object? value) {
    if (value == null) return null;
    final number = value is int
        ? value
        : value is num && value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : null;
    if (number == null || number < 0 || number > 0x1fffffffffffff) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    return number;
  }
}
