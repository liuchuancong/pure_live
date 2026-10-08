// Module: test/cookie_store_test.dart
// Purpose: Verify cookie isolation per extension, the permission gate and the domain and expiry rules.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const String _tvbox = 'purelive.external.tvbox';
const String _lxmusic = 'purelive.external.lxmusic';
final Uri _site = Uri.parse('https://api.example.com/v1/search');

final DateTime _now = DateTime.utc(2026, 10, 8, 12);

ExtensionDescriptor _descriptor(String id) => ExtensionDescriptor(
  id: id,
  name: id,
  version: '1.0.0',
  protocol: 'test',
  type: ExtensionType.external,
  permissions: const <Permission>{Permission.cookie},
);

void main() {
  late InMemoryPermissionStore store;
  late PolicyPermissionManager permissions;
  late InMemoryCookieJar jar;
  late PolicyBackedCookieStore cookies;

  setUp(() async {
    store = InMemoryPermissionStore();
    permissions = PolicyPermissionManager(store: store, prompt: const GrantDeclaredPrompts(), clock: () => _now);
    await permissions.register(_descriptor(_tvbox));
    await permissions.register(_descriptor(_lxmusic));
    jar = InMemoryCookieJar();
    cookies = PolicyBackedCookieStore(permissions: permissions, jar: jar, clock: () => _now);
  });

  Future<void> grantCookies(String extensionId) async {
    await permissions.request(extensionId, Permission.cookie);
  }

  group('permission gate', () {
    test('test_cookiesFor_withoutTheCookiePermission_isRefused', () async {
      await expectLater(
        cookies.cookiesFor(_tvbox, _site),
        throwsA(isA<CookieAccessException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionDenied)),
      );
    });

    test('test_set_withoutTheCookiePermission_isRefused', () async {
      await expectLater(
        cookies.set(_tvbox, const Cookie(name: 'sid', value: 'v', domain: 'example.com')),
        throwsA(isA<CookieAccessException>()),
      );
      expect(await jar.read(_tvbox), isEmpty);
    });

    test('test_clear_needsNoPermission_becauseItOnlyTakesDataAway', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'v', domain: 'example.com'));
      await permissions.revoke(_tvbox, Permission.cookie);

      await cookies.clear(_tvbox);

      expect(await jar.read(_tvbox), isEmpty);
    });
  });

  group('isolation', () {
    test('test_cookiesFor_anotherExtensionCannotReadThem', () async {
      await grantCookies(_tvbox);
      await grantCookies(_lxmusic);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'tv-secret', domain: 'example.com'));

      expect(await cookies.cookiesFor(_lxmusic, _site), isEmpty);
      expect((await cookies.cookiesFor(_tvbox, _site)).single.value, 'tv-secret');
    });

    test('test_cookiesFor_subdomainReceivesTheApexCookie', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'v', domain: 'example.com'));

      expect(await cookies.cookiesFor(_tvbox, Uri.parse('https://api.example.com/')), hasLength(1));
      expect(await cookies.cookiesFor(_tvbox, Uri.parse('https://example.org/')), isEmpty);
    });
  });

  group('records', () {
    test('test_set_sameNameDomainPath_replacesTheRecord', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'old', domain: 'example.com'));
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'new', domain: 'example.com'));

      final stored = await cookies.cookiesFor(_tvbox, _site);

      expect(stored, hasLength(1));
      expect(stored.single.value, 'new');
    });

    test('test_set_differentDomainKeepsBothRecords', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'a', domain: 'example.com'));
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'b', domain: 'other.test'));

      expect(await jar.read(_tvbox), hasLength(2));
    });

    test('test_cookiesFor_expiredRecordIsDroppedOnRead', () async {
      await grantCookies(_tvbox);
      await jar.write(_tvbox, <Cookie>[
        const Cookie(name: 'fresh', value: 'v', domain: 'example.com'),
        Cookie(name: 'stale', value: 'v', domain: 'example.com', expiresAt: _now.subtract(const Duration(minutes: 1))),
      ]);

      final visible = await cookies.cookiesFor(_tvbox, _site);

      expect(visible.map((cookie) => cookie.name), <String>['fresh']);
    });

    test('test_cookiesFor_pathScopedCookieIsNotSentElsewhere', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'v', domain: 'example.com', path: '/admin'));

      expect(await cookies.cookiesFor(_tvbox, _site), isEmpty);
      expect(await cookies.cookiesFor(_tvbox, Uri.parse('https://example.com/admin/users')), hasLength(1));
    });

    test('test_clear_hostRemovesOnlyThatHost', () async {
      await grantCookies(_tvbox);
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'a', domain: 'example.com'));
      await cookies.set(_tvbox, const Cookie(name: 'sid', value: 'b', domain: 'other.test'));

      await cookies.clear(_tvbox, host: 'example.com');

      final left = await jar.read(_tvbox);
      expect(left, hasLength(1));
      expect(left.single.domain, 'other.test');
    });
  });
}
