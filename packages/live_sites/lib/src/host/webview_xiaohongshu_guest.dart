import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:webview_all/webview_all.dart';

/// The finite browser operation, isolated from the WebView plugin for testing.
abstract interface class XiaohongshuGuestBrowser {
  /// Loads the public [page], observes only read-only visitor traffic and
  /// runs [script]. Cancellation, failure and success all dispose the page.
  Future<Object?> run({required Uri page, required String script, CancelToken? cancel});

  /// Opens the same read-only visitor visit on the public [page] and keeps
  /// it for further scripts ([XiaohongshuKeptGuestPage.run]) until
  /// [XiaohongshuKeptGuestPage.release], so a burst of directory pages —
  /// the feed's pagination — loads the site once instead of once per page.
  Future<XiaohongshuKeptGuestPage> keep({required Uri page, CancelToken? cancel});
}

/// One kept visitor page: the loaded public page with its captured signer,
/// answering further scripts without a reload until it is released.
abstract interface class XiaohongshuKeptGuestPage {
  /// The public page this kept visit loaded.
  Uri get page;

  /// Runs [script] on the kept page; the read-only contract of
  /// [XiaohongshuGuestBrowser.run] applies unchanged.
  Future<Object?> run({required String script, CancelToken? cancel});

  /// Closes the page; further runs fail.
  Future<void> release();
}

/// Anonymous directory and RWP bootstrap. A browser page exists for one
/// request or one kept burst and is closed as soon as it is no longer the
/// page a request needs; playback and subsequent chat use the normal native
/// transports.
final class WebViewXiaohongshuGuest implements XiaohongshuGuest {
  /// Creates the visitor client. It never reads the account's cookie stores
  /// or signed-in state.
  new({required this.route, XiaohongshuGuestBrowser? browser, DateTime Function()? now})
    : browser = browser ?? const OffscreenXiaohongshuGuestBrowser(),
      _now = now ?? DateTime.now;

  /// Whether this device can run a short-lived visitor page at all.
  ///
  /// webview_all's own runtime capability: the same check
  /// `OffscreenWebViewSession.create` performs, asked without building a
  /// controller first. The composition root consults this before wiring the
  /// guest into the site, so a host without an offscreen browser keeps the
  /// sign-in-only directory instead of failing at the first open.
  static bool get isAvailable => WebViewPlatform.instance?.supportsOffscreenWebViews ?? false;

  /// The proxy route in force right now (`proxySettingsProvider`'s answer,
  /// read per request like the other seams).
  ///
  /// The visitor page runs on webview_all, which has no proxy override: its
  /// traffic follows the operating system's own proxy settings, which the
  /// direct and system routes already describe. An explicit in-app HTTP
  /// proxy would be bypassed by the page, so a configured one refuses the
  /// visitor instead of leaking traffic past it (the reference passed the
  /// rule to an Android-only WebView proxy scope; none exists here).
  final ProxyRoute Function() route;

  /// The page implementation: one visit per request, or one kept page per
  /// burst of requests that name the same public page.
  final XiaohongshuGuestBrowser browser;
  final DateTime Function() _now;
  XiaohongshuPushIdentity? _identity;
  DateTime? _identityAt;

  /// The kept visitor page and when its burst began. One page serves every
  /// request naming the same public page — the directory's pagination — so
  /// a load-more costs one signed fetch instead of a full site reload, and
  /// a page another page replaces or that ages out is closed at once.
  XiaohongshuKeptGuestPage? _kept;
  DateTime? _keptAt;

  /// Requests serialize on the kept page: the site's signer lives in one
  /// JavaScript context, and concurrent scripts would race its capture.
  Future<void> _chain = Future.value();

  Future<Object?> _run(Uri page, String script, CancelToken? cancel) async {
    if (cancel?.isCancelled ?? false) throw const CancelledFailure();
    final done = _chain.then((_) => _runOnKept(page, script, cancel));
    _chain = done.then<void>((_) {}, onError: (Object _) {});
    return await done;
  }

  Future<Object?> _runOnKept(Uri page, String script, CancelToken? cancel) async {
    var kept = _kept;
    if (kept != null) {
      final age = _keptAt == null ? null : _now().difference(_keptAt!);
      final stale = kept.page != page || (age != null && !age.isNegative && age >= _keepTtl);
      if (stale) {
        _kept = null;
        _keptAt = null;
        unawaited(kept.release());
        kept = null;
      }
    }
    // Whether this call opened the page itself: a page reused from an
    // earlier burst can have died since the last visit, and that failure
    // retries once on a fresh page — a fresh page's own failure is the
    // environment's answer and stands as thrown.
    final reused = kept != null;
    if (kept == null) {
      final opening = browser.keep(page: page, cancel: cancel);
      try {
        kept = await opening.timeout(_openTimeout);
      } on _Cancelled {
        unawaited(opening.then<void>((page) => page.release(), onError: (Object _) {}));
        throw const CancelledFailure();
      } on TimeoutException catch (error) {
        unawaited(opening.then<void>((page) => page.release(), onError: (Object _) {}));
        _noteIssue(error, 'opening the visitor page');
        throw const TimeoutFailure('the Xiaohongshu visitor page took too long');
      } on CancelledFailure {
        rethrow;
      } on Object catch (error) {
        unawaited(opening.then<void>((page) => page.release(), onError: (Object _) {}));
        _noteIssue(error, 'opening the visitor page');
        throw _visitFailure(error);
      }
      _kept = kept;
      _keptAt = _now();
    }
    final answer = kept.run(script: script, cancel: cancel);
    try {
      final value = await Future.any([
        answer.timeout(_visitTimeout),
        if (cancel != null) cancel.whenCancel.then<Object?>((_) => throw const _Cancelled()),
      ]);
      if (cancel?.isCancelled ?? false) throw const CancelledFailure();
      // A busy burst keeps its page: the TTL slides with the last answer.
      _keptAt = _now();
      return value;
    } on _Cancelled {
      unawaited(answer.then<void>((_) {}, onError: (Object _) {}));
      throw const CancelledFailure();
    } on TimeoutException catch (error) {
      // A stuck page is dropped, so the next request opens a fresh one.
      unawaited(answer.then<void>((_) {}, onError: (Object _) {}));
      await _dropKept();
      if (reused) return await _runOnKept(page, script, cancel);
      _noteIssue(error, 'running the visitor script');
      throw const TimeoutFailure('the Xiaohongshu visitor page took too long');
    } on CancelledFailure {
      rethrow;
    } on Object catch (error) {
      unawaited(answer.then<void>((_) {}, onError: (Object _) {}));
      await _dropKept();
      if (reused) return await _runOnKept(page, script, cancel);
      _noteIssue(error, 'running the visitor script');
      throw _visitFailure(error);
    }
  }

  /// Names the failing stage and the error's type, never its message: the
  /// plugin's own text can carry page content or credentials, and the
  /// visitor's diagnostics stay fixed — the console gets the shape only.
  void _noteIssue(Object error, String stage) {
    debugPrint('xhs guest: ${error.runtimeType} while $stage');
  }

  /// The visit scripts' own refusal words. They are fixed strings with no
  /// page content or credentials, so they may surface; a plugin error that
  /// carries none keeps the generic text with the error's type alone.
  static const List<String> _visitRefusals = [
    'Visitor directory unavailable',
    'Visitor directory refused',
    'Visitor signer failed',
    'Visitor response too large',
    'Visitor chat unavailable',
    'Visitor handshake refused',
  ];

  /// The failure a visit's error maps to: the script's own refusal word
  /// when it carries one — the site not serving the visitor feed, refusing
  /// the signed fetch, a broken signer, refusing the push handshake — and
  /// the generic text plus the error's type for everything else, so the
  /// notice says which layer failed without quoting plugin text.
  Exception _visitFailure(Object error) {
    final text = error.toString();
    for (final refusal in _visitRefusals) {
      if (text.contains(refusal)) {
        return XiaohongshuFailure(XiaohongshuFailureKind.network, 'the visitor page said: $refusal');
      }
    }
    return ConnectFailure('the Xiaohongshu visitor page failed (${error.runtimeType})');
  }

  Future<void> _dropKept() async {
    final kept = _kept;
    _kept = null;
    _keptAt = null;
    await kept?.release();
  }

  /// One full visitor visit that always closes its page: the identity
  /// bootstrap's shape. The site's own RWP socket lives in that page, and
  /// it must not stay open to compete with the app's push socket for the
  /// same visitor seat — the identity cache, not the page, serves repeats.
  Future<Object?> _runOneShot(Uri page, String script, CancelToken? cancel) async {
    if (cancel?.isCancelled ?? false) throw const CancelledFailure();
    final run = browser.run(page: page, script: script, cancel: cancel);
    try {
      final value = await Future.any([
        run.timeout(_visitTimeout),
        if (cancel != null) cancel.whenCancel.then<Object?>((_) => throw const _Cancelled()),
      ]);
      if (cancel?.isCancelled ?? false) throw const CancelledFailure();
      return value;
    } on _Cancelled {
      // The page still finishes closing itself; its late result is dropped.
      unawaited(run.then<void>((_) {}, onError: (Object _) {}));
      throw const CancelledFailure();
    } on TimeoutException catch (error) {
      unawaited(run.then<void>((_) {}, onError: (Object _) {}));
      _noteIssue(error, 'running the visitor script');
      throw const TimeoutFailure('the Xiaohongshu visitor page took too long');
    } on CancelledFailure {
      rethrow;
    } on Object catch (error) {
      unawaited(run.then<void>((_) {}, onError: (Object _) {}));
      _noteIssue(error, 'running the visitor script');
      throw _visitFailure(error);
    }
  }

  /// The open's budget: the public page must answer its load in this.
  static const Duration _openTimeout = Duration(seconds: 30);

  /// The plugin-side budget for one script execution; above the Dart-side
  /// [_visitTimeout] so the visitor's own accounting decides the wait.
  static const Duration _scriptBudget = Duration(seconds: 60);

  /// The script's budget: the page may still be settling, and the script
  /// itself waits for the site's own feed traffic before signing — a slow
  /// load must not eat the whole window.
  static const Duration _visitTimeout = Duration(seconds: 45);

  /// How long a kept visitor page stays open between requests.
  static const Duration _keepTtl = Duration(minutes: 4);

  Future<String> _request(String path, CancelToken? cancel) async {
    final value = await _run(Uri.parse('https://www.xiaohongshu.com/livelist'), requestScript(path), cancel);
    if (value is! String || value.length > XiaohongshuEndpoints.responseLimit) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'Invalid visitor response');
    }
    return value;
  }

  @override
  Future<String> categories({CancelToken? cancel}) => _request('/api/sns/red/live/web/feed/category', cancel);

  @override
  Future<String> directory({required String category, required String cursor, CancelToken? cancel}) {
    if (!RegExp(r'^\d{1,8}$').hasMatch(category) || cursor.isEmpty || cursor.length > 128) {
      throw ArgumentError('Invalid directory request');
    }
    final query =
        'cursor_score=${Uri.encodeComponent(cursor)}&source=13&category=${Uri.encodeComponent(category)}&pre_source=&extra_info=%7B%22image_formats%22:[%22jpg%22,%22webp%22,%22avif%22]%7D&size=27';
    return _request('/api/sns/red/live/web/feed/v1/squarefeed?$query', cancel);
  }

  @override
  Future<XiaohongshuPushIdentity> pushIdentity(String roomId, {bool refresh = false, CancelToken? cancel}) async {
    if (!XiaohongshuEndpoints.isRoomId(roomId)) throw ArgumentError.value(roomId, 'roomId');
    if (cancel?.isCancelled ?? false) throw const CancelledFailure();
    if (refresh) {
      _identity = null;
      _identityAt = null;
    }
    final kept = _identity;
    if (kept != null && _identityAt != null) {
      final age = _now().difference(_identityAt!);
      if (!age.isNegative && age < const Duration(minutes: 5)) return kept;
    }
    final value = await _runOneShot(XiaohongshuEndpoints.roomUrl(roomId), identityScript, cancel);
    if (value is! Map) throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'Missing visitor identity');
    String field(String key) {
      final item = value[key];
      if (item is! String || item.isEmpty || item.length > 4096) {
        throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'Incomplete visitor identity');
      }
      return item;
    }

    final identity = XiaohongshuPushIdentity(
      sid: field('sid'),
      uid: field('uid'),
      deviceId: field('deviceId'),
      fingerprint: field('fingerprint'),
      userAgent: field('userAgent'),
    );
    _identityAt = _now();
    return _identity = identity;
  }

  /// Uses the currently served website signer; no copied or hard-coded
  /// signature algorithm. Only the two public directory endpoints qualify.
  @visibleForTesting
  static String requestScript(String path) {
    final uri = Uri.parse(path);
    if (uri.hasScheme ||
        uri.hasAuthority ||
        !const ['/api/sns/red/live/web/feed/category', '/api/sns/red/live/web/feed/v1/squarefeed'].contains(uri.path)) {
      throw ArgumentError.value(path, 'path');
    }
    return '''
const path = ${jsonEncode(path)};
for (let n=0; n<400; n++) {
  if (typeof window._webmsxyw === 'function') {
    // The page's own signer is enough for the public category and directory
    // endpoints. The captured x-s-common (when the page has made a feed
    // request) rides along, but a page that never does — the current list
    // renders its first screen server-side — must not block the request.
    const s = window.__pureLiveXhs;
    let headers;
    try {
      headers = Object.assign({}, s && s.headers ? s.headers : {}, window._webmsxyw(path));
    } catch (e) {
      throw new Error('Visitor signer failed');
    }
    const r = await fetch('https://live-room.xiaohongshu.com'+path, {headers, credentials:'include'});
    if (r.status !== 200) throw new Error('Visitor directory refused');
    const body = await r.text();
    if (body.length > 2097152) throw new Error('Visitor response too large');
    return body;
  }
  await new Promise(resolve=>setTimeout(resolve,100));
}
throw new Error('Visitor directory unavailable');
''';
  }

  /// Only an acknowledged visitor handshake is returned. The page never
  /// sends a test comment, reaction, follow or account request on our behalf.
  @visibleForTesting
  static const String identityScript = '''
for (let n=0; n<400; n++) {
  const s=window.__pureLiveXhs;
  if(s && s.identity) return s.identity;
  if(s && s.refused) throw new Error('Visitor handshake refused');
  await new Promise(resolve=>setTimeout(resolve,100));
}
throw new Error('Visitor chat unavailable');
''';

  /// Observes the site's own feed headers and RWP auth ack, keeping them in
  /// the ephemeral page. No general HTTP or account bridge exists.
  @visibleForTesting
  static const String captureScript = '''
(()=>{
  if(window.__pureLiveXhs)return;
  const state=window.__pureLiveXhs={};
  const wanted=k=>['x-s-common','xy-common-params','accept'].includes(k.toLowerCase());
  const feed=url=>{try{const u=new URL(url,location.href);return u.hostname==='live-room.xiaohongshu.com'&&u.pathname==='/api/sns/red/live/web/feed/v1/squarefeed';}catch{return false;}};
  const save=(url,headers)=>{
    if(!feed(url))return;
    const h={};new Headers(headers).forEach((v,k)=>{if(wanted(k))h[k]=v;});
    if(h['x-s-common'])state.headers=h;
  };
  const X=XMLHttpRequest.prototype,open=X.open,set=X.setRequestHeader,send=X.send;
  X.open=function(method,url,...rest){this.__plUrl=String(url);this.__plHeaders={};return open.call(this,method,url,...rest);};
  X.setRequestHeader=function(k,v){if(wanted(String(k)))this.__plHeaders[k]=String(v);return set.call(this,k,v);};
  X.send=function(...args){save(this.__plUrl,this.__plHeaders);return send.apply(this,args);};
  const fetch=window.fetch;
  window.fetch=function(input,options){save(typeof input==='string'?input:input.url,options?.headers||input?.headers);return fetch.apply(this,arguments);};
  const Socket=window.WebSocket;
  window.WebSocket=class extends Socket {
    constructor(...args){
      super(...args);
      if(String(args[0])!=='wss://apppush-rws.xiaohongshu.com/rwp')return;
      this.__plRwp=true;
      this.addEventListener('message',event=>{
        try{const f=JSON.parse(event.data);if(f.m!==this.__plAuthId)return;
          if(f.b?.a?.c===0)state.identity=this.__plIdentity;else state.refused=true;
        }catch{}
      });
    }
    send(data){
      if(this.__plRwp)try{const f=JSON.parse(data),b=f.b?.d?.b;
        if(f.t===2&&f.b?.d?.s===0&&b?.appId==='xhs-pc'&&b.authInfo?.authType==='generic'){
          this.__plAuthId=f.m;
          this.__plIdentity={sid:b.authInfo.sid,uid:b.authInfo.uid,deviceId:b.deviceInfo?.deviceId,fingerprint:b.deviceInfo?.fingerprint,userAgent:navigator.userAgent};
        }
      }catch{}
      return super.send(data);
    }
  };
})();
''';
}

final class _Cancelled implements Exception {
  const new();
}

/// webview_all's offscreen session as the [XiaohongshuGuestBrowser]: a
/// full-size but short-lived visitor page per request or per kept burst,
/// deterministically released through `OffscreenWebViewSession.close`.
///
/// The reference kept Android on a dedicated-profile method channel; that
/// native half does not exist here — every platform goes through the same
/// offscreen session. There is no incognito flag in webview_all, so the page
/// shares the platform cookie jar; it only ever visits public pages and the
/// captured credentials live in its `window` object, which dies with the
/// page.
final class OffscreenXiaohongshuGuestBrowser implements XiaohongshuGuestBrowser {
  /// Creates the browser.
  const new();

  /// The desktop Chrome user agent the site's own web app expects; the
  /// reference's non-Android pages ran under the same one.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  Future<Object?> run({required Uri page, required String script, CancelToken? cancel}) async {
    final kept = await keep(page: page, cancel: cancel);
    try {
      return await kept.run(script: script, cancel: cancel);
    } finally {
      await kept.release();
    }
  }

  @override
  Future<XiaohongshuKeptGuestPage> keep({required Uri page, CancelToken? cancel}) async {
    if (cancel?.isCancelled ?? false) throw const CancelledFailure();
    final session = await OffscreenWebViewSession.create();
    final loaded = Completer<void>();
    try {
      final controller = session.controller;
      await controller.setUserAgent(_userAgent);
      // The capture script must sit in the page before the site's own
      // scripts run, so it registers before any feed request or RWP socket.
      await controller.addUserScript(const WebViewUserScript(source: WebViewXiaohongshuGuest.captureScript));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!loaded.isCompleted) loaded.complete();
          },
        ),
      );
    } on Object {
      await session.close();
      rethrow;
    }
    final opened = _open(session, page, loaded);
    if (cancel != null) {
      final answer = Future.any([
        opened,
        cancel.whenCancel.then<XiaohongshuKeptGuestPage>((_) => throw const _Cancelled()),
      ]);
      // A cancelled open releases its own page when it lands — but only
      // when the cancellation won the race: a page this call returns has
      // an owner, and releasing it under the caller left every script
      // running on a closed page.
      unawaited(
        answer.then<void>(
          (_) {},
          onError: (Object _) {
            unawaited(opened.then<void>((kept) => kept.release(), onError: (Object _) {}));
          },
        ),
      );
      return await answer;
    }
    return await opened;
  }

  static Future<XiaohongshuKeptGuestPage> _open(
    OffscreenWebViewSession session,
    Uri page,
    Completer<void> loaded,
  ) async {
    try {
      await session.controller.loadRequest(page);
    } on Object {
      await session.close();
      rethrow;
    }
    return _OffscreenXiaohongshuKeptPage(session, page, loaded);
  }
}

/// The offscreen session as a kept page: it stays open until released, and
/// every run answers on the already loaded page.
final class _OffscreenXiaohongshuKeptPage implements XiaohongshuKeptGuestPage {
  new(this._session, this.page, this._loaded);

  final OffscreenWebViewSession _session;
  final Completer<void> _loaded;

  @override
  final Uri page;

  bool _released = false;

  @override
  Future<Object?> run({required String script, CancelToken? cancel}) async {
    if (_released) throw const ConnectFailure('the Xiaohongshu visitor page is released');
    if (cancel?.isCancelled ?? false) throw const CancelledFailure();
    await _loaded.future;
    // The plugin's own default script budget is thirty seconds; the visit
    // scripts' poll may legitimately run longer, so the budget is ours.
    final answer = _session.controller.callAsyncJavaScript(script, timeout: WebViewXiaohongshuGuest._scriptBudget);
    if (cancel == null) return await answer;
    return await Future.any([answer, cancel.whenCancel.then<Object?>((_) => throw const _Cancelled())]);
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _session.close();
  }
}
