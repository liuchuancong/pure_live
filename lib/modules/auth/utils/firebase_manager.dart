import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pure_live/plugins/archethic.dart';
import 'package:win32_registry/win32_registry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

class FirebaseManager {
  static late FirebaseManager _instance;
  static const String customScheme = 'purelive';
  static String? currentUserRole;
  static Set<String> managementRoles = {};
  static const String middlePageUrl = 'https://pure-live-26c7f.web.app/auth_callback.html';
  static Map<String, List<String>> roleVisibilityMap = {};
  static Map<String, int> roleWeights = {};

  static bool canUploadConfig = false;

  FirebaseManager._internal();

  factory FirebaseManager.getInstance() {
    _instance = FirebaseManager._internal();
    return _instance;
  }

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  FirebaseAuth get auth => FirebaseAuth.instance;

  Future<void> initial() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    registerWindowsCustomScheme(customScheme, description: 'PureLive Authentication Callback');
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

  void signOut() {
    auth.signOut();
    try {
      final AuthController authController = Get.find<AuthController>();

      authController.isLogin = false;
      authController.user = null;
      authController.userId = '';
      authController.update();
    } catch (e) {
      developer.log('❌ 退出登录时状态同步清空失败: $e');
    }
    Navigator.of(Get.context!).pop();
  }

  Future<bool> loadUploadConfig() async {
    final user = Get.find<AuthController>().user;
    if (user == null) {
      canUploadConfig = false;
      currentUserRole = null;
      return false;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final doc = await firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        canUploadConfig = true;
      } else {
        final data = doc.data();
        canUploadConfig = data?['canUpload'] != false;
      }

      final permDoc = await firestore.collection('permissions').doc(user.uid).get();
      if (permDoc.exists) {
        final permData = permDoc.data();
        currentUserRole = permData?['role'] as String?;
      } else {
        currentUserRole = null;
      }

      final rolesSnapshot = await firestore.collection('roles').get();

      roleVisibilityMap.clear();
      roleWeights.clear();
      managementRoles.clear();

      for (var roleDoc in rolesSnapshot.docs) {
        final roleData = roleDoc.data();
        final String roleId = roleDoc.id;

        roleVisibilityMap[roleId] = List<String>.from(roleData['canSeeRoles'] ?? []);
        roleWeights[roleId] = roleData['weight'] ?? 2;
        if (roleData['isManagement'] == true) {
          managementRoles.add(roleId);
        }
      }

      roleWeights['user'] = 2;

      return canUploadConfig;
    } catch (e) {
      debugPrint('[FirebaseManager] 从 users 集合读取权限异常(已默认放行): $e');
      canUploadConfig = true;
      currentUserRole = null;
      return true;
    }
  }

  bool canVisible(String targetRole) {
    final myRole = currentUserRole ?? 'user';
    final allowedRoles = roleVisibilityMap[myRole] ?? ['user'];
    return allowedRoles.contains(targetRole);
  }

  Future<void> uploadConfig() async {
    final secureUser = auth.currentUser;
    if (secureUser == null || secureUser.uid.trim().isEmpty) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    await loadUploadConfig();

    if (!canUploadConfig) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }

    final userId = secureUser.uid;
    final BackupController backup = Get.find<BackupController>();
    final encryptData = ArchethicUtils().encrypt(jsonEncode(backup.exportAllSettings()));
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      await firestore.collection('users').doc(userId).set({
        'config': encryptData,
        'email': secureUser.email ?? '',
        'version': VersionUtil.version,
        'update_at': formattedTime,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ToastUtil.show(i18n('webdav_upload_success'));
    } catch (e) {
      developer.log('❌ 上传失败（可能被安全规则拦截）: $e');
      ToastUtil.show(i18n('firebase_account_unauthorized'));
    }
  }

  Future<void> downloadConfig() async {
    final secureUser = auth.currentUser;
    if (secureUser == null || secureUser.uid.trim().isEmpty) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }

    final FavoriteController favoriteController = Get.find<FavoriteController>();
    final BackupController backup = Get.find<BackupController>();

    await loadUploadConfig();

    if (!canUploadConfig) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    try {
      final document = await firestore.collection('users').doc(secureUser.uid).get();

      if (!document.exists) {
        ToastUtil.show(i18n('no_data'));
        return;
      }

      final data = document.data()!;
      final jsonString = data['config'];
      final jsonData = ArchethicUtils().decrypti(jsonString);
      final back = jsonDecode(jsonData) as Map<String, dynamic>;
      backup.importAllSettings(back);
      favoriteController.onRefresh();
      ToastUtil.show(i18n('download_success'));
    } catch (e) {
      developer.log('❌ 下载失败（可能被安全规则拦截）: $e');
      ToastUtil.show(i18n('firebase_account_unauthorized'));
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
