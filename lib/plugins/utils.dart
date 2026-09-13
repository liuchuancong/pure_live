import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/modules/account/bilibili/web_login_controller.dart';

class Utils {
  static DateFormat dateFormat = DateFormat("MM-dd HH:mm");
  static DateFormat dateFormatWithYear = DateFormat("yyyy-MM-dd HH:mm");
  static DateFormat timeFormat = DateFormat("HH:mm:ss");
  static Future<bool>? _activeExitFlow;

  static Future<void> exitDesktopApplication() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await HivePrefUtil.flush().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('设置落盘超时: $e');
    }
    bool? wasVisible;
    try {
      wasVisible = await windowManager.isVisible();
    } catch (e) {
      debugPrint('窗口可见状态读取失败: $e');
    }

    var windowHidden = false;
    var preventCloseChanged = false;
    BiliBiliWebLoginController? webLoginController;
    bool? webViewWasVisible;
    try {
      await windowManager.hide();
      windowHidden = true;
      if (await windowManager.isPreventClose()) {
        await windowManager.setPreventClose(false);
        preventCloseChanged = true;
      }
      if (Get.isRegistered<BiliBiliWebLoginController>()) {
        webLoginController = Get.find<BiliBiliWebLoginController>();
        webViewWasVisible = webLoginController.showWebView.value;
        webLoginController.showWebView.value = false;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      try {
        await trayManager.destroy().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('托盘注销超时: $e');
      }
      await windowManager.destroy().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('桌面退出操作失败: $e');
      if (webLoginController != null && webViewWasVisible != null) {
        webLoginController.showWebView.value = webViewWasVisible;
      }
      if (preventCloseChanged) {
        try {
          await windowManager.setPreventClose(true);
        } catch (restoreError) {
          debugPrint('窗口关闭拦截恢复失败: $restoreError');
        }
      }
      if (windowHidden && wasVisible != false) {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (restoreError) {
          debugPrint('窗口可见状态恢复失败: $restoreError');
        }
      }
      rethrow;
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
      } else {
        await windowManager.minimize();
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

  static Future<bool> showExitDialog() {
    final active = _activeExitFlow;
    if (active != null) return active;

    late final Future<bool> tracked;
    tracked = _showExitDialog().whenComplete(() {
      if (identical(_activeExitFlow, tracked)) {
        _activeExitFlow = null;
      }
    });
    _activeExitFlow = tracked;
    return tracked;
  }

  static Future<bool> _showExitDialog() async {
    final settings = SettingsService.to.exit;
    final rememberedAction = ExitSettingsController.normalizeExitAction(settings.exitChoose.v);

    if (settings.dontAskExit.v) {
      final succeeded = await _executeExitAction(rememberedAction);
      if (!succeeded) {
        try {
          await _persistExitPreference(settings, dontAskAgain: false, action: rememberedAction);
        } catch (error) {
          debugPrint('退出偏好恢复失败: $error');
        }
      }
      return succeeded;
    }

    final selection = await Get.dialog<_ExitDialogSelection>(
      _ExitDecisionDialog(initialDontAskAgain: settings.dontAskExit.v),
    );
    if (selection == null) return false;

    final previousDontAsk = settings.dontAskExit.v;
    final previousAction = settings.exitChoose.v;
    try {
      await _persistExitPreference(settings, dontAskAgain: selection.dontAskAgain, action: selection.action);
    } catch (error) {
      _reportExitActionFailure(error);
      return false;
    }

    final succeeded = await _executeExitAction(selection.action);
    if (!succeeded) {
      try {
        await _persistExitPreference(settings, dontAskAgain: previousDontAsk, action: previousAction);
      } catch (error) {
        debugPrint('退出偏好回滚失败: $error');
      }
    }
    return succeeded;
  }

  static Future<void> _persistExitPreference(
    ExitSettingsController settings, {
    required bool dontAskAgain,
    required String action,
  }) {
    return HivePrefUtil.persistBatch(() {
      settings.setDontAskExit(dontAskAgain);
      settings.setExitAction(action);
    });
  }

  static Future<bool> _executeExitAction(String action) async {
    try {
      if (action == ExitSettingsController.minimizeAction) {
        await _minimizeOrHideDesktopWindow();
      } else {
        await exitDesktopApplication();
      }
      return true;
    } catch (error) {
      _reportExitActionFailure(error);
      return false;
    }
  }

  static void _reportExitActionFailure(Object error) {
    debugPrint('窗口关闭操作失败: $error');
    ToastUtil.show(i18n('window_close_action_failed'));
  }
}

class _ExitDialogSelection {
  const _ExitDialogSelection({required this.action, required this.dontAskAgain});

  final String action;
  final bool dontAskAgain;
}

class _ExitDecisionDialog extends StatefulWidget {
  const _ExitDecisionDialog({required this.initialDontAskAgain});

  final bool initialDontAskAgain;

  @override
  State<_ExitDecisionDialog> createState() => _ExitDecisionDialogState();
}

class _ExitDecisionDialogState extends State<_ExitDecisionDialog> {
  late bool _dontAskAgain;

  @override
  void initState() {
    super.initState();
    _dontAskAgain = widget.initialDontAskAgain;
  }

  void _select(String action) {
    Navigator.of(context).pop(_ExitDialogSelection(action: action, dontAskAgain: _dontAskAgain));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(i18n("tip"), style: theme.textTheme.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(i18n("confirm_exit"), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const Divider(height: 1),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i18n("dont_ask_again"), style: theme.textTheme.titleSmall),
              value: _dontAskAgain,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _dontAskAgain = value);
                }
              },
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _select(ExitSettingsController.minimizeAction),
          child: Text(i18n("minimize")),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => _select(ExitSettingsController.exitAction),
          child: Text(i18n("exit_app")),
        ),
      ],
    );
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
