import 'dart:io';
import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

class AuthController extends GetxController {
  fb.FirebaseAuth? _auth;
  final isConnectingObs = false.obs;
  bool get isConnecting => isConnectingObs.value;
  set isConnecting(bool value) => isConnectingObs.value = value;
  bool shouldGoReset = false;

  final isLoginObs = false.obs;
  bool get isLogin => isLoginObs.value;
  set isLogin(bool value) => isLoginObs.value = value;

  final isReadyObs = false.obs;
  bool get isReady => isReadyObs.value;
  set isReady(bool value) => isReadyObs.value = value;

  final isInitSuccessObs = false.obs;
  bool get isInitSuccess => isInitSuccessObs.value;
  set isInitSuccess(bool value) => isInitSuccessObs.value = value;

  fb.User? user;
  String userId = '';

  StreamSubscription<fb.User?>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    startAsyncInit();
  }

  Future<void> startAsyncInit() async {
    if (isConnecting) return;
    isConnecting = true;
    try {
      await _runFirebasePlatformInit();

      if (isInitSuccess) {
        await FirebaseManager.getInstance().initial();
        await Future.delayed(Duration.zero);
        _auth = fb.FirebaseAuth.instance;
        final initialUser = _auth?.currentUser;
        if (initialUser != null && initialUser.uid.trim().isNotEmpty) {
          isLogin = true;
          user = initialUser;
          userId = initialUser.uid;
          await _syncFirebaseConfigs();
        }

        _authSubscription = _auth?.authStateChanges().listen((fb.User? firebaseUser) async {
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
      }
    } catch (e) {
      isInitSuccess = false;
      Log.d('[AuthController] Firebase async init error: $e');
    } finally {
      isConnecting = false;
    }

    if (!isLogin) {
      if (!isClosed) {
        isReady = true;
        update();
      }
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

  Future<void> _runFirebasePlatformInit() async {
    await Future.delayed(Duration.zero);
    try {
      final result = await canAccessFirebaseWebsite();
      isInitSuccess = result;
    } catch (e) {
      isInitSuccess = false;
      debugPrint('[FirebasePing] Network lookup timeout or failed: $e');
    }
  }

  Future<bool> canAccessFirebaseWebsite() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse('https://firebase.google.com/?hl=zh-cn'));
      final response = await request.close();
      client.close();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      Log.d('Firebase check failed: $e');
      return false;
    }
  }
}
