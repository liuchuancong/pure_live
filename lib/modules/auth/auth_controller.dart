import 'dart:io';
import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';


class FirebaseAuthControllerBackend {
  const FirebaseAuthControllerBackend();

  Future<bool> canAccessFirebaseWebsite() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse('https://firebase.google.com/?hl=zh-cn'));
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (error) {
      debugPrint('[FirebaseProbe] Website check failed: $error');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> initialize() => FirebaseManager.getInstance().initial();

  fb.User? get currentUser => fb.FirebaseAuth.instance.currentUser;

  Stream<fb.User?> authStateChanges() => fb.FirebaseAuth.instance.authStateChanges();

  Future<void> syncConfigs(String userId) async {
    final manager = FirebaseManager.getInstance();
    final canDownload = await manager.loadUploadConfig(expectedUserId: userId, rethrowFailures: true);
    if (!canDownload) return;
    final wantLoad = SettingsService.to.fav.favoriteRooms.v.isEmpty;
    if (wantLoad) {
      await manager.downloadConfig(
        expectedUserId: userId,
        reloadPermissions: false,
        showFeedback: false,
        rethrowFailures: true,
      );
    }
  }

  void clearSessionMetadata() {
    FirebaseManager.canUploadConfig = false;
    FirebaseManager.currentUserRole = null;
  }
}

class AuthController extends GetxController {
  AuthController({this.backend = const FirebaseAuthControllerBackend(), this.autoStart = true});

  final FirebaseAuthControllerBackend backend;
  final bool autoStart;
  final isConnectingObs = false.obs;
  bool get isConnecting => isConnectingObs.value;
  set isConnecting(bool value) => isConnectingObs.value = value;
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
  int _lifecycleGeneration = 0;
  int _identityGeneration = 0;
  String? _syncedUserId;
  String? _syncingUserId;
  int? _syncingIdentityGeneration;
  Future<void>? _syncingOperation;

  @override
  void onInit() {
    super.onInit();
    if (autoStart) startAsyncInit();
  }

  Future<void> startAsyncInit() async {
    if (isConnecting || isClosed) return;

    final lifecycleGeneration = ++_lifecycleGeneration;
    isConnecting = true;
    isReady = false;
    update();

    try {
      final previousSubscription = _authSubscription;
      _authSubscription = null;
      await previousSubscription?.cancel();

      if (!_isLifecycleCurrent(lifecycleGeneration)) return;
      // Probe Firebase connectivity before initialization to avoid blocking
      // app startup when Firebase services are unreachable or inaccessible.
      final canAccessFirebase = await backend.canAccessFirebaseWebsite();

      if (!_isLifecycleCurrent(lifecycleGeneration)) return;

      if (!canAccessFirebase) {
        isInitSuccess = false;
        _setSignedOut(clearMetadata: true);
        debugPrint(
          '[AuthController] Firebase website is unreachable, '
          'skip Firebase initialization.',
        );
        return;
      }

      await backend.initialize();

      if (!_isLifecycleCurrent(lifecycleGeneration)) return;

      isInitSuccess = true;

      _authSubscription = backend.authStateChanges().listen(
        (firebaseUser) {
          unawaited(_applyAuthUser(firebaseUser, lifecycleGeneration));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isLifecycleCurrent(lifecycleGeneration)) return;

          debugPrint('[AuthController] Auth state stream error: $error');

          isReady = true;
          update();
        },
      );

      await _applyAuthUser(backend.currentUser, lifecycleGeneration);
    } catch (error) {
      if (!_isLifecycleCurrent(lifecycleGeneration)) return;

      isInitSuccess = false;
      _setSignedOut(clearMetadata: true);

      debugPrint('[AuthController] Firebase async init error: $error');
    } finally {
      if (_isLifecycleCurrent(lifecycleGeneration)) {
        isConnecting = false;
        isReady = true;
        update();
      }
    }
  }

  Future<void> acceptAuthenticatedUser(fb.User firebaseUser) {
    return _applyAuthUser(firebaseUser, _lifecycleGeneration);
  }

  Future<void> acceptSignedOut() {
    return _applyAuthUser(null, _lifecycleGeneration);
  }

  Future<void> _applyAuthUser(fb.User? firebaseUser, int lifecycleGeneration) async {
    if (!_isLifecycleCurrent(lifecycleGeneration)) return;
    final nextUserId = firebaseUser?.uid.trim() ?? '';
    if (firebaseUser == null || nextUserId.isEmpty) {
      _setSignedOut(clearMetadata: true);
      isReady = true;
      update();
      return;
    }

    if (userId != nextUserId) {
      _identityGeneration++;
      _syncedUserId = null;
    }
    final identityGeneration = _identityGeneration;
    isLogin = true;
    user = firebaseUser;
    userId = nextUserId;
    update();

    if (_syncedUserId == nextUserId) {
      isReady = true;
      update();
      return;
    }

    final Future<void> operation;
    if (_syncingUserId == nextUserId && _syncingIdentityGeneration == identityGeneration && _syncingOperation != null) {
      operation = _syncingOperation!;
    } else {
      operation = _syncFirebaseConfigs(nextUserId);
      _syncingUserId = nextUserId;
      _syncingIdentityGeneration = identityGeneration;
      _syncingOperation = operation;
    }

    var succeeded = false;
    try {
      await operation;
      succeeded = true;
    } catch (_) {
      // _syncFirebaseConfigs already records the diagnostic. Authentication
      // remains valid even when optional profile/config synchronization fails.
    } finally {
      if (identical(_syncingOperation, operation)) {
        _syncingOperation = null;
        _syncingUserId = null;
        _syncingIdentityGeneration = null;
      }
    }

    if (!_isLifecycleCurrent(lifecycleGeneration) ||
        identityGeneration != _identityGeneration ||
        userId != nextUserId) {
      return;
    }
    if (succeeded) _syncedUserId = nextUserId;
    isReady = true;
    update();
  }

  Future<void> _syncFirebaseConfigs(String expectedUserId) async {
    try {
      await backend.syncConfigs(expectedUserId);
    } catch (error) {
      debugPrint('[AuthController] Optional profile/config sync failed: $error');
      rethrow;
    }
  }

  void _setSignedOut({required bool clearMetadata}) {
    if (isLogin || user != null || userId.isNotEmpty) {
      _identityGeneration++;
    }
    isLogin = false;
    user = null;
    userId = '';
    _syncedUserId = null;
    if (clearMetadata) backend.clearSessionMetadata();
  }

  bool _isLifecycleCurrent(int generation) => !isClosed && generation == _lifecycleGeneration;

  void _cancelAuthSubscription() {
    final subscription = _authSubscription;
    _authSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  @override
  void onClose() {
    _lifecycleGeneration++;
    _identityGeneration++;
    _cancelAuthSubscription();
    super.onClose();
  }

  Future<bool> canAccessFirebaseWebsite() async {
    return backend.canAccessFirebaseWebsite();
  }
}
