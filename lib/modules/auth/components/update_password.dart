import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/components/supa_reset_password.dart';

class UpdatePassword extends StatelessWidget {
  const UpdatePassword({super.key});

  AppBar appBar(String title) => AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar('更新密码'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SupaResetPassword(
              accessToken: Supabase.instance.client.auth.currentSession!.accessToken,
              onSuccess: (response) {
                Supabase.instance.client.auth.refreshSession();
                SmartDialog.showToast(S.current.supabase_sign_success);
                Get.offAllNamed(RoutePath.kInitial);
              },
            ),
            TextButton(
              child: Text(
                S.current.supabase_back_sign_in,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Get.offAllNamed(RoutePath.kSignIn);
              },
            ),
          ],
        ),
      ),
    );
  }
}
