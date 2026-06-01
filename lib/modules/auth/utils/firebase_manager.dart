import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pure_live/plugins/archethic.dart';
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
  }

  void signOut() {
    auth.signOut().then((_) {
      Get.offAllNamed(RoutePath.kInitial);
    });
  }

  Future<void> loadPolicy() async {
    try {
      final doc = await firestore.collection('config').doc('global_policy').get();

      if (doc.exists) {
        policy.owner = doc.data()?['owner_uid'] ?? '';
      }
    } catch (_) {}
  }

  Future<bool> loadUploadConfig() async {
    final user = Get.find<AuthController>().user;

    try {
      final doc = await firestore.collection('permissions').doc(user!.uid).get();

      if (!doc.exists) {
        canUploadConfig = false;
        return false;
      }

      canUploadConfig = doc.data()?['canUpload'] == true;

      return canUploadConfig;
    } catch (_) {
      canUploadConfig = false;
      return false;
    }
  }

  Future<void> uploadConfig() async {
    final AuthController authController = Get.find<AuthController>();

    if (!authController.isLogin) {
      return;
    }

    if (!canUploadConfig) {
      // 这里修改为 firebase
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
    } catch (_) {
      ToastUtil.show(i18n('webdav_upload_failed'));
    }
  }

  Future<void> downloadConfig() async {
    final AuthController authController = Get.find<AuthController>();

    final FavoriteController favoriteController = Get.find<FavoriteController>();

    final BackupController backup = Get.find<BackupController>();

    if (!authController.isLogin) {
      return;
    }

    if (!canUploadConfig) {
      // 这里修改为 firebase
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
    } catch (_) {
      ToastUtil.show(i18n('download_failed'));
    }
  }

  Future<void> grantUploadPermission(String uid) async {
    await firestore.collection('permissions').doc(uid).set({'canUpload': true, 'role': 'user'});
  }

  Future<void> revokeUploadPermission(String uid) async {
    await firestore.collection('permissions').doc(uid).delete();
  }

  Future<void> setAdmin(String uid) async {
    await firestore.collection('config').doc('global_policy').set({'owner_uid': uid});

    policy.owner = uid;
  }

  bool isAdmin() {
    final user = auth.currentUser;

    if (user == null) {
      return false;
    }

    return user.uid == policy.owner;
  }
}
