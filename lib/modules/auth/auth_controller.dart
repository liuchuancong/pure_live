import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

class AuthController extends GetxController {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  bool shouldGoReset = false;

  final isLoginObs = false.obs;
  bool get isLogin => isLoginObs.value;
  set isLogin(bool value) => isLoginObs.value = value;
  fb.User? user;

  String userId = '';

  StreamSubscription<fb.User?>? _authSubscription;

  @override
  void onInit() {
    super.onInit();

    _authSubscription = _auth.authStateChanges().listen((fb.User? firebaseUser) async {
      if (firebaseUser != null) {
        isLogin = true;
        user = firebaseUser;
        userId = firebaseUser.uid;
        update();
        await FirebaseManager.getInstance().loadUploadConfig();
        final wantLoad = SettingsService.to.fav.favoriteRooms.v.isEmpty;
        if (wantLoad) {
          await FirebaseManager.getInstance().downloadConfig();
        }
      } else {
        isLogin = false;

        user = null;

        userId = '';
      }

      update();
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
