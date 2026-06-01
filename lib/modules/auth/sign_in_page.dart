import 'package:pure_live/common/index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/components/firebase_email_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
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
                onPasswordResetEmailSent: () {
                  final AuthController authController = Get.find<AuthController>();
                  authController.shouldGoReset = true;
                  ToastUtil.show(i18n('reset_password_email'));
                },
                onSignInComplete: (UserCredential credential) {
                  ToastUtil.show(i18n('firebase_sign_success'));
                  Get.offAllNamed(RoutePath.kInitial);
                },
                onSignUpComplete: (UserCredential credential) {
                  ToastUtil.show(i18n('firebase_sign_success'));
                  Get.offAllNamed(RoutePath.kInitial);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
