import 'dart:async';
import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/archethic.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/common/utils/supabase_policy.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

class SupaBaseManager {
  String supabaseUrl = '';
  String supabaseKey = '';
  static late SupaBaseManager _instance;
  static late SupabasePolicy supabasePolicy;
  static bool canUploadConfig = false;
  SupaBaseManager._internal();
  late Supabase supabase;
  SupabaseClient get client => Supabase.instance.client;
  //单例模式，只创建一次实例
  static SupaBaseManager getInstance() {
    _instance = SupaBaseManager._internal();
    return _instance;
  }

  SupaBaseManager();
  Future initial() async {
    var mapString = await rootBundle.loadString("assets/keystore/supabase.json");
    supabasePolicy = SupabasePolicy.fromJson(jsonDecode(mapString)); // 获取配置信息
    await Supabase.initialize(url: supabasePolicy.supabaseUrl, anonKey: supabasePolicy.supabaseKey);
  }

  void signOut() {
    client.auth.signOut().then((value) {
      Get.offAllNamed(RoutePath.kInitial);
    });
  }

  Future<bool> loadUploadConfig() async {
    final user = Get.find<AuthController>().user;
    List<dynamic> data = await client
        .from(supabasePolicy.checkTable)
        .select()
        .eq(supabasePolicy.email, user.email as Object);
    if (data.isNotEmpty) {
      canUploadConfig = true;
      return true;
    }
    canUploadConfig = false;
    return false;
  }

  Future<void> uploadConfig() async {
    final AuthController authController = Get.find<AuthController>();
    if (!authController.isLogin) {
      return;
    }
    if (!canUploadConfig) {
      ToastUtil.show(i18n('supabase_account_unauthorized'));
      return;
    }
    final userId = Get.find<AuthController>().userId;
    final BackupController backup = Get.find<BackupController>();
    List<dynamic> data = await client.from(supabasePolicy.tableName).select().eq(supabasePolicy.userId, userId);
    final encryptData = ArchethicUtils().encrypt(jsonEncode(backup.exportAllSettings()));
    DateTime currentTime = DateTime.now();
    String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(currentTime);
    if (data.isNotEmpty) {
      client
          .from(supabasePolicy.tableName)
          .update({
            supabasePolicy.config: encryptData,
            supabasePolicy.email: authController.user.email,
            supabasePolicy.updateAt: formattedTime,
            supabasePolicy.version: VersionUtil.version,
          })
          .eq(supabasePolicy.userId, userId)
          .then(
            (value) => ToastUtil.show(i18n('webdav_upload_success')),
            onError: (err) {
              ToastUtil.show(i18n('webdav_upload_failed'));
            },
          )
          .catchError((err) => {ToastUtil.show(i18n('webdav_upload_failed'))});
    } else {
      client
          .from(supabasePolicy.tableName)
          .insert({
            supabasePolicy.config: encryptData,
            supabasePolicy.email: authController.user.email,
            supabasePolicy.updateAt: formattedTime,
            supabasePolicy.version: VersionUtil.version,
          })
          .then(
            (value) => ToastUtil.show(i18n('webdav_upload_success')),
            onError: (err) {
              ToastUtil.show(i18n('webdav_upload_failed'));
            },
          );
    }
  }

  Future<void> readConfig() async {
    final AuthController authController = Get.find<AuthController>();
    final FavoriteController favoriteController = Get.find<FavoriteController>();
    final BackupController backup = Get.find<BackupController>();

    if (authController.isLogin) {
      if (!canUploadConfig) {
        ToastUtil.show(i18n('supabase_account_unauthorized'));
        return;
      }

      List<dynamic> data = await client
          .from(supabasePolicy.tableName)
          .select()
          .eq(supabasePolicy.userId, authController.user.id)
          .then(
            (value) => value,
            onError: (err) {
              ToastUtil.show(i18n('download_failed'));
            },
          );
      if (data.isNotEmpty) {
        ToastUtil.show(i18n('download_success'));
        String jsonString = data[0][supabasePolicy.config];
        final jsonData = ArchethicUtils().decrypti(jsonString);
        Map<String, dynamic> back = jsonDecode(jsonData);
        backup.importAllSettings(back);
        favoriteController.onRefresh();
      } else {
        ToastUtil.show(i18n('no_data'));
      }
    }
  }
}
