import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/account/bilibili/web_login_controller.dart';

class Utils {
  static DateFormat dateFormat = DateFormat("MM-dd HH:mm");
  static DateFormat dateFormatWithYear = DateFormat("yyyy-MM-dd HH:mm");
  static DateFormat timeFormat = DateFormat("HH:mm:ss");

  static Future<void> exitDesktopApplication() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await HivePrefUtil.flush().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('设置落盘超时: $e');
    }
    await windowManager.hide();
    if (await windowManager.isPreventClose()) {
      await windowManager.setPreventClose(false);
    }
    if (Get.isRegistered<BiliBiliWebLoginController>()) {
      final controller = Get.find<BiliBiliWebLoginController>();
      controller.showWebView.value = false;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    try {
      await trayManager.destroy().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('托盘注销超时: $e');
    }
    try {
      await windowManager.destroy().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('窗口销毁超时: $e');
    }
  }

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
    final result = await Get.dialog<bool>(
      _SharedAlertDialog(
        title: title,
        content: content,
        selectable: selectable,
        cancel: cancel,
        confirm: confirm,
        additionalActions: actions,
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
    final result = await Get.dialog<bool>(
      _SharedAlertDialog(title: title, content: content, selectable: selectable, confirm: confirm),
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
    return Get.dialog<String>(
      _EditTextDialog(initialValue: content, title: title, hintText: hintText, confirm: confirm, cancel: cancel),
    );
  }

  static Future<T?> showOptionDialog<T>(List<T> contents, T value, {String title = ''}) async {
    return Get.dialog<T>(_OptionDialog<T>(contents: contents, selectedValue: value, title: title));
  }

  static Future<bool> showExitDialog() async {
    final dontAsk = SettingsService.to.exit.dontAskExit.v;
    final exitChoose = SettingsService.to.exit.exitChoose.v;

    if (dontAsk) {
      if (exitChoose == 'exit') {
        if (await windowManager.isPreventClose()) {
          await windowManager.setPreventClose(false);
        }
        Future.microtask(exitDesktopApplication);
        return true;
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
                  await exitDesktopApplication();
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

class _SharedAlertDialog extends StatelessWidget {
  const _SharedAlertDialog({
    required this.title,
    required this.content,
    required this.selectable,
    required this.confirm,
    this.cancel,
    this.additionalActions,
  });

  final String title;
  final String content;
  final bool selectable;
  final String confirm;
  final String? cancel;
  final List<Widget>? additionalActions;

  @override
  Widget build(BuildContext context) {
    final actionWidgets = <Widget>[
      if (cancel != null)
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancel!.isEmpty ? i18n("cancel") : cancel!),
        ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(confirm.isEmpty ? i18n("confirm") : confirm),
      ),
      ...?additionalActions,
    ];

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: title.isEmpty ? null : Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: selectable ? SelectableText(content) : Text(content),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: actionWidgets,
    );
  }
}

class _OptionDialog<T> extends StatelessWidget {
  const _OptionDialog({required this.contents, required this.selectedValue, required this.title});

  final List<T> contents;
  final T selectedValue;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void select(T? value) {
      if (value != null) {
        Navigator.of(context).pop(value);
      }
    }

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: title.isEmpty ? null : Text(title),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: RadioGroup<T>(
          groupValue: selectedValue,
          onChanged: select,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < contents.length; index++)
                SimpleDialogOption(
                  key: ValueKey<String>('shared-option-$index'),
                  padding: EdgeInsets.zero,
                  onPressed: () => select(contents[index]),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Radio<T>(value: contents[index], activeColor: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(contents[index].toString(), style: theme.textTheme.bodyLarge, softWrap: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.initialValue,
    required this.title,
    required this.hintText,
    required this.confirm,
    required this.cancel,
  });

  final String initialValue;
  final String title;
  final String? hintText;
  final String confirm;
  final String cancel;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height;
    final dialogHeight = availableHeight > 40 ? availableHeight - 40 : availableHeight;
    final largeText = media.textScaler.scale(1) >= 1.6;
    final stackActions = media.size.width < 420 || largeText;
    final cancelButton = TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(widget.cancel.isNotEmpty ? widget.cancel : i18n("cancel")),
    );
    final confirmButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => Navigator.of(context).pop(_controller.text),
      child: Text(widget.confirm.isNotEmpty ? widget.confirm : i18n("confirm")),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 468, maxHeight: dialogHeight),
        child: SizedBox(
          width: 468,
          height: largeText ? dialogHeight : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: largeText ? FlexFit.tight : FlexFit.loose,
                child: SingleChildScrollView(
                  key: const ValueKey<String>('shared-edit-text-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLines: 5,
                        minLines: 4,
                        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                        decoration: InputDecoration(
                          hintText: widget.hintText ?? widget.title,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: stackActions
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [cancelButton, const SizedBox(height: 8), confirmButton],
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [cancelButton, confirmButton],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
