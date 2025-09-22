import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/widgets/right_sheet.dart';
import 'package:pure_live/core/common/common_request.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'app_style.dart';

typedef TextValidate = bool Function(String text);

class Utils {
  static late PackageInfo packageInfo;
  static DateFormat dateFormat = DateFormat("MM-dd HH:mm");
  static DateFormat dateFormatWithYear = DateFormat("yyyy-MM-dd HH:mm");
  static DateFormat timeFormat = DateFormat("HH:mm:ss");

  /// 处理时间
  static String parseTime(DateTime? dt) {
    if (dt == null) {
      return "";
    }

    var dtNow = DateTime.now();
    if (dt.year == dtNow.year && dt.month == dtNow.month && dt.day == dtNow.day) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    if (dt.year == dtNow.year) {
      return dateFormat.format(dt);
    }

    return dateFormatWithYear.format(dt);
  }

  /// 提示弹窗
  /// - `content` 内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容，留空为确定
  /// - `cancel` 取消按钮内容，留空为取消
  static Future<bool> showAlertDialog(
    String content, {
    String title = '',
    String confirm = '',
    String cancel = '',
    bool selectable = false,
    List<Widget>? actions,
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Container(
          constraints: const BoxConstraints(
            maxHeight: 400,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: AppStyle.edgeInsetsV12,
              child: selectable ? SelectableText(content) : Text(content),
            ),
          ),
        ),
        actions: [
          ...?actions,
          TextButton(
            onPressed: (() => Navigator.of(Get.context!).pop(false)),
            child: Text(cancel.isEmpty ? S.current.cancel : cancel),
          ),
          TextButton(
            onPressed: (() => Navigator.of(Get.context!).pop(true)),
            child: Text(confirm.isEmpty ? S.current.confirm : confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 提示弹窗
  /// - `content` 内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容，留空为确定
  static Future<bool> showMessageDialog(String content, {String title = '', String confirm = '', bool selectable = false}) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Padding(
          padding: AppStyle.edgeInsetsV12,
          child: selectable ? SelectableText(content) : Text(content),
        ),
        actions: [
          TextButton(
            onPressed: (() => Navigator.of(Get.context!).pop(true)),
            child: Text(confirm.isEmpty ? S.current.confirm : confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void showRightDialog({
    required String title,
    Function()? onDismiss,
    required Widget child,
    double width = 320,
    bool useSystem = false,
  }) {
    SmartDialog.show(
      alignment: Alignment.topRight,
      animationBuilder: (controller, child, animationParam) {
        //从右到左
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(controller.view),
          child: child,
        );
      },
      useSystem: useSystem,
      maskColor: Colors.transparent,
      animationTime: const Duration(milliseconds: 200),
      builder: (context) => Container(
        width: width + MediaQuery.of(context).padding.right,
        padding: EdgeInsets.only(right: MediaQuery.of(context).padding.right),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SafeArea(
          left: false,
          right: false,
          child: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.zero),
            child: Column(
              children: [
                ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  leading: IconButton(
                    onPressed: () {
                      SmartDialog.dismiss(status: SmartStatus.allCustom).then(
                        (value) => onDismiss?.call(),
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(
                    title,
                    style: Get.textTheme.titleMedium,
                  ),
                ),
                Divider(
                  height: 1,
                  color: Colors.grey.withValues(alpha: .1),
                ),
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void hideRightDialog() {
    SmartDialog.dismiss(status: SmartStatus.allCustom);
  }

  static Future showBottomSheet({
    required String title,
    required Widget child,
    double maxWidth = 600,
    Color? color,
    bool isFull = false,
  }) async {
    var result = await showModalBottomSheet(
      context: Get.context!,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      isScrollControlled: isFull,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      backgroundColor: color,
      builder: (_) => Column(
        children: [
          if (!title.isNullOrEmpty)
            ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(Get.context!);
                },
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(
                title,
                style: Get.textTheme.titleMedium,
              ),
              trailing: IconButton(
                onPressed: () {
                  Navigator.pop(Get.context!);
                },
                icon: const Icon(Icons.close),
              ),
            ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
    return result;
  }

  static Future showRightSheet({
    required String title,
    required Widget child,
    double maxWidth = 320,
    Color? color,
  }) async {
    var result = await showModalRightSheet(
      context: Get.context!,
      clickEmptyPop: true,
      useRootNavigator: true,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      backgroundColor: color,
      builder: (context) => Column(
        children: [
          if (!title.isNullOrEmpty)
            ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(Get.context!);
                },
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(
                title,
                style: Get.textTheme.titleMedium,
              ),
            ),
          Divider(
            height: 1,
            color: Colors.grey.withValues(alpha: .1),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
    return result;
  }

  static Future showRightOrBottomSheet({
    required String title,
    required Widget child,
    double bottomMaxWidth = 600,
    double? rightMaxWidth,
    Color? color,
    bool isFull = false,
  }) async {
    var size2 = MediaQuery.of(Get.context!).size;
    var width = size2.width;
    var height = size2.height;
    if(isFull) {
      bottomMaxWidth = width;
      rightMaxWidth = width;
    }
    if (width <= height) {
      return showBottomSheet(title: title, child: child, maxWidth: bottomMaxWidth, color: color, isFull: isFull);
    }
    rightMaxWidth ??= width / 2;
    return showRightSheet(title: title, child: child, maxWidth: rightMaxWidth, color: color);
  }

  /// 文本编辑的弹窗
  /// - `content` 编辑框默认的内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容
  /// - `cancel` 取消按钮内容
  static Future<String?> showEditTextDialog(
    String content, {
    String title = '',
    String? hintText,
    String confirm = '',
    String cancel = '',
    TextValidate? validate,
  }) async {
    final TextEditingController textEditingController = TextEditingController(text: content);
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Padding(
          padding: AppStyle.edgeInsetsT12,
          child: TextField(
            controller: textEditingController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              //prefixText: title,
              contentPadding: AppStyle.edgeInsetsA12,
              hintText: hintText ?? title,
            ),
            // style: TextStyle(
            //     height: 1.0,
            //     color: Get.isDarkMode ? Colors.white : Colors.black),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(Get.context!).pop(),
            child: Text(S.current.cancel),
          ),
          TextButton(
            onPressed: () {
              if (validate != null && !validate(textEditingController.text)) {
                return;
              }
              Navigator.of(Get.context!).pop(textEditingController.text);
            },
            child: Text(S.current.confirm),
          ),
        ],
      ),
      // barrierColor:
      //     Get.isDarkMode ? Colors.grey.withValues(alpha: .3) : Colors.black38,
    );
    return result;
  }

  static Future<T?> showOptionDialog<T>(
    List<T> contents,
    T value, {
    String title = '',
  }) async {
    var result = await Get.dialog(
      SimpleDialog(
        title: Text(title),
        children: contents
            .map(
              (e) => RadioListTile<T>(
                title: Text(e.toString()),
                value: e,
                groupValue: value,
                onChanged: (e) {
                  Navigator.of(Get.context!).pop(e);
                },
              ),
            )
            .toList(),
      ),
    );
    return result;
  }

  static Future showStatement() async {
    var text = await rootBundle.loadString("assets/statement.txt");

    var result = await showAlertDialog(
      text,
      selectable: true,
      title: S.current.disclaimer,
      confirm: S.current.read_and_agree,
      cancel: S.current.exit,
    );
    if (!result) {
      exit(0);
    }
  }

  static Future<T?> showMapOptionDialog<T>(
    Map<T, String> contents,
    T value, {
    String title = '',
  }) async {
    var result = await Get.dialog(
      SimpleDialog(
        title: Text(title),
        children: contents.keys
            .map(
              (e) => RadioListTile<T>(
                title: Text((contents[e] ?? '-').tr),
                value: e,
                groupValue: value,
                onChanged: (e) {
                  Navigator.of(Get.context!).pop(e);
                },
              ),
            )
            .toList(),
      ),
    );
    return result;
  }

  static void checkUpdate({bool showMsg = false}) async {
    try {
      int currentVer = Utils.parseVersion(packageInfo.version);
      CommonRequest request = CommonRequest();
      var versionInfo = await request.checkUpdate();
      if (versionInfo.versionNum > currentVer) {
        Get.dialog(
          AlertDialog(
            title: Text(
              S.current.found_new_version_format(versionInfo.version),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            content: Text(
              versionInfo.versionDesc,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actionsPadding: AppStyle.edgeInsetsH12,
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(Get.context!).pop();
                      },
                      child: Text(S.current.cancel),
                    ),
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                      ),
                      onPressed: () {
                        launchUrlString(
                          versionInfo.downloadUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Text(S.current.update),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        if (showMsg) {
          SmartDialog.showToast(S.current.is_new_version);
        }
      }
    } catch (e) {
      CoreLog.logPrint(e);
      if (showMsg) {
        SmartDialog.showToast(S.current.check_update_failed);
      }
    }
  }

  static int parseVersion(String version) {
    var sp = version.split('.');
    var num = "";
    for (var item in sp) {
      num = num + item.padLeft(2, '0');
    }
    return int.parse(num);
  }

  static String onlineToString(int num) {
    if (num >= 10000) {
      return "${(num / 10000.0).toStringAsFixed(1)}万";
    }
    return num.toString();
  }

  /// 检查相册权限
  static Future<bool> checkPhotoPermission() async {
    try {
      if (!Platform.isIOS) {
        return true;
      }
      var status = await Permission.photos.status;
      if (status == PermissionStatus.granted) {
        return true;
      }
      status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      } else {
        SmartDialog.showToast(
          S.current.grant_access_album,
        );
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  /// 检查文件权限
  static Future<bool> checkStorgePermission() async {
    try {
      if (!Platform.isAndroid) {
        return true;
      }
      Permission permission = Permission.storage;
      var androidIndo = await deviceInfo.androidInfo;
      if (androidIndo.version.sdkInt >= 33) {
        permission = Permission.manageExternalStorage;
      }

      var status = await permission.status;
      if (status == PermissionStatus.granted) {
        return true;
      }
      status = await permission.request();
      if (status.isGranted) {
        return true;
      } else {
        SmartDialog.showToast(
          S.current.grant_access_file,
        );
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  ///16进制颜色转换
  static Color convertHexColor(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 4) {
      hexColor = "00$hexColor";
    }

    if (hexColor.length == 6) {
      var R = int.parse(hexColor.substring(0, 2), radix: 16);
      var G = int.parse(hexColor.substring(2, 4), radix: 16);
      var B = int.parse(hexColor.substring(4, 6), radix: 16);
      return Color.fromARGB(255, R, G, B);
    }
    if (hexColor.length == 8) {
      var A = int.parse(hexColor.substring(0, 2), radix: 16);
      var R = int.parse(hexColor.substring(2, 4), radix: 16);
      var G = int.parse(hexColor.substring(4, 6), radix: 16);
      var B = int.parse(hexColor.substring(6, 8), radix: 16);

      return Color.fromARGB(A, R, G, B);
    }

    return Colors.white;
  }

  /// 复制内容到剪贴板
  static void copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      SmartDialog.showToast(S.current.copy_to_clipboard);
    } catch (e) {
      CoreLog.logPrint(e);
      SmartDialog.showToast("${S.current.copy_to_clipboard_failed}: $e");
    }
  }

  /// 获取剪贴板内容
  static Future<String?> getClipboard() async {
    try {
      var content = await Clipboard.getData(Clipboard.kTextPlain);
      if (content == null) {
        SmartDialog.showToast(S.current.unable_to_read_clipboard_contents);
        return null;
      }
      return content.text;
    } catch (e) {
      CoreLog.logPrint(e);
      SmartDialog.showToast("${S.current.reading_clipboard_content_failed}：$e");
    }
    return null;
  }

  static bool isRegexFormat(String keyword) {
    return keyword.startsWith('/') && keyword.endsWith('/') && keyword.length > 2;
  }

  static String removeRegexFormat(String keyword) {
    return keyword.substring(1, keyword.length - 1);
  }

  static String parseFileSize(int size) {
    if (size < 1024) {
      return "$size B";
    }
    if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(2)} KB";
    }
    if (size < 1024 * 1024 * 1024) {
      return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
    }
    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
