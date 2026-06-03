import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:easy_localization/easy_localization.dart';

class Utils {
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

  static Future<void> _minimizeOrHideDesktopWindow() async {
    // macOS 上更符合习惯的是最小化到 Dock；直接 hide 在没有托盘/菜单栏入口时
    // 容易让用户误以为 App 退出。
    if (Platform.isMacOS) {
      await windowManager.minimize();
    } else {
      if (await windowManager.isPreventClose()) {
        await windowManager.hide();
      }
    }
  }

  static Future<bool> showAlertDialog(
    String content, {
    String title = '',
    String confirm = '',
    String cancel = '',
    bool selectable = false,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    var result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: selectable ? SelectableText(content) : Text(content),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: (() => Navigator.of(Get.context!).pop(false)),
            child: Text(cancel.isEmpty ? i18n("cancel") : cancel),
          ),
          TextButton(
            onPressed: (() => Navigator.of(Get.context!).pop(true)),
            child: Text(confirm.isEmpty ? i18n("confirm") : confirm),
          ),
          ...?actions,
        ],
      ),
      barrierDismissible: barrierDismissible,
    );
    return result ?? false;
  }

  /// 提示弹窗
  /// - `content` 内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容，留空为确定
  static Future<bool> showMessageDialog(
    String content, {
    String title = '',
    String confirm = '',
    bool selectable = false,
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: selectable ? SelectableText(content) : Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(Get.context!).pop(true);
            },
            child: Text(confirm.isEmpty ? i18n("confirm") : confirm),
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
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(controller.view),
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
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
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
                      SmartDialog.dismiss(status: SmartStatus.allCustom).then((value) => onDismiss?.call());
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(title, style: Get.textTheme.titleMedium),
                ),
                Divider(height: 1, color: Colors.grey.withValues(alpha: .1)),
                Expanded(child: child),
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
  }) async {
    final TextEditingController textEditingController = TextEditingController(text: content);
    final res = await Get.dialog(
      AlertDialog(
        title: Text(title),
        titleTextStyle: Get.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 18),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: textEditingController,
            autofocus: true,
            maxLines: 5,
            minLines: 4,
            style: Get.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              hintText: hintText ?? title,
              hintStyle: Get.textTheme.bodyMedium?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Get.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Get.theme.colorScheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(Get.context!).pop();
            },
            child: Text(cancel.isNotEmpty ? cancel : i18n("cancel")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Get.theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(Get.context!).pop(textEditingController.text);
            },
            child: Text(confirm.isNotEmpty ? confirm : i18n("confirm")),
          ),
        ],
      ),
    );
    return res;
  }

  static Future<T?> showOptionDialog<T>(List<T> contents, T value, {String title = ''}) async {
    var result = await Get.dialog(
      SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: value,
            onChanged: (T? e) {
              if (e != null) {
                Navigator.of(Get.context!).pop(e);
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contents.map<Widget>((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<T>(value: e, activeColor: Theme.of(Get.context!).colorScheme.primary),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(Get.context!).pop(e);
                        },
                        child: Text(e.toString(), style: Theme.of(Get.context!).textTheme.bodyLarge),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  static Future<bool> showExitDialog() async {
    final dontAsk = SettingsService.to.exit.dontAskExit.v;
    final exitChoose = SettingsService.to.exit.exitChoose.v;

    if (dontAsk) {
      if (exitChoose == 'exit') {
        if (await windowManager.isPreventClose()) {
          await windowManager.setPreventClose(false);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          exit(0);
        });
      } else if (exitChoose == 'minimize') {
        await _minimizeOrHideDesktopWindow();
        return true;
      }
    }
    bool shouldNotAskAgain = false;
    var result = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(i18n("tip"), style: Get.textTheme.titleLarge),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n("confirm_exit"), style: Get.textTheme.titleMedium),
                      SizedBox(height: 12),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: Text(i18n("dont_ask_again"), style: Get.textTheme.titleSmall),
                        value: shouldNotAskAgain,
                        onChanged: (bool? value) {
                          setState(() {
                            shouldNotAskAgain = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () async {
                  SettingsService.to.exit.dontAskExit.v = shouldNotAskAgain;
                  SettingsService.to.exit.exitChoose.v = 'minimize';
                  Navigator.of(context).pop();
                  Future.delayed(const Duration(milliseconds: 200), () async {
                    await _minimizeOrHideDesktopWindow();
                  });
                },
                child: Text(i18n("minimize")),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {
                  SettingsService.to.exit.dontAskExit.v = shouldNotAskAgain;
                  SettingsService.to.exit.exitChoose.v = 'exit';
                  Navigator.of(context).pop();
                  await windowManager.hide();

                  await windowManager.setPreventClose(false);
                  trayManager.destroy().catchError((e) => debugPrint('托盘注销失败: $e'));
                  windowManager.close().catchError((e) => debugPrint('窗口关闭失败: $e'));
                },
                child: Text(i18n("exit_app")),
              ),
            ],
          );
        },
      ),
    );
    return result ?? false;
  }
}
