import 'dart:io';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/desktop_tray_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/web_login_controller.dart';
import 'package:pure_live/core/config/exit_settings_controller.dart';

class DesktopExitFlow {
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
        DesktopTrayService.dispose();
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

  static Future<void> _minimizeOrHideDesktopWindow() async {
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
