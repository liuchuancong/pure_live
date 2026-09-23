import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:win32_registry/win32_registry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

class _FirebaseAuthSessionChanged implements Exception {
  const _FirebaseAuthSessionChanged();
}

Map<String, dynamic> buildFirebaseConfigUploadData({
  required String config,
  required String email,
  required String version,
  required String updateAt,
  required bool hasCanonicalCreatedAt,
  Object? legacyCreatedAt,
  required Object newCreatedAt,
}) {
  final payload = <String, dynamic>{'config': config, 'email': email, 'version': version, 'update_at': updateAt};
  if (!hasCanonicalCreatedAt) {
    payload['created_at'] = legacyCreatedAt ?? newCreatedAt;
  }
  return payload;
}

Map<String, dynamic>? parseFirebaseStoredConfig(Object? storedConfig) {
  if (storedConfig == null) return null;
  final Object? decoded;
  if (storedConfig is String) {
    if (storedConfig.trim().isEmpty) return null;
    decoded = jsonDecode(storedConfig);
  } else {
    decoded = storedConfig;
  }
  if (decoded is! Map) {
    throw const FormatException('Firebase config payload must be an object.');
  }
  return Map<String, dynamic>.from(decoded);
}

class FirebaseManager {
  static final FirebaseManager _instance = FirebaseManager._internal();
  static const String customScheme = 'purelive';
  static String? currentUserRole;
  static Set<String> managementRoles = {};
  static const String middlePageUrl = 'https://pure-live-26c7f.web.app/auth_callback.html';
  static Map<String, List<String>> roleVisibilityMap = {};
  static Map<String, int> roleWeights = {};

  static bool canUploadConfig = false;
  Future<void>? _initialization;

  FirebaseManager._internal();

  factory FirebaseManager.getInstance() => _instance;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  FirebaseAuth get auth => FirebaseAuth.instance;

  Future<void> initial() {
    final existing = _initialization;
    if (existing != null) return existing;

    late final Future<void> operation;
    operation = _initializeOnce().catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, operation)) _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _initialization = operation;
    return operation;
  }

  Future<void> _initializeOnce() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await registerWindowsCustomScheme(customScheme, description: 'PureLive Authentication Callback');
  }

  Future<void> registerWindowsCustomScheme(String scheme, {String? description}) async {
    if (!Platform.isWindows || scheme.trim().isEmpty) {
      return;
    }

    RegistryKey? schemeKey;
    RegistryKey? commandKey;

    try {
      final exePath = Platform.resolvedExecutable;
      final basePath = r'Software\Classes\' + scheme;
      final commandPath = '$basePath\\shell\\open\\command';
      final command = '"$exePath" "%1"';

      schemeKey = CURRENT_USER.create(basePath);
      commandKey = CURRENT_USER.create(commandPath);

      final currentCommandValue = commandKey.getValue('');
      if (currentCommandValue is StringValue && currentCommandValue.value == command) {
        return;
      }

      schemeKey.setValue('', RegistryValue.string(description ?? 'URL:$scheme Protocol'));
      schemeKey.setValue('URL Protocol', const RegistryValue.string(''));
      commandKey.setValue('', RegistryValue.string(command));

      debugPrint('[Protocol Registry] Registered $scheme://');
    } catch (e, s) {
      debugPrint('[Protocol Registry] Failed: $e\n$s');
    } finally {
      schemeKey?.close();
      commandKey?.close();
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
    try {
      final AuthController authController = Get.find<AuthController>();
      await authController.acceptSignedOut();
    } catch (e) {
      developer.log('❌ 退出登录时状态同步清空失败: $e');
    }
    final context = Get.context;
    if (context != null && context.mounted) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<bool> loadUploadConfig({String? expectedUserId, bool rethrowFailures = false}) async {
    final authController = Get.find<AuthController>();
    final user = authController.user;
    if (user == null) {
      canUploadConfig = false;
      currentUserRole = null;
      return false;
    }
    final requestedUserId = user.uid.trim();
    if (requestedUserId.isEmpty || (expectedUserId != null && expectedUserId != requestedUserId)) {
      return false;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final doc = await firestore.collection('users').doc(requestedUserId).get();
      final nextCanUpload = !doc.exists || doc.data()?['canUpload'] != false;

      final permDoc = await firestore.collection('permissions').doc(requestedUserId).get();
      final nextUserRole = permDoc.exists ? (permDoc.data()?['role'] as String?) : null;

      final rolesSnapshot = await firestore.collection('roles').get();
      final nextRoleVisibilityMap = <String, List<String>>{};
      final nextRoleWeights = <String, int>{};
      final nextManagementRoles = <String>{};

      for (var roleDoc in rolesSnapshot.docs) {
        final roleData = roleDoc.data();
        final String roleId = roleDoc.id;

        nextRoleVisibilityMap[roleId] = List<String>.from(roleData['canSeeRoles'] ?? []);
        nextRoleWeights[roleId] = roleData['weight'] ?? 2;
        if (roleData['isManagement'] == true) {
          nextManagementRoles.add(roleId);
        }
      }

      nextRoleWeights['user'] = 2;
      if (!_isCurrentControllerUser(requestedUserId)) return false;

      canUploadConfig = nextCanUpload;
      currentUserRole = nextUserRole;
      roleVisibilityMap = nextRoleVisibilityMap;
      roleWeights = nextRoleWeights;
      managementRoles = nextManagementRoles;

      return canUploadConfig;
    } catch (e) {
      debugPrint('[FirebaseManager] 从 users 集合读取权限异常（停止上传）: $e');
      if (_isCurrentControllerUser(requestedUserId)) {
        canUploadConfig = false;
        currentUserRole = null;
      }
      if (rethrowFailures) rethrow;
      return false;
    }
  }

  bool _isCurrentControllerUser(String expectedUserId) {
    try {
      final controller = Get.find<AuthController>();
      return !controller.isClosed &&
          controller.isLogin &&
          controller.userId == expectedUserId &&
          controller.user?.uid == expectedUserId;
    } catch (_) {
      return false;
    }
  }

  bool canVisible(String targetRole) {
    final myRole = currentUserRole ?? 'user';
    final allowedRoles = roleVisibilityMap[myRole] ?? ['user'];
    return allowedRoles.contains(targetRole);
  }

  /// Roles the current user is allowed to see in the user directory.
  ///
  /// Derived from the same [roleVisibilityMap] entry used by [canVisible], so
  /// the server-side `where('role', whereIn: visibleRoles())` filter returns
  /// exactly the set the client would have accepted. This avoids page-size
  /// drift where the server returns N docs but the client silently drops some.
  ///
  /// `roleWeights` is the authoritative list of known roles: it is populated
  /// from the `roles` collection in [loadUploadConfig] with `user` always
  /// added as a fallback.
  List<String> visibleRoles() {
    final myRole = currentUserRole ?? 'user';
    final allowed = roleVisibilityMap[myRole];
    if (allowed == null || allowed.isEmpty) {
      if (isAdmin()) return const ['admin', 'manager', 'user'];
      if (isManager()) return const ['manager', 'user'];
      return const ['user'];
    }
    final filtered = allowed.where(roleWeights.containsKey).toList(growable: false);
    return filtered.isEmpty ? const ['user'] : filtered;
  }

  Future<void> uploadConfig() async {
    final secureUser = auth.currentUser;
    if (secureUser == null || secureUser.uid.trim().isEmpty) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    final userId = secureUser.uid;
    if (!_isCurrentControllerUser(userId)) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    await loadUploadConfig(expectedUserId: userId);
    if (!_isCurrentControllerUser(userId)) return;

    if (!canUploadConfig) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }

    final BackupController backup = Get.find<BackupController>();
    final backupData = jsonEncode(backup.exportAllSettings());
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      final userReference = firestore.collection('users').doc(userId);
      await firestore.runTransaction((transaction) async {
        if (!_isCurrentControllerUser(userId)) throw const _FirebaseAuthSessionChanged();
        final existingDocument = await transaction.get(userReference);
        if (!_isCurrentControllerUser(userId)) throw const _FirebaseAuthSessionChanged();
        final existingData = existingDocument.data();
        final payload = buildFirebaseConfigUploadData(
          config: backupData,
          email: secureUser.email ?? '',
          version: VersionUtil.version,
          updateAt: formattedTime,
          hasCanonicalCreatedAt: existingData?.containsKey('created_at') ?? false,
          legacyCreatedAt: existingData?['createdAt'],
          newCreatedAt: FieldValue.serverTimestamp(),
        );
        transaction.set(userReference, payload, SetOptions(merge: true));
      });

      if (_isCurrentControllerUser(userId)) ToastUtil.show(i18n('webdav_upload_success'));
    } on _FirebaseAuthSessionChanged {
      developer.log('Firebase config upload stopped after the authenticated session changed.');
    } catch (e) {
      developer.log('❌ 上传失败（可能被安全规则拦截）: $e');
      if (_isCurrentControllerUser(userId)) ToastUtil.show(i18n('firebase_account_unauthorized'));
    }
  }

  Future<void> downloadConfig({
    String? expectedUserId,
    bool reloadPermissions = true,
    bool showFeedback = true,
    bool rethrowFailures = false,
  }) async {
    final secureUser = auth.currentUser;
    if (secureUser == null || secureUser.uid.trim().isEmpty) {
      if (showFeedback) ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    final requestedUserId = expectedUserId ?? secureUser.uid;
    if (secureUser.uid != requestedUserId || !_isCurrentControllerUser(requestedUserId)) return;

    final FavoriteController favoriteController = Get.find<FavoriteController>();
    final BackupController backup = Get.find<BackupController>();

    if (reloadPermissions) {
      await loadUploadConfig(expectedUserId: requestedUserId);
    }
    if (!_isCurrentControllerUser(requestedUserId)) return;

    if (!canUploadConfig) {
      if (showFeedback) ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    try {
      final document = await firestore.collection('users').doc(requestedUserId).get();
      if (!_isCurrentControllerUser(requestedUserId)) return;

      if (!document.exists) {
        if (showFeedback) ToastUtil.show(i18n('no_data'));
        return;
      }

      final data = document.data()!;
      final back = parseFirebaseStoredConfig(data['config']);
      if (back == null) {
        if (showFeedback) ToastUtil.show(i18n('no_data'));
        return;
      }
      if (!_isCurrentControllerUser(requestedUserId)) return;
      await backup.restoreAllSettings(back);
      if (!_isCurrentControllerUser(requestedUserId)) return;
      favoriteController.refreshData();
      if (showFeedback) ToastUtil.show(i18n('download_success'));
    } catch (e) {
      developer.log('❌ 下载失败（可能被安全规则拦截）: $e');
      if (showFeedback && _isCurrentControllerUser(requestedUserId)) {
        ToastUtil.show(i18n('firebase_account_unauthorized'));
      }
      if (rethrowFailures) rethrow;
    }
  }

  Future<void> grantUploadPermission(String uid) async {
    await firestore.collection('permissions').doc(uid).set({'canUpload': true, 'role': 'user'});
  }

  Future<void> revokeUploadPermission(String uid) async {
    await firestore.collection('permissions').doc(uid).delete();
  }

  bool isAdmin() {
    final myRole = FirebaseManager.currentUserRole;
    if (myRole == null) return false;
    return FirebaseManager.roleWeights[myRole] == 0;
  }

  bool isManager() {
    final myRole = FirebaseManager.currentUserRole;
    if (myRole == null) return false;
    return FirebaseManager.roleWeights[myRole] == 1;
  }

  bool hasManagementPower() {
    final myRole = FirebaseManager.currentUserRole;
    if (myRole == null) return false;
    final myWeight = FirebaseManager.roleWeights[myRole] ?? 2;
    return myWeight < 2;
  }

  Future<void> handleGithubCredential(Map<String, dynamic> json) async {
    try {
      final String? accessToken = json['accessToken'];
      if (accessToken != null && accessToken.isNotEmpty) {
        final githubCredential = GithubAuthProvider.credential(accessToken);
        await auth.signInWithCredential(githubCredential);
        developer.log('Successfully signed in with GitHub token cross-instance.');
      }
    } catch (e) {
      developer.log('Error handling GitHub credential cross-instance: $e');
    }
  }

  Future<void> handleIdToken(String idToken) async {
    try {
      if (idToken.isNotEmpty) {
        final customCredential = OAuthProvider('github.com').credential(idToken: idToken);
        await auth.signInWithCredential(customCredential);
        developer.log('Successfully signed in with OAuth ID Token cross-instance.');
      }
    } catch (e) {
      developer.log('Error handling Custom ID Token cross-instance: $e');
    }
  }
}
