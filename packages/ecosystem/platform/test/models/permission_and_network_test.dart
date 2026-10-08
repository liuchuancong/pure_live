// Module: test/models/permission_and_network_test.dart
// Purpose: Verify the permission, network and cookie models from docs/contracts/platform-models.md section 12.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

final Uri _target = Uri.parse('https://example.com/api/v1');

/// Redaction keeps the length so "the token was sent but empty" stays debuggable; the tests spell the
/// expected value the same way instead of hardcoding a character count.
String _hidden(String secret) => '<${secret.length} chars>';

void main() {
  group('PermissionScope', () {
    test('test_scope_allowsUri_unrestrictedScopeCoversAnyHost', () {
      expect(PermissionScope.unrestricted.allowsUri(Uri.parse('https://example.com/a')), isTrue);
      expect(PermissionScope.unrestricted.isHostLimited, isFalse);
    });

    test('test_scope_allowsUri_exactHostOnlyMatchesThatHost', () {
      const scope = PermissionScope(hosts: <String>{'api.example.com'});
      expect(scope.allowsUri(Uri.parse('https://api.example.com/v1')), isTrue);
      expect(scope.allowsUri(Uri.parse('https://example.com/')), isFalse);
      expect(scope.allowsUri(Uri.parse('https://cdn.example.com/')), isFalse);
    });

    test('test_scope_allowsUri_wildcardCoversSubdomainsButNotTheApex', () {
      const scope = PermissionScope(hosts: <String>{'*.example.com'});
      expect(scope.allowsUri(Uri.parse('https://a.example.com/')), isTrue);
      expect(scope.allowsUri(Uri.parse('https://deep.a.example.com/')), isTrue);
      expect(scope.allowsUri(Uri.parse('https://example.com/')), isFalse);
      expect(scope.allowsUri(Uri.parse('https://notexample.com/')), isFalse);
    });

    test('test_scope_allowsUri_hostMatchingIgnoresCase', () {
      const scope = PermissionScope(hosts: <String>{'API.Example.com'});
      expect(scope.allowsUri(Uri.parse('https://api.example.com/')), isTrue);
    });

    test('test_scope_allowsUri_pathPrefixLimitsTheGrant', () {
      const scope = PermissionScope(hosts: <String>{'example.com'}, paths: <String>{'/api/'});
      expect(scope.allowsUri(Uri.parse('https://example.com/api/v1')), isTrue);
      expect(scope.allowsUri(Uri.parse('https://example.com/admin')), isFalse);
      expect(scope.allowsUri(Uri.parse('https://example.com')), isFalse);
    });

    test('test_scope_allowsUri_hostlessUri_isRefused', () {
      expect(PermissionScope.unrestricted.allowsUri(Uri.parse('file:///tmp/a.json')), isFalse);
    });

    test('test_scope_jsonRoundTrip_preservesBoundsAndToleratesUnknownKeys', () {
      const scope = PermissionScope(
        hosts: <String>{'example.com'},
        paths: <String>{'/api/'},
        constraints: <String, Object?>{'maxResponseBytes': 4194304},
      );

      final decoded = PermissionScope.fromJson(<String, Object?>{...scope.toJson(), 'futureField': 'ignored'});

      expect(decoded, scope);
    });

    test('test_scope_equality_aChangedConstraintIsADifferentScope', () {
      const small = PermissionScope(constraints: <String, Object?>{'maxResponseBytes': 1024});
      const large = PermissionScope(constraints: <String, Object?>{'maxResponseBytes': 4194304});

      expect(small, isNot(large));
      expect(small, const PermissionScope(constraints: <String, Object?>{'maxResponseBytes': 1024}));
    });
  });

  group('PermissionGrant', () {
    final grantedAt = DateTime.utc(2026, 10, 8, 12);
    final expiresAt = DateTime.utc(2026, 10, 8, 18);

    PermissionGrant grant(
      PermissionState state, {
      PermissionScope scope = PermissionScope.unrestricted,
      DateTime? expiry,
    }) {
      return PermissionGrant(
        extensionId: 'purelive.external.tvbox',
        permission: Permission.network,
        state: state,
        grantedAt: grantedAt,
        expiresAt: expiry,
        scope: scope,
      );
    }

    test('test_grant_isEffectiveAt_grantedWithNoExpiry_isEffective', () {
      expect(grant(PermissionState.granted).isEffectiveAt(grantedAt), isTrue);
    });

    test('test_grant_isEffectiveAt_afterExpiry_isNotEffective', () {
      final timed = grant(PermissionState.granted, expiry: expiresAt);
      expect(timed.isEffectiveAt(DateTime.utc(2026, 10, 8, 17, 59)), isTrue);
      expect(timed.isEffectiveAt(expiresAt), isFalse);
    });

    test('test_grant_isEffectiveAt_nonGrantedState_isNeverEffective', () {
      for (final state in <PermissionState>[
        PermissionState.unknown,
        PermissionState.denied,
        PermissionState.restricted,
      ]) {
        expect(grant(state).isEffectiveAt(grantedAt), isFalse, reason: state.name);
      }
    });

    test('test_grant_isEffectiveAt_targetOutsideHostScope_isNotEffective', () {
      final limited = grant(PermissionState.granted, scope: const PermissionScope(hosts: <String>{'example.com'}));

      expect(limited.isEffectiveAt(grantedAt, target: _target), isTrue);
      expect(limited.isEffectiveAt(grantedAt, target: Uri.parse('https://other.com/a')), isFalse);
    });

    test('test_grant_asDenied_dropsExpiryAndKeepsScope', () {
      final timed = grant(PermissionState.granted, expiry: expiresAt);
      final denied = timed.asDenied();

      expect(denied.state, PermissionState.denied);
      expect(denied.expiresAt, isNull);
      expect(denied.scope, timed.scope);
      expect(denied.permission, timed.permission);
    });

    test('test_grant_jsonRoundTrip_preservesFields', () {
      final original = grant(
        PermissionState.granted,
        scope: const PermissionScope(hosts: <String>{'example.com'}, constraints: <String, Object?>{'n': 1}),
        expiry: expiresAt,
      );

      final decoded = PermissionGrant.fromJson(original.toJson());

      expect(decoded.extensionId, 'purelive.external.tvbox');
      expect(decoded.permission, Permission.network);
      expect(decoded.state, PermissionState.granted);
      expect(decoded.grantedAt, grantedAt);
      expect(decoded.expiresAt, expiresAt);
      expect(decoded.scope.hosts, <String>{'example.com'});
      expect(decoded, original);
    });

    test('test_grant_fromJson_unknownPermissionName_throwsInsteadOfDefaulting', () {
      // Falling back to a known permission would widen a record whose data is already untrustworthy.
      expect(
        () => PermissionGrant.fromJson(<String, Object?>{
          'extensionId': 'x',
          'permission': 'telekinesis',
          'state': 'granted',
        }),
        throwsFormatException,
      );
    });

    test('test_grant_fromJson_unknownState_fallsBackToUnknown', () {
      final decoded = PermissionGrant.fromJson(<String, Object?>{
        'extensionId': 'x',
        'permission': 'network',
        'state': 'yes_please',
      });

      expect(decoded.state, PermissionState.unknown);
      expect(decoded.isEffectiveAt(DateTime.utc(2026, 10, 8)), isFalse);
    });
  });

  group('NetworkRequest', () {
    test('test_networkRequest_effectiveTimeout_absentValue_usesPlatformDefault', () {
      final request = NetworkRequest(method: 'GET', uri: _target);
      expect(request.effectiveTimeout, NetworkRequest.defaultTimeout);
      expect(request.timeout, isNull);
    });

    test('test_networkRequest_isReadOnly_headCountsAsReadOnly', () {
      expect(NetworkRequest(method: 'GET', uri: _target).isReadOnly, isTrue);
      expect(NetworkRequest(method: 'HEAD', uri: _target).isReadOnly, isTrue);
      expect(NetworkRequest(method: 'POST', uri: _target).isReadOnly, isFalse);
    });

    test('test_networkRequest_redactedHeaders_hidesCredentialHeaders', () {
      const authorization = 'Bearer super-secret-token';
      const cookie = 'sid=abc';
      final request = NetworkRequest(
        method: 'POST',
        uri: _target,
        headers: <String, String>{
          'Authorization': authorization,
          'cookie': cookie,
          'X-API-KEY': 'key',
          'Referer': 'https://example.com/',
          'User-Agent': 'pure_live/2',
        },
      );

      final redacted = request.redactedHeaders();

      expect(redacted['Authorization'], _hidden(authorization));
      expect(redacted['cookie'], _hidden(cookie));
      expect(redacted['X-API-KEY'], _hidden('key'));
      expect(redacted['Referer'], 'https://example.com/');
      expect('${request.toString()}', isNot(contains('super-secret-token')));
    });

    test('test_networkRequest_redactedHeaders_emptySecretStaysMarked', () {
      final request = NetworkRequest(method: 'GET', uri: _target, headers: const <String, String>{'Cookie': ''});
      expect(request.redactedHeaders()['Cookie'], '<empty>');
    });

    test('test_networkRequest_toJson_neverCarriesTheBodyOrRawSecrets', () {
      final request = NetworkRequest(
        method: 'GET',
        uri: _target,
        headers: const <String, String>{'Authorization': 'Bearer leaked'},
        body: 'payload',
      );

      final json = request.toJson();

      expect(json.containsKey('body'), isFalse);
      expect(json['headers'], <String, String>{'Authorization': _hidden('Bearer leaked')});
      expect(json['timeoutMs'], NetworkRequest.defaultTimeout.inMilliseconds);
    });

    test('test_networkRequest_fromJson_readsBackTheRedactedForm', () {
      final original = NetworkRequest(
        method: 'GET',
        uri: _target,
        headers: const <String, String>{'Referer': 'https://example.com/'},
        timeout: const Duration(seconds: 3),
        followRedirects: false,
      );

      final decoded = NetworkRequest.fromJson(original.toJson());

      expect(decoded.method, 'GET');
      expect(decoded.uri, _target);
      expect(decoded.headers['Referer'], 'https://example.com/');
      expect(decoded.timeout, const Duration(seconds: 3));
      expect(decoded.followRedirects, isFalse);
    });

    test('test_networkRequest_fromJson_missingRequiredField_throwsFormatException', () {
      expect(() => NetworkRequest.fromJson(<String, Object?>{'method': 'GET'}), throwsFormatException);
    });
  });

  group('NetworkResponse', () {
    test('test_networkResponse_statusBands_classifySuccessAndRedirect', () {
      NetworkResponse response(int code) => NetworkResponse(statusCode: code, finalUri: _target);

      expect(response(204).isSuccess, isTrue);
      expect(response(302).isRedirect, isTrue);
      expect(response(403).isSuccess, isFalse);
      expect(response(403).isRedirect, isFalse);
    });

    test('test_networkResponse_toString_reportsSizeNotContent', () {
      final response = NetworkResponse(
        statusCode: 200,
        finalUri: _target,
        body: List<int>.filled(12, 0),
        headers: const <String, String>{'set-cookie': 'sid=abc12345'},
      );

      expect(response.bodySize, 12);
      expect('${response.toString()}', contains('12 bytes'));
      expect('${response.toString()}', isNot(contains('abc12345')));
      expect(response.redactedHeaders()['set-cookie'], _hidden('sid=abc12345'));
    });
  });

  group('Cookie', () {
    final now = DateTime.utc(2026, 10, 8, 12);

    test('test_cookie_matchesUri_domainCoversSubdomainsOfThatApexOnly', () {
      const cookie = Cookie(name: 'sid', value: 'v', domain: 'example.com');

      expect(cookie.matchesUri(Uri.parse('https://example.com/')), isTrue);
      expect(cookie.matchesUri(Uri.parse('https://api.example.com/')), isTrue);
      expect(cookie.matchesUri(Uri.parse('https://noteexample.com/')), isFalse);
    });

    test('test_cookie_matchesUri_leadingDotDomainBehavesLikeTheApex', () {
      const cookie = Cookie(name: 'sid', value: 'v', domain: '.example.com');
      expect(cookie.matchesUri(Uri.parse('https://example.com/')), isTrue);
      expect(cookie.matchesUri(Uri.parse('https://a.example.com/')), isTrue);
    });

    test('test_cookie_matchesUri_secureCookieRefusesPlainHttp', () {
      const cookie = Cookie(name: 'sid', value: 'v', domain: 'example.com', secure: true);
      expect(cookie.matchesUri(Uri.parse('http://example.com/')), isFalse);
      expect(cookie.matchesUri(Uri.parse('https://example.com/')), isTrue);
    });

    test('test_cookie_matchesUri_pathMustBeAPrefix', () {
      const cookie = Cookie(name: 'sid', value: 'v', domain: 'example.com', path: '/api/');
      expect(cookie.matchesUri(Uri.parse('https://example.com/api/v1')), isTrue);
      expect(cookie.matchesUri(Uri.parse('https://example.com/apiv1')), isFalse);
      expect(cookie.matchesUri(Uri.parse('https://example.com')), isFalse);
    });

    test('test_cookie_expiry_sessionCookiesNeverExpire', () {
      const session = Cookie(name: 'sid', value: 'v', domain: 'example.com');
      final timed = Cookie(
        name: 'sid',
        value: 'v',
        domain: 'example.com',
        expiresAt: now.add(const Duration(minutes: 5)),
      );

      expect(session.isSessionCookie, isTrue);
      expect(session.isExpiredAt(now.add(const Duration(days: 1))), isFalse);
      expect(timed.isExpiredAt(now), isFalse);
      expect(timed.isExpiredAt(now.add(const Duration(minutes: 5))), isTrue);
    });

    test('test_cookie_toString_neverPrintsTheValue', () {
      const secret = 'super-secret-session-id';
      const cookie = Cookie(name: 'sid', value: secret, domain: 'example.com', httpOnly: true);

      expect('$cookie', isNot(contains(secret)));
      expect(cookie.redacted(), contains('sid=<${secret.length} chars>'));
      expect(cookie.redacted(), contains('httpOnly'));
    });
  });
}
