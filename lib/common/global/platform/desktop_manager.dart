import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';

class DesktopManager {
  static State? _currentState;

  static Future<void> initialize() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      await Window.initialize();

      const WindowOptions windowOptions = WindowOptions(
        size: Size(1080, 720),
        minimumSize: Size(400, 300),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setBackgroundColor(Colors.transparent);
        if (Platform.isMacOS) {
          await Window.setEffect(
            effect: WindowEffect.hudWindow,
            dark: PlatformDispatcher.instance.platformBrightness == Brightness.dark,
          );
          Window.setBlurViewState(MacOSBlurViewState.active);
        }
      });

      await _initTray();
    } catch (e) {
      debugPrint('桌面端初始化失败: $e');
    }
  }

  static Future<void> postInitialize() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      if (PlatformUtils.isWindows) {
        doWhenWindowReady(() {
          final win = appWindow;
          win.size = const Size(1080, 720);
          win.minSize = const Size(400, 300);
          win.alignment = Alignment.center;
          win.show();
          if (Platform.isWindows) {
            Window.setEffect(
              effect: WindowEffect.mica,
              dark: PlatformDispatcher.instance.platformBrightness == Brightness.dark,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('桌面端后初始化失败: $e');
    }
  }

  static void initializeListeners(State state) {
    if (!PlatformUtils.isDesktop) return;

    _currentState = state;
    if (state is WindowListener) {
      windowManager.addListener(state as WindowListener);
    }
    if (state is TrayListener) {
      trayManager.addListener(state as TrayListener);
    }
  }

  static void disposeListeners() {
    if (!PlatformUtils.isDesktop || _currentState == null) return;

    if (_currentState is WindowListener) {
      windowManager.removeListener(_currentState as WindowListener);
    }
    if (_currentState is TrayListener) {
      trayManager.removeListener(_currentState as TrayListener);
    }
    _currentState = null;
  }

  static Widget buildWithTitleBar(Widget? child) {
    return Obx(() {
      bool fullscreen = GlobalPlayerState.to.isFullscreen.value;
      bool isPipModel = GlobalPlayerState.to.isPipMode.value;
      if (!PlatformUtils.isWindows) {
        return child ?? const SizedBox.shrink();
      }
      return Column(
        children: [
          if (!fullscreen && !isPipModel) const CustomTitleBar(),
          if (child != null) Expanded(child: child),
        ],
      );
    });
  }

  static Future<void> _initTray() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await trayManager.setIcon('assets/icons/app_icon.ico');
    } catch (e) {
      debugPrint('系统托盘初始化失败: $e');
    }
  }

  static Future<void> updateTray() async {
    if (!PlatformUtils.isDesktop) return;

    await trayManager.setToolTip('纯粹直播');
    try {
      bool isWindowVisible = await windowManager.isVisible();
      Menu menu = Menu(
        items: [
          MenuItem(key: isWindowVisible ? 'hide_window' : 'show_window', label: isWindowVisible ? '隐藏窗口' : '显示窗口'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: '退出应用'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('系统托盘更新失败: $e');
    }
  }

  static Future<void> handleTrayMenuClick(MenuItem menuItem) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      switch (menuItem.key) {
        case 'show_window':
          await windowManager.show();
          break;
        case 'hide_window':
          await windowManager.hide();
          break;
        case 'exit_app':
          await trayManager.destroy();
          await windowManager.setPreventClose(false);
          await windowManager.close();
          break;
      }
    } catch (e) {
      debugPrint('托盘菜单处理失败: $e');
    }
  }

  static Future<void> handleWindowClose() async {
    if (!PlatformUtils.isDesktop) return;
    await Utils.showExitDialog();
  }

  static Future<void> handleTrayIconClick() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      bool isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.focus();
      } else {
        await windowManager.show();
        await windowManager.setSkipTaskbar(false);
      }
    } catch (e) {
      debugPrint('托盘图标点击处理失败: $e');
    }
  }

  static Future<void> handleTrayRightClick() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await updateTray();
      await trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('托盘右键点击处理失败: $e');
    }
  }

  static Future<void> hideWindow() async {
    if (!PlatformUtils.isDesktop) return;
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('隐藏窗口失败: $e');
    }
  }

  static Future<void> showWindow() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await windowManager.show();
    } catch (e) {
      debugPrint('显示窗口失败: $e');
    }
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      bool isFull = GlobalPlayerState.to.isWindowFullscreen.value;

      // 背景色控制
      final Color bgColor = isFull || isDark ? Colors.black : theme.scaffoldBackgroundColor;
      final Color baseIconColor = isFull || isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

      // 普通按钮颜色配置
      final buttonColors = WindowButtonColors(
        iconNormal: baseIconColor,
        mouseOver: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.1),
        mouseDown: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade300,
        iconMouseOver: isDark ? Colors.white : theme.colorScheme.primary,
        iconMouseDown: isDark ? Colors.white : theme.colorScheme.primary,
      );

      // 关闭按钮颜色配置
      final closeButtonColors = WindowButtonColors(
        iconNormal: baseIconColor,
        mouseOver: const Color(0xFFD32F2F),
        mouseDown: const Color(0xFFB71C1C),
        iconMouseOver: Colors.white,
        iconMouseDown: Colors.white,
      );

      return Container(
        height: 32,
        color: bgColor,
        child: WindowTitleBarBox(
          child: Row(
            children: [
              // 拖动区域
              Expanded(
                child: MoveWindow(
                  child: Container(
                    padding: const EdgeInsets.only(left: 12),
                    alignment: Alignment.centerLeft,
                    child: isFull
                        ? null
                        : Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final url = Uri.parse('https://github.com/liuchuancong/pure_live');
                                if (await canLaunchUrl(url)) await launchUrl(url);
                              },
                              child: Text(
                                "Pure Live",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: baseIconColor,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                  decorationColor: baseIconColor,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // 右侧控制按钮
              Row(
                children: [
                  MinimizeWindowButton(colors: buttonColors, onPressed: () => windowManager.minimize()),
                  _MaximizeButton(colors: buttonColors),
                  CloseWindowButton(colors: closeButtonColors, onPressed: () => DesktopManager.handleWindowClose()),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _MaximizeButton extends StatelessWidget {
  final WindowButtonColors colors;
  const _MaximizeButton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return MaximizeWindowButton(
      colors: colors,
      onPressed: () async {
        if (await windowManager.isMaximized()) {
          windowManager.restore();
        } else {
          windowManager.maximize();
        }
      },
    );
  }
}

mixin DesktopWindowMixin<T extends StatefulWidget> on State<T> implements WindowListener, TrayListener {
  @override
  void onWindowClose() {
    // 临时仅在 macOS 上处理系统标题栏关闭按钮事件，避免其他桌面端窗口管理行为差异。
    if (!Platform.isMacOS) return;

    // 桌面端默认拦截关闭事件（preventClose=true），这里统一走退出/最小化逻辑，
    // 避免 macOS 点击关闭按钮无响应。
    unawaited(
      DesktopManager.handleWindowClose().catchError((e, _) {
        debugPrint('处理关闭窗口失败: $e');
      }),
    );
  }

  @override
  void onTrayIconMouseDown() => DesktopManager.handleTrayIconClick();

  @override
  void onTrayIconRightMouseDown() => DesktopManager.handleTrayRightClick();

  @override
  void onTrayIconRightMouseUp() {
    windowManager.focus().then((_) {
      trayManager.popUpContextMenu();
    });
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) => DesktopManager.handleTrayMenuClick(menuItem);

  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMaximize() {}
  @override
  void onWindowUnmaximize() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}
  @override
  void onWindowResized() {}

  @override
  void onWindowMove() {}
  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() {}
  @override
  void onWindowLeaveFullScreen() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}
  @override
  void onWindowEvent(String eventName) {}
  @override
  void onTrayIconMouseUp() {}
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
