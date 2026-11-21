import 'dart:async' show Completer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_web_login.dart' show HongguoLoginFailure;
import 'package:pure_live/modules/hongguo/widgets/hongguo_phone_sign_in.dart';

/// The phone sign-in form: an empty ask never leaves the form, the send
/// button reads the ask's own answer (the mask, then the wait, then itself
/// again), a refused code names the refusal, and a settled code signs the
/// account in and clears itself. The session and the account under the form
/// are scripted — neither the transport nor the store runs under the widget
/// test's clock.
void main() {
  // The form holds exactly two buttons; their labels move with the state
  // (the send reads the wait), so the finders go by place, not by words.
  Finder sendButton() => find.byType(DsButton).first;
  Finder verifyButton() => find.byType(DsButton).at(1);

  Future<({Translations t, TextEditingController code})> showForm(
    WidgetTester tester, {
    required Future<({String maskedMobile, int retrySeconds})> Function() onSend,
    required Future<void> Function(String code) onVerify,
    bool signedIn = false,
  }) async {
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    final container = ProviderContainer(
      overrides: [
        platformRuntimeProvider.overrideWithValue(runtime),
        hongguoLoginSessionProvider.overrideWith(() => _ScriptedSession(onSend, onVerify)),
        hongguoAccountProvider.overrideWith(
          () => _MemoryAccount(
            HongguoAccountState(credentials: signedIn ? const HongguoCredentials(cookie: 'sid=1') : null),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: const DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: Padding(padding: EdgeInsets.all(16), child: HongguoPhoneSignIn()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final t = tester.element(find.byType(HongguoPhoneSignIn)).t;
    final code = tester.widget<DsTextField>(find.byType(DsTextField).at(1)).controller!;
    return (t: t, code: code);
  }

  testWidgets('an empty ask never leaves the form', (tester) async {
    var sends = 0;
    var verifies = 0;
    final form = await showForm(
      tester,
      onSend: () async {
        sends += 1;
        return (maskedMobile: '138****0000', retrySeconds: 60);
      },
      onVerify: (_) async {
        verifies += 1;
      },
    );
    final t = form.t;

    await tester.tap(sendButton());
    await tester.tap(verifyButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(sends, 0); // no phone, no send
    expect(verifies, 0); // no code, no verify
    expect(find.text(t.hongguo.phoneSent), findsNothing);
  });

  testWidgets('the send answers with the mask, then the wait, then itself again', (tester) async {
    final gate = Completer<({String maskedMobile, int retrySeconds})>();
    final form = await showForm(tester, onSend: () => gate.future, onVerify: (_) async {});
    final t = form.t;

    await tester.enterText(find.byType(DsTextField).first, '13800000000');
    await tester.tap(sendButton());
    await tester.pump();
    expect(tester.widget<DsButton>(sendButton()).onPressed, isNull); // the ask is in flight

    gate.complete((maskedMobile: '138****0000', retrySeconds: 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('${t.hongguo.phoneSent} 138****0000'), findsOneWidget); // the answer names the mask
    expect(find.text('60s'), findsOneWidget); // the wait the passport asked for
    expect(tester.widget<DsButton>(sendButton()).onPressed, isNull); // the wait holds the button

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('58s'), findsOneWidget); // the ticker counts down

    await tester.pump(const Duration(seconds: 58));
    expect(find.text(t.hongguo.phoneSend), findsOneWidget); // the wait is over: the send is itself again
    expect(tester.widget<DsButton>(sendButton()).onPressed, isNotNull);
    expect(find.text('${t.hongguo.phoneSent} 138****0000'), findsOneWidget); // the mask's line stays
  });

  testWidgets('a refused code names the refusal and gives the form back', (tester) async {
    final gate = Completer<void>();
    final form = await showForm(
      tester,
      onSend: () async => (maskedMobile: '138****0000', retrySeconds: 60),
      onVerify: (_) => gate.future,
    );
    final t = form.t;

    await tester.enterText(find.byType(DsTextField).at(1), '2468');
    await tester.tap(verifyButton());
    await tester.pump();
    expect(tester.widget<DsButton>(verifyButton()).onPressed, isNull); // the ask is in flight

    gate.completeError(const HongguoLoginFailure('验证码不对'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('验证码不对'), findsOneWidget); // the refusal's own words
    expect(tester.widget<DsButton>(verifyButton()).onPressed, isNotNull); // the form is back
    expect(find.text(t.hongguo.phoneVerify), findsOneWidget);
  });

  testWidgets('a settled code signs the account in and clears itself', (tester) async {
    final form = await showForm(
      tester,
      onSend: () async => (maskedMobile: '138****0000', retrySeconds: 60),
      onVerify: (_) async {},
      signedIn: true, // the session behind the form settled: the account holds a login
    );
    final t = form.t;
    final code = form.code;

    await tester.enterText(find.byType(DsTextField).at(1), '2468');
    await tester.tap(verifyButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(code.text, isEmpty); // the settled code leaves no copy behind
    expect(find.text('验证码不对'), findsNothing); // nothing failed
    expect(find.textContaining(t.hongguo.phoneSent), findsNothing); // nothing was sent here
  });
}

/// The session this file's forms run under: the passport's answers scripted.
final class _ScriptedSession extends HongguoLoginSessionController {
  _ScriptedSession(this.onSend, this.onVerify);

  final Future<({String maskedMobile, int retrySeconds})> Function() onSend;
  final Future<void> Function(String code) onVerify;

  @override
  Future<({String maskedMobile, int retrySeconds})> sendCode(String number) => onSend();

  @override
  Future<void> verifyCode(String code) => onVerify(code);
}

/// The account this file's forms read: a memory state, no store.
final class _MemoryAccount extends HongguoAccountController {
  _MemoryAccount(this._state);

  final HongguoAccountState _state;

  @override
  HongguoAccountState build() => _state;
}
