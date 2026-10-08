// Module: lib/src/extension_cookie_store.dart
// Purpose: Per-extension cookie storage gated by the cookie permission, so no source sees another's jar.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 15 ("插件 MUST NOT 直接访问全局 Cookie 数据库") and
// docs/contracts/platform-models.md section 12. Isolation is the point: one ExtensionId is one jar, and a
// request without the cookie permission cannot read or write even its own.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'permission_manager.dart';

/// A cookie operation the platform refused.
final class CookieAccessException implements Exception {
  const CookieAccessException(this.error);

  final PlatformErrorInfo error;

  String get code => error.code;

  @override
  String toString() => 'CookieAccessException(${error.code}: ${error.message})';
}

/// Where a jar is kept.
///
/// The whole jar is read and written as one unit on purpose: a jar is small, and replacing it atomically
/// avoids a torn record when a runtime is stopped mid-refresh.
abstract interface class CookieJar {
  Future<List<Cookie>> read(ExtensionId extensionId);

  Future<void> write(ExtensionId extensionId, List<Cookie> cookies);
}

/// Jar held in process memory; a persisted implementation replaces it without any caller changing.
final class InMemoryCookieJar implements CookieJar {
  final Map<ExtensionId, List<Cookie>> _jars = <ExtensionId, List<Cookie>>{};

  @override
  Future<List<Cookie>> read(ExtensionId extensionId) async =>
      List<Cookie>.unmodifiable(_jars[extensionId] ?? const <Cookie>[]);

  @override
  Future<void> write(ExtensionId extensionId, List<Cookie> cookies) async {
    _jars[extensionId] = List<Cookie>.unmodifiable(cookies);
  }
}

/// The cookie surface an extension gets.
abstract interface class ExtensionCookieStore {
  /// The cookies that belong on a request for [uri], expired records already dropped.
  Future<List<Cookie>> cookiesFor(ExtensionId extensionId, Uri uri);

  /// Stores [cookie], replacing any record with the same name, domain and path.
  Future<void> set(ExtensionId extensionId, Cookie cookie);

  /// Drops cookies for one host, or the whole jar when [host] is omitted.
  ///
  /// Clearing needs no permission: it only takes data away, and a user pressing "log this source out" must
  /// work even after the grant was revoked.
  Future<void> clear(ExtensionId extensionId, {String? host});
}

/// An ExtensionCookieStore that asks the PermissionManager before it touches any jar.
final class PolicyBackedCookieStore implements ExtensionCookieStore {
  PolicyBackedCookieStore({required PermissionManager permissions, required CookieJar jar, DateTime Function()? clock})
    : _permissions = permissions,
      _jar = jar,
      _clock = clock ?? _utcNow;

  final PermissionManager _permissions;
  final CookieJar _jar;
  final DateTime Function() _clock;

  @override
  Future<List<Cookie>> cookiesFor(ExtensionId extensionId, Uri uri) async {
    await _require(extensionId, 'read cookies');
    final now = _clock();
    return (await _jar.read(extensionId))
        .where((cookie) => !cookie.isExpiredAt(now) && cookie.matchesUri(uri))
        .toList(growable: false);
  }

  @override
  Future<void> set(ExtensionId extensionId, Cookie cookie) async {
    await _require(extensionId, 'store cookies');
    final now = _clock();
    final current = await _jar.read(extensionId);
    final kept = current
        .where((existing) => !_sameRecord(existing, cookie) && !existing.isExpiredAt(now))
        .toList(growable: false);
    await _jar.write(extensionId, <Cookie>[...kept, cookie]);
  }

  @override
  Future<void> clear(ExtensionId extensionId, {String? host}) async {
    final current = await _jar.read(extensionId);
    if (host == null) {
      await _jar.write(extensionId, const <Cookie>[]);
      return;
    }
    await _jar.write(extensionId, current.where((cookie) => !cookie.matchesHost(host)).toList(growable: false));
  }

  Future<void> _require(ExtensionId extensionId, String what) async {
    final decision = await _permissions.check(extensionId, Permission.cookie);
    if (decision.allowed) {
      return;
    }
    throw CookieAccessException(
      PlatformErrorInfo(
        code: decision.code,
        message: '$extensionId may not $what: ${decision.reason}',
        category: PlatformErrorCategory.permission,
        recoverable: decision.state == PermissionState.unknown,
      ),
    );
  }

  static bool _sameRecord(Cookie a, Cookie b) =>
      a.name == b.name && a.domain.toLowerCase() == b.domain.toLowerCase() && a.path == b.path;

  static DateTime _utcNow() => DateTime.now().toUtc();
}
