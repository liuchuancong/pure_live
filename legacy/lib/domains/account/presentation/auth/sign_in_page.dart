import 'dart:developer' as developer;

import 'package:pure_live/core/index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pure_live/domains/account/presentation/auth/auth_controller.dart';
import 'package:pure_live/domains/account/presentation/auth/components/firebase_email_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.authBackend = const FirebaseEmailAuthBackend()});

  final FirebaseEmailAuthBackend authBackend;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  Future<void> _handleSignInComplete(UserCredential credential) async {
    final user = credential.user;
    if (user == null) return;
    final String email = user.email ?? i18n('account_email_undisclosed');
    String providerStr = "Email";
    if (user.providerData.any((info) => info.providerId == 'github.com')) {
      providerStr = "GitHub";
    }
    developer.log('Firebase sign-in completed via $providerStr.');
    try {
      final AuthController authController = Get.find<AuthController>();
      await authController.acceptAuthenticatedUser(user);
    } catch (e) {
      developer.log('❌ 状态同步或拉取云端配置失败: $e');
    }
    if (!mounted) return;
    ToastUtil.show('$providerStr ${i18n('firebase_sign_success')} ($email)');
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('firebase_sign_in'))),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              FirebaseEmailAuth(
                backend: widget.authBackend,
                onPasswordResetEmailSent: () {
                  ToastUtil.show(i18n('reset_password_email'));
                },
                onSignInComplete: _handleSignInComplete,
                onSignUpComplete: _handleSignInComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
