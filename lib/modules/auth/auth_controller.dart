import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends GetxController {
  final supabaseClient = SupaBaseManager().client;
  bool shouldGoReset = false;
  late bool isLogin = false;
  late User user;
  String userId = '';
  @override
  void onInit() {
    super.onInit();
    supabaseClient.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      if (session?.user != null) {
        isLogin = true;
        userId = data.session!.user.id;
        user = session!.user;
        await SupaBaseManager().loadUploadConfig();
        bool wantLoad = SettingsService.to.fav.favoriteRooms.v.isEmpty;

        if (wantLoad) {
          SupaBaseManager().readConfig();
        }
      } else {
        isLogin = false;
        userId = '';
      }
      if (event == AuthChangeEvent.passwordRecovery && shouldGoReset) {
        Timer(const Duration(seconds: 2), () {
          shouldGoReset = false;
          Get.offAndToNamed(RoutePath.kUpdatePassword);
        });
      }
    });
  }
}
