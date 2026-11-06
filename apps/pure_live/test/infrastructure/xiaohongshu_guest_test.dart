import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart' show XiaohongshuFailure, XiaohongshuFailureKind;
import 'package:live_sites/webview_guest.dart' show WebViewXiaohongshuGuest, XiaohongshuGuestBrowser;

final class _Browser implements XiaohongshuGuestBrowser {
  final calls = <({Uri page, String script, CancelToken? cancel})>[];
  Object? answer = '{}';
  @override
  Future<Object?> run({required Uri page, required String script, CancelToken? cancel}) async {
    calls.add((page: page, script: script, cancel: cancel));
    if (answer case final Completer<Object?> pending) return await pending.future;
    if (answer case final Exception error) throw error;
    return answer;
  }
}

WebViewXiaohongshuGuest _guest(_Browser browser, {ProxyRoute Function()? route, DateTime Function()? now}) =>
    WebViewXiaohongshuGuest(route: route ?? () => const DirectRoute(), browser: browser, now: now);

void main() {
  test('the visitor page exists only where an offscreen browser can run', () {
    // No plugin registrant in a plain test: no browser, no guest wiring.
    expect(WebViewXiaohongshuGuest.isAvailable, isFalse);
  });

  test('only read-only public directory paths enter the browser', () async {
    final browser = _Browser();
    final guest = _guest(browser);
    await guest.categories();
    await guest.directory(category: '6', cursor: '9.75');
    expect(browser.calls.every((c) => c.page.toString() == 'https://www.xiaohongshu.com/livelist'), isTrue);
    expect(browser.calls[0].script, contains('/api/sns/red/live/web/feed/category'));
    expect(browser.calls[1].script, contains('cursor_score=9.75&source=13&category=6'));
    expect(browser.calls[1].script, isNot(contains('synthetic-credential')));
    expect(
      () => WebViewXiaohongshuGuest.requestScript('https://example.invalid/api/sns/red/live/web/feed/category'),
      throwsArgumentError,
    );
    expect(() => WebViewXiaohongshuGuest.requestScript('/api/sns/web/v1/comment/post'), throwsArgumentError);
    expect(() => guest.directory(category: '../bad', cursor: '0'), throwsArgumentError);
  });

  test('cancel before creation avoids a browser; cancelled result is suppressed', () async {
    final browser = _Browser();
    final guest = _guest(browser);
    final cancel = CancelToken()..cancel();
    await expectLater(guest.categories(cancel: cancel), throwsA(isA<CancelledFailure>()));
    expect(browser.calls, isEmpty);
    final pending = Completer<Object?>();
    browser.answer = pending;
    final current = CancelToken();
    final response = guest.categories(cancel: current);
    current.cancel();
    pending.complete('{}');
    await expectLater(response, throwsA(isA<CancelledFailure>()));
    expect(browser.calls.single.cancel, same(current));
  });

  test('an explicit in-app proxy refuses the visitor instead of being bypassed', () async {
    final browser = _Browser();
    final guest = _guest(browser, route: () => const HttpProxyRoute(host: '::1'));
    await expectLater(guest.categories(), throwsA(isA<ProtocolFailure>()));
    expect(browser.calls, isEmpty);
    // The direct and system routes run: the page follows the OS proxy on its
    // own, which is what those routes already describe.
    final system = _guest(_Browser(), route: () => const SystemProxyRoute());
    await expectLater(system.categories(), completion('{}'));
  });

  test('identity is memory-only, reused briefly, renewed on refusal and expiry', () async {
    var now = DateTime.utc(2026, 11, 4);
    final browser = _Browser()
      ..answer = {
        'sid': 'synthetic-sid',
        'uid': 'synthetic-guest',
        'deviceId': 'synthetic-device',
        'fingerprint': 'synthetic-fingerprint',
        'userAgent': 'Synthetic browser',
      };
    final guest = _guest(browser, now: () => now);
    final first = await guest.pushIdentity('570000000000000017');
    expect(first.sid, 'synthetic-sid');
    expect(await guest.pushIdentity('570000000000000018'), same(first));
    expect(browser.calls.length, 1);
    await guest.pushIdentity('570000000000000018', refresh: true);
    expect(browser.calls.length, 2);
    now = now.add(const Duration(minutes: 6));
    await guest.pushIdentity('570000000000000018');
    expect(browser.calls.length, 3);
    expect(first.toString(), isNot(contains('synthetic-sid')));
    expect(browser.calls.first.page.path, '/livestream/570000000000000017');
  });

  test('missing identity and oversized results fail without exposing raw credentials', () async {
    final browser = _Browser()..answer = {'sid': 'synthetic-private-sid'};
    final guest = _guest(browser);
    await expectLater(
      guest.pushIdentity('570000000000000017'),
      throwsA(predicate<Object>((e) => !e.toString().contains('synthetic-private-sid'))),
    );
    browser.answer = Exception('synthetic-private-sid');
    await expectLater(
      guest.categories(),
      throwsA(
        isA<ConnectFailure>().having((e) => e.toString(), 'diagnostic', isNot(contains('synthetic-private-sid'))),
      ),
    );
    browser.answer = 'x' * (2 * 1024 * 1024 + 1);
    await expectLater(
      guest.categories(),
      throwsA(isA<XiaohongshuFailure>().having((e) => e.kind, 'kind', XiaohongshuFailureKind.apiChanged)),
    );
  });
}
