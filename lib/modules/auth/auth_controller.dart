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

  final isReadyObs = false.obs;
  bool get isReady => isReadyObs.value;
  set isReady(bool value) => isReadyObs.value = value;

  fb.User? user;
  String userId = '';

  StreamSubscription<fb.User?>? _authSubscription;

  @override
  void onInit() {
    super.onInit();

    final initialUser = _auth.currentUser;
    if (initialUser != null && initialUser.uid.trim().isNotEmpty) {
      isLogin = true;
      user = initialUser;
      userId = initialUser.uid;
      _syncFirebaseConfigs();
    }

    _authSubscription = _auth.authStateChanges().listen((fb.User? firebaseUser) async {
      if (firebaseUser != null) {
        if (firebaseUser.uid.trim().isEmpty) return;

        isLogin = true;
        user = firebaseUser;
        userId = firebaseUser.uid;
        update();

        await _syncFirebaseConfigs();
      } else {
        isLogin = false;
        user = null;
        userId = '';
        FirebaseManager.canUploadConfig = false;
        FirebaseManager.currentUserRole = null;
      }

      isReady = true;
      update();
    });

    if (!isLogin) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          isReady = true;
          update();
        }
      });
    }
  }

  Future<void> _syncFirebaseConfigs() async {
    try {
      await FirebaseManager.getInstance().loadUploadConfig();
      final wantLoad = SettingsService.to.fav.favoriteRooms.v.isEmpty;
      if (wantLoad) {
        await FirebaseManager.getInstance().downloadConfig();
      }
    } catch (e) {
      debugPrint('[AuthController] Error syncing: $e');
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
