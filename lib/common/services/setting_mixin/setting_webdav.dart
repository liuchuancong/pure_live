import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/services/setting_mixin/setting_part.dart';
import 'package:pure_live/common/utils/pref_util.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/iptv/src/general_utils_object_extension.dart';
import 'package:pure_live/modules/util/rx_util.dart';
import 'package:webdav_client/webdav_client.dart';

import '../../utils/snackbar_util.dart';
import '../settings_service.dart';

/// 码率
mixin SettingWebdavMixin {
  /// url
  static var webdavUrlKey = "webdavUrl";
  static var webdavUrlDefault = "https://dav.jianguoyun.com/dav/";

  /// 坚果云
  final webdavUrl = (PrefUtil.getString(webdavUrlKey) ?? webdavUrlDefault).obs;

  /// 用户名
  static var webdavUserKey = "webdavUser";
  static var webdavUserDefault = "";
  final webdavUser = (PrefUtil.getString(webdavUserKey) ?? webdavUserDefault).obs;

  /// 密码
  static var webdavPwdKey = "webdavPwd";
  static var webdavPwdDefault = "";
  final webdavPwd = (PrefUtil.getString(webdavPwdKey) ?? webdavPwdDefault).obs;

  /// 路径
  static var webdavPathKey = "webdavPath";
  static var webdavPathDefault = "pure_live";
  final webdavPath = (PrefUtil.getString(webdavPathKey) ?? webdavPathDefault).obs;

  /// webDav同步时间
  static var webdavSyncTimeKey = "webdavSyncTime";
  static var webdavSyncTimeDefault = 0;
  final webdavSyncTime = (PrefUtil.getInt(webdavSyncTimeKey) ?? webdavSyncTimeDefault).obs;

  void initWebdav(SettingPartList settingPartList) {
    webdavUrl.listen((value) {
      PrefUtil.setString(webdavUrlKey, value);
    });

    webdavUser.listen((value) {
      PrefUtil.setString(webdavUserKey, value);
    });

    webdavPwd.listen((value) {
      PrefUtil.setString(webdavPwdKey, value);
    });

    webdavPath.listen((value) {
      PrefUtil.setString(webdavPathKey, value);
    });

    webdavSyncTime.listen((value) {
      PrefUtil.setInt(webdavSyncTimeKey, value);
    });

    settingPartList.fromJsonList.add(fromJsonWebdav);
    settingPartList.toJsonList.add(toJsonWebdav);
    settingPartList.defaultConfigList.add(defaultConfigWebdav);
  }

  //// -------------- 默认
  void fromJsonWebdav(Map<String, dynamic> json) {
    webdavUrl.value = json[webdavUrlKey] ?? webdavUrlDefault;
    webdavUser.value = json[webdavUserKey] ?? webdavUserDefault;
    webdavPwd.value = json[webdavPwdKey] ?? webdavPwdDefault;
    webdavPath.value = json[webdavPathKey] ?? webdavPathDefault;
    webdavSyncTime.value = json[webdavSyncTimeKey] ?? webdavSyncTimeDefault;
  }

  void toJsonWebdav(Map<String, dynamic> json) {
    json[webdavUrlKey] = webdavUrl.value;
    json[webdavUserKey] = webdavUser.value;
    json[webdavPwdKey] = webdavPwd.value;
    json[webdavPathKey] = webdavPath.value;
    json[webdavSyncTimeKey] = webdavSyncTime.value;
  }

  void defaultConfigWebdav(Map<String, dynamic> json) {
    json[webdavUrlKey] = webdavUrlDefault;
    json[webdavUserKey] = webdavUserDefault;
    json[webdavPwdKey] = webdavPwdDefault;
    json[webdavPathKey] = webdavPathDefault;
    json[webdavSyncTimeKey] = webdavSyncTimeDefault;
  }

  Future<bool> _retryZone(Future<bool> Function() fn) async {
    int time = 1;
    while (time < 1 << 3) {
      var res = await fn();
      if (res) {
        return true;
      }
      await Future.delayed(Duration(seconds: time));
      time *= 2;
    }
    return false;
  }

  bool _isOperating = false;

  bool _haveWaitingTask = false;

  bool isMkdir = false;
  Future<void> createWebDevDir(Client client) async {
    if(!isMkdir) {
      await client.mkdirAll(webdavPath.value);
      isMkdir = true;
    }
  }

  /// Sync current data to webdav server. Return true if success.
  Future<bool> uploadData() async {
    var flag = checkWebdavConfig();
    if (!flag) return false;

    if (_haveWaitingTask) {
      return true;
    }
    if (_isOperating) {
      _haveWaitingTask = true;
      while (_isOperating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    _haveWaitingTask = false;
    _isOperating = true;

    CoreLog.d("Uploading Data");
    var client = newClient(
      webdavUrl.value,
      user: webdavUser.value,
      password: webdavPwd.value,
      debug: false,
    );
    client.setHeaders({'content-type': 'text/plain'});
    try {
      var currentDays = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 86400;
      webdavSyncTime.updateValueNotEquate(currentDays);
      await createWebDevDir(client);
      var files = await client.readDir(webdavPath.value);
      for (var file in files) {
        var name = file.name;
        if (name != null) {
          var version = name.split(".").first;
          if (version.isNum) {
            var days = int.parse(version) ~/ 86400;
            if (currentDays == days && file.path != null) {
              client.remove(file.path!);
              break;
            }
          }
        }
      }
      // CoreLog.d("currentDays: ${currentDays} ${DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 86400} ${DateTime.now().millisecondsSinceEpoch} ${DateTime.now().millisecondsSinceEpoch ~/ 1000}");
      client.write("${webdavPath.value}/$currentDays.pure_live.json", stringToUint8List(jsonEncode(SettingsService.instance.toJson())));
      SnackBarUtil.success("文件上传成功");
    } catch (e, s) {
      CoreLog.error("Failed to upload data to webdav server.\n$e\n$s");
      SnackBarUtil.error("文件上传失败");
      _isOperating = false;
      return false;
    }
    _isOperating = false;
    return true;
  }

  Uint8List stringToUint8List(String str) {
    return utf8.encode(str);
  }

  void toastError(String msg) {
    SmartDialog.showToast(msg);
    CoreLog.error(msg);
    // SnackBarUtil.error(msg);
  }

  bool checkWebdavConfig() {
    if (webdavUrl.value.isNullOrEmpty) {
      toastError("webdav Url is null!");
      return false;
    }
    if (webdavUser.value.isNullOrEmpty) {
      toastError("webdav User is null!");
      return false;
    }
    if (webdavPwd.value.isNullOrEmpty) {
      toastError("webdav Password is null!");
      return false;
    }
    // if(webdavPath.value.isNullOrEmpty) {
    //   toastError("webdav Path is null!");
    //   return false;
    // }

    return true;
  }

  Future<bool> downloadData() async {
    _isOperating = true;
    bool force = true;
    try {
      var curWebdavUrl = webdavUrl.value;
      var curWebdavUser = webdavUser.value;
      var curWebdavPwd = webdavPwd.value;
      var curWebdavPath = webdavPath.value;
      CoreLog.d("Downloading Data");
      var flag = checkWebdavConfig();
      if (!flag) return false;
      var client = newClient(
        curWebdavUrl,
        user: curWebdavUser,
        password: curWebdavPwd,
        debug: false,
      );

      client.setConnectTimeout(8000);
      try {
        await createWebDevDir(client);
        var files = await client.readDir(webdavPath.value);
        int? maxVersion;
        for (var file in files) {
          var name = file.name;
          if (name != null) {
            var version = name.split(".").first;
            if (version.isNum) {
              maxVersion = max(maxVersion ?? 0, int.parse(version));
            }
          }
        }

        final fileName = maxVersion != null ? "$maxVersion.pure_live.json" : "pure_live.json";
        webdavSyncTime.updateValueNotEquate(maxVersion ?? 0);

        var list = await client.read("$curWebdavPath/$fileName");
        var text = utf8.decode(list);
        SettingsService.instance.fromJson(jsonDecode(text));
        SnackBarUtil.success('文件下载成功');
        return true;
      } catch (e, s) {
        SnackBarUtil.error('文件下载失败');
        CoreLog.error("Failed to download data from webdav server.\n$e\n$s");
        return false;
      }
    } finally {
      _isOperating = false;
    }
  }

  void syncData() async {
    var flag = checkWebdavConfig();
    if (!flag) return;

    /// 一天只同步一次
    var currentDays = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 86400;
    var value = webdavSyncTime.value;
    if (currentDays == value) {
      return;
    }
    //webdavSyncTime.updateValueNotEquate(currentDays);

    SmartDialog.showToast("同步数据中");
    var res = await _retryZone(uploadData);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!res) {
      // SmartDialog.showToast("上传数据失败, 已禁用同步");
      SnackBarUtil.error("上传数据失败, 已禁用同步");
    } else {
      ///
    }
  }
}
