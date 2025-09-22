import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/archethic.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/common/utils/supabase_policy.dart';

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
    await Supabase.initialize(
      url: supabasePolicy.supabaseUrl,
      anonKey: supabasePolicy.supabaseKey,
    );
  }

  void signOut() {
    client.auth.signOut().then((value) {
      Get.offAllNamed(RoutePath.kInitial);
    });
  }

  Future<bool> loadUploadConfig() async {
    final user = Get.find<AuthController>().user;
    List<dynamic> data =
        await client.from(supabasePolicy.checkTable).select().eq(supabasePolicy.email, user.email as Object);
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
      SmartDialog.showToast('未开放,请与管理员联系');
      return;
    }
    final userId = Get.find<AuthController>().userId;
    final SettingsService service = Get.find<SettingsService>();
    List<dynamic> data = await client.from(supabasePolicy.tableName).select().eq(supabasePolicy.userId, userId);
    final encryptData = ArchethicUtils().encrypt(jsonEncode(service.toJson()));
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
          .then((value) => SmartDialog.showToast('上传成功'), onError: (err) {
            SmartDialog.showToast('上传失败,请稍后重试');
          })
          .catchError((err) => {SmartDialog.showToast('上传失败,请稍后重试')});
    } else {
      client.from(supabasePolicy.tableName).insert({
        supabasePolicy.config: encryptData,
        supabasePolicy.email: authController.user.email,
        supabasePolicy.updateAt: formattedTime,
        supabasePolicy.version: VersionUtil.version,
      }).then((value) => SmartDialog.showToast('上传成功'), onError: (err) {
        SmartDialog.showToast('上传失败,请稍后重试');
      });
    }
  }

  Future<void> readConfig() async {
    final AuthController authController = Get.find<AuthController>();
    final FavoriteController favoriteController = Get.find<FavoriteController>();
    if (authController.isLogin) {
      if (!canUploadConfig) {
        SmartDialog.showToast('未开放,请与管理员联系');
        return;
      }

      final SettingsService service = Get.find<SettingsService>();
      List<dynamic> data = await client
          .from(supabasePolicy.tableName)
          .select()
          .eq(supabasePolicy.userId, authController.user.id)
          .then((value) => value, onError: (err) {
        SmartDialog.showToast('下载失败,请稍后重试');
      });
      if (data.isNotEmpty) {
        SmartDialog.showToast('下载成功');
        String jsonString = data[0][supabasePolicy.config];
        final jsonData = ArchethicUtils().decrypti(jsonString);
        Map<String, dynamic> back = jsonDecode(jsonData);
        service.fromJson(back);
        favoriteController.onRefresh();
      } else {
        SmartDialog.showToast('无数据');
      }
    }
  }
}
