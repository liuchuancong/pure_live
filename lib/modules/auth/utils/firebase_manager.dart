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
import 'package:pure_live/modules/auth/models/policy_model.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

class FirebaseManager {
  static late FirebaseManager _instance;
  static const String customScheme = 'purelive';

  static const String middlePageUrl = 'https://pure-live-26c7f.web.app/auth_callback.html';
  static final PolicyModel policy = PolicyModel();

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
    await loadPolicy();
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
      schemeKey = Registry.currentUser.createKey(basePath);
      commandKey = Registry.currentUser.createKey(commandPath);
      final currentCommand = commandKey.getStringValue('');
      if (currentCommand == command) {
        return;
      }
      schemeKey.createValue(RegistryValue.string('', description ?? 'URL:$scheme Protocol'));
      schemeKey.createValue(RegistryValue.string('URL Protocol', ''));
      commandKey.createValue(RegistryValue.string('', command));
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

  Future<void> loadPolicy() async {
    try {
      final doc = await firestore.collection('config').doc('global_policy').get();
      if (doc.exists && doc.data() != null) {
        final loadedPolicy = PolicyModel.fromJson(doc.data()!);
        policy.owner = loadedPolicy.owner;
      }
    } catch (_) {}
  }

  Future<bool> loadUploadConfig() async {
    final user = Get.find<AuthController>().user;
    if (user == null) {
      canUploadConfig = false;
      return false;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final doc = await firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        canUploadConfig = true;
        return true;
      }

      final data = doc.data();
      canUploadConfig = data?['canUpload'] != false;
      return canUploadConfig;
    } catch (e) {
      debugPrint('[FirebaseManager] 从 users 集合读取权限异常(已默认放行): $e');
      canUploadConfig = true;
      return true;
    }
  }

  Future<void> uploadConfig() async {
    final AuthController authController = Get.find<AuthController>();
    if (!authController.isLogin) {
      return;
    }

    await loadUploadConfig();

    if (!canUploadConfig) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }

    final userId = authController.user!.uid;
    final BackupController backup = Get.find<BackupController>();
    final encryptData = ArchethicUtils().encrypt(jsonEncode(backup.exportAllSettings()));
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      await firestore.collection('users').doc(userId).set({
        'config': encryptData,
        'email': authController.user!.email,
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
    final AuthController authController = Get.find<AuthController>();
    final FavoriteController favoriteController = Get.find<FavoriteController>();
    final BackupController backup = Get.find<BackupController>();
    if (!authController.isLogin) {
      return;
    }
    await loadUploadConfig();
    if (!canUploadConfig) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    try {
      final document = await firestore.collection('users').doc(authController.user!.uid).get();

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

  Future<void> setAdmin(String uid) async {
    try {
      final newPolicy = PolicyModel(owner: uid);
      await firestore.collection('config').doc('global_policy').set(newPolicy.toJson(), SetOptions(merge: true));
      policy.owner = uid;
      ToastUtil.show(i18n('policy_sync_success'));
    } catch (_) {
      ToastUtil.show(i18n('policy_sync_failed'));
    }
  }

  bool isAdmin() {
    final currentUser = Get.find<AuthController>().user;
    if (currentUser == null) {
      return false;
    }
    return currentUser.uid == policy.owner;
  }
}
