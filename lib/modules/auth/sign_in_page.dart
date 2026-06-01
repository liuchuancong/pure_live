import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:pure_live/modules/auth/components/firebase_email_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  void _handleSignInComplete(UserCredential credential) async {
    final user = credential.user;
    if (user == null) return;
    final String email = user.email ?? "未公开邮箱";
    String providerStr = "Email";
    if (user.providerData.any((info) => info.providerId == 'github.com')) {
      providerStr = "GitHub";
    }
    developer.log('🎉 登录成功! 渠道: $providerStr, 邮箱: $email, UID: ${user.uid}');
    try {
      final AuthController authController = Get.find<AuthController>();
      authController.isLogin = true;
      authController.user = user;
      authController.userId = user.uid;
      authController.update();
      await FirebaseManager.getInstance().loadUploadConfig();
      final wantLoad = SettingsService.to.fav.favoriteRooms.v.isEmpty;
      if (wantLoad) {
        await FirebaseManager.getInstance().downloadConfig();
      }
      authController.update();
    } catch (e) {
      developer.log('❌ 状态同步或拉取云端配置失败: $e');
    }
    ToastUtil.show('$providerStr ${i18n('firebase_sign_success')} ($email)');
    Navigator.of(Get.context!).pop();
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
                onPasswordResetEmailSent: () {
                  final AuthController authController = Get.find<AuthController>();
                  authController.shouldGoReset = true;
                  ToastUtil.show(i18n('reset_password_email'));
                },
                onSignInComplete: (UserCredential credential) {
                  _handleSignInComplete(credential);
                },
                onSignUpComplete: (UserCredential credential) {
                  _handleSignInComplete(credential);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
