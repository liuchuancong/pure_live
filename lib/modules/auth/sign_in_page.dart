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
      appBar: AppBar(title: Text(i18n('firebase_sign_in'))), // 如果 i18n 還沒改，可先用常規字串
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
                  ToastUtil.show(i18n('supabase_sign_success')); // 提示成功
                  Get.offAllNamed(RoutePath.kInitial); // 使用 Get 跳轉回首頁
                },
                onSignUpComplete: (UserCredential credential) {
                  // Firebase 預設註冊成功會自動登入
                  ToastUtil.show(i18n('supabase_sign_success'));
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
