import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/components/supa_email_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.supabase_sign_in),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              SupaEmailAuth(
                redirectTo: kIsWeb ? null : 'purelive://signin',
                onPasswordResetEmailSent: () {
                  final AuthController authController = Get.find<AuthController>();
                  authController.shouldGoReset = true;
                  SmartDialog.showToast('请打开邮箱重置密码', animationTime: const Duration(seconds: 2));
                },
                onSignInComplete: (AuthResponse response) {
                  SmartDialog.showToast(S.current.supabase_sign_success);
                  Get.offAllNamed(RoutePath.kInitial);
                },
                onSignUpComplete: (AuthResponse response) {
                  SmartDialog.showToast(S.current.supabase_sign_confirm);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
