import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show SecretRefs, SecretVault;
import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/app_providers.dart' show sitesProvider;
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/features/account/cookie_editor_page.dart';
import 'package:pure_live/features/account/douyu_login_store.dart';
import 'package:pure_live/features/account/login_providers.dart';
import 'package:pure_live/features/account/login_repository.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// An in-memory vault: the editor's persistence under test is a map, the
/// same shape the device keychain gives.
final class _MapVault implements SecretVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String ref, String plain) async => values[ref] = plain;

  @override
  Future<void> delete(String ref) async => values.remove(ref);
}

/// The douyu adapter's test half: a site whose only capability signs a
/// pasted cookie in when it carries fields, and refuses it otherwise — the
/// shape the real `DouyuAuthProvider` verifies with.
final class _FakeAuth implements LiveAuthCapability {
  final List<LiveCredential> applied = <LiveCredential>[];

  @override
  LiveAuthSession startQrLogin() => throw UnsupportedError('paste only');

  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final fields = <String, String>{
      for (final part in rawCookieHeader.split(';'))
        if (part.contains('=')) part.split('=').first.trim(): part.split('=').last.trim(),
    };
    if (fields.isEmpty) {
      // The capability contract throws the site's failure type, which is
      // not an Exception — the same shape the real auth providers have.
      // ignore: only_throw_errors
      throw const LiveSiteError.authentication(siteId: 'douyu', message: 'no fields');
    }
    return LiveCredential(siteId: 'douyu', cookies: fields, nickname: '弹幕君');
  }

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) => throw UnsupportedError('paste only');

  @override
  Future<void> applyCredential(LiveCredential credential) async => applied.add(credential);

  @override
  Future<void> clearCredential() async {}
}

final class _FakeSite implements LiveSite {
  new(this.id, this._auth);

  final String id;
  final LiveAuthCapability? _auth;

  @override
  LiveSiteManifest get manifest =>
      LiveSiteManifest(id: id, name: const {'zh': '斗鱼'}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() {
    final auth = _auth;
    if (auth == null) {
      return null;
    }
    return auth is T ? auth as T : null;
  }

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('the cookie editor refuses a non-cookie before asking the platform', (tester) async {
    final vault = _MapVault();
    final auth = _FakeAuth();
    await _pump(tester, vault: vault, auth: auth);

    await tester.enterText(find.byKey(const ValueKey('account-cookie-field')), 'not a cookie');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('account-cookie-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('这不像 Cookie'), findsOneWidget);
    expect(auth.applied, isEmpty);
    expect(vault.values[SecretRefs.cookie('douyu')], isNull);
  });

  testWidgets('a verified cookie lands on the site, in the vault and on the card', (tester) async {
    final vault = _MapVault();
    final auth = _FakeAuth();
    await _pump(tester, vault: vault, auth: auth);

    await tester.enterText(find.byKey(const ValueKey('account-cookie-field')), 'dy_auth=abc123; uid=7');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('account-cookie-save')));
    await tester.pumpAndSettle();

    expect(auth.applied.single.nickname, '弹幕君');
    final raw = vault.values[SecretRefs.cookie('douyu')];
    expect(raw, isNotNull);
    final document = jsonDecode(raw!) as Map<String, Object?>;
    expect((document['cookies']! as Map).cast<String, String>(), {'dy_auth': 'abc123', 'uid': '7'});
    expect(find.text('已登录：弹幕君'), findsWidgets); // the card and the success toast

    // Douyu's renewal pair is saved with the cookie and lands in the vault.
    expect(vault.values[SecretRefs.douyuSavedAt], isNotNull);

    // Signing out takes the stored document back out. The dialog's own
    // confirm button reads like the page's, so the last one is the dialog.
    await tester.tap(find.byKey(const ValueKey('account-cookie-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录').last);
    await tester.pumpAndSettle();
    expect(vault.values[SecretRefs.cookie('douyu')], isNull);
  });
}

Future<void> _pump(WidgetTester tester, {required _MapVault vault, required _FakeAuth auth}) async {
  final sites = AppSites(
    factory: DioFactory(),
    http: DioFactory().create(),
    registry: LiveSiteRegistry([_FakeSite('douyu', auth)]),
  );
  final store = await AppDouyuLoginStore.load(vault: () => vault);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWithValue(sites),
        douyuLoginStoreProvider.overrideWithValue(store),
        loginRepositoryProvider.overrideWith((ref, siteId) => LoginRepository(siteId: siteId, vaultOf: () => vault)),
      ],
      child: PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (context, state) => const CookieEditorPage(siteId: 'douyu'))],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          locale: const Locale('zh'),
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  await tester.pump();
}
