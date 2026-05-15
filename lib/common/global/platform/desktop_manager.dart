import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/routes/route_path.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/routes/route_observer_controller.dart';

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
        await windowManager.setPreventClose(true);

        await windowManager.setBackgroundColor(Colors.transparent);

        if (Platform.isWindows) {
          await windowManager.setResizable(true);
        }

        await windowManager.show();
        await windowManager.focus();

        if (Platform.isWindows) {
          await Window.setEffect(
            effect: WindowEffect.mica,
            dark: PlatformDispatcher.instance.platformBrightness == Brightness.dark,
          );
        }

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
      final fullscreen = GlobalPlayerState.to.isFullscreen.value;
      final pipMode = GlobalPlayerState.to.isPipMode.value;

      if (!PlatformUtils.isWindows) {
        return child ?? const SizedBox.shrink();
      }

      return Column(
        children: [
          if (!fullscreen && !pipMode) const CustomTitleBar(),
          if (child != null) Expanded(child: child),
        ],
      );
    });
  }

  static Future<void> _initTray() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      if (Platform.isWindows) {
        await trayManager.setIcon('assets/icons/app_icon.ico');
      } else if (Platform.isMacOS) {
        await trayManager.setIcon('assets/icons/app_icon.ico');
      }

      await updateTray();
    } catch (e) {
      debugPrint('系统托盘初始化失败: $e');
    }
  }

  static Future<void> updateTray() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await trayManager.setToolTip(i18n('app_name'));

      final isVisible = await windowManager.isVisible();

      final menu = Menu(
        items: [
          MenuItem(
            key: isVisible ? 'hide_window' : 'show_window',
            label: isVisible ? i18n('hide_window') : i18n('show_window'),
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: i18n('exit_app')),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('${i18n("tray_update_failed")}: $e');
    }
  }

  static Future<void> handleTrayMenuClick(MenuItem menuItem) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      switch (menuItem.key) {
        case 'show_window':
          await showWindow();
          break;

        case 'hide_window':
          await hideWindow();
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
      final isVisible = await windowManager.isVisible();

      if (isVisible) {
        await windowManager.focus();
      } else {
        await windowManager.show();
        await windowManager.focus();
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
      await windowManager.focus();
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
    final LinearGradient bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF141E27)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE8FAFC), Color(0xFFC8F1F5), Color(0xFF9BE7F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Obx(() {
      final isFullscreen = GlobalPlayerState.to.isWindowFullscreen.value;
      final bgColor = isFullscreen || isDark ? Colors.black : theme.scaffoldBackgroundColor;
      final iconColor = isFullscreen || isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black;
      final currentRoute = RouteObserverController.to.currentRoute.value;
      final currentRouteIskSplash = currentRoute == RoutePath.kSplash;

      return Container(
        height: 32,
        decoration: BoxDecoration(
          gradient: currentRouteIskSplash ? bgGradient : null,
          color: currentRouteIskSplash ? null : bgColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 12),
                  child: isFullscreen
                      ? null
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final url = Uri.parse('https://github.com/liuchuancong/pure_live');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/icons/icon.png', width: 16, height: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '纯粹直播',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: iconColor,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            /// Window Buttons
            Row(
              children: [
                WindowControlButton(
                  icon: Icons.remove,
                  iconColor: iconColor,
                  hoverColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                  onPressed: () async {
                    await windowManager.minimize();
                  },
                ),
                WindowControlButton(
                  icon: Icons.crop_square,
                  iconColor: iconColor,
                  hoverColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.restore();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                WindowControlButton(
                  icon: Icons.close,
                  iconColor: iconColor,
                  hoverIconColor: Colors.white,
                  hoverColor: const Color(0xFFE81123),
                  isClose: true,
                  onPressed: () async {
                    await DesktopManager.handleWindowClose();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class WindowControlButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;

  final Color hoverColor;
  final Color iconColor;

  final Color? hoverIconColor;

  final bool isClose;

  const WindowControlButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.hoverColor,
    required this.iconColor,
    this.hoverIconColor,
    this.isClose = false,
  });

  @override
  State<WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<WindowControlButton> {
  bool hover = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hover = true;
        });
      },
      onExit: (_) {
        setState(() {
          hover = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            pressed = true;
          });
        },

        onTapUp: (_) {
          setState(() {
            pressed = false;
          });
        },

        onTapCancel: () {
          setState(() {
            pressed = false;
          });
        },
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: hover ? widget.hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: (hover || pressed) ? (widget.hoverIconColor ?? widget.iconColor) : widget.iconColor,
          ),
        ),
      ),
    );
  }
}

mixin DesktopWindowMixin<T extends StatefulWidget> on State<T> implements WindowListener, TrayListener {
  @override
  void onWindowClose() {
    unawaited(
      DesktopManager.handleWindowClose().catchError((e, _) {
        debugPrint('处理窗口关闭失败: $e');
      }),
    );
  }

  @override
  void onTrayIconMouseDown() {
    DesktopManager.handleTrayIconClick();
  }

  @override
  void onTrayIconRightMouseDown() {
    DesktopManager.handleTrayRightClick();
  }

  @override
  void onTrayIconRightMouseUp() {
    windowManager.focus().then((_) {
      trayManager.popUpContextMenu();
    });
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    DesktopManager.handleTrayMenuClick(menuItem);
  }

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
