import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/plugins/share_command_handler.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/common/widgets/share_command_import_dialog.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/utils/window_helper.dart';

class DesktopManager {
  static State? _currentState;
  static Future<void> initialize() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      await Window.initialize();

      final storedSize = SettingsService.to.window.storedSize;

      final WindowOptions windowOptions = WindowOptions(
        size: storedSize,
        minimumSize: const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight),
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
      // The desktop window is created before EasyLocalization has loaded its
      // delegate. Use a stable tooltip here and build the localized context
      // menu after the first application frame.
      await trayManager.setToolTip('PureLive');
    } catch (e) {
      debugPrint('系统托盘初始化失败: $e');
    }
  }

  static Future<void> updateTray() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      final useChineseFallback = PlatformDispatcher.instance.locale.languageCode == 'zh';
      await trayManager.setToolTip(i18nOr('app_name', useChineseFallback ? '纯粹直播' : 'PureLive'));

      final isVisible = await windowManager.isVisible();

      final menu = Menu(
        items: [
          MenuItem(
            key: isVisible ? 'hide_window' : 'show_window',
            label: isVisible
                ? i18nOr('hide_window', useChineseFallback ? '隐藏窗口' : 'Hide Window')
                : i18nOr('show_window', useChineseFallback ? '显示窗口' : 'Show Window'),
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: i18nOr('exit_app', useChineseFallback ? '退出应用' : 'Exit')),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('${i18n("tray_update_failed")}: $e');
    }
  }

  static Future<void> updateTrayWhenLocalized() async {
    // The first frame can be scheduled while the asset delegate is still
    // decoding JSON. Wait briefly so the first visible tray menu already uses
    // the selected application language.
    for (var attempt = 0; attempt < 40 && !i18nExists('app_name'); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await updateTray();
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
          await Utils.exitDesktopApplication();
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
      final currentSize = SettingsService.to.window.windowSize.value;
      final showSizeText = SettingsService.to.window.isTracking.value;

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
                              final url = Uri.parse(VersionUtil.projectUrl);
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
                                  i18nOr('app_name', 'PureLive'),
                                  style: AppTextStyles.t13.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: iconColor,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (showSizeText && !isFullscreen)
                                  IgnorePointer(
                                    child: Text(
                                      '[${currentSize.width.toInt()} × ${currentSize.height.toInt()}]',
                                      style: AppTextStyles.t12.copyWith(color: iconColor.withValues(alpha: 0.6)),
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
                  semanticLabel: i18nOr('window_minimize', 'Minimize window'),
                  failureMessage: i18nOr('window_close_action_failed', 'The window action failed. Try again.'),
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
                  semanticLabel: i18nOr('window_maximize_restore', 'Maximize or restore window'),
                  failureMessage: i18nOr('window_close_action_failed', 'The window action failed. Try again.'),
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
                  semanticLabel: i18nOr('window_close', 'Close window'),
                  failureMessage: i18nOr('window_close_action_failed', 'The window action failed. Try again.'),
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
  final Future<void> Function() onPressed;
  final String semanticLabel;
  final String failureMessage;
  final IconData icon;

  final Color hoverColor;
  final Color iconColor;

  final Color? hoverIconColor;

  final bool isClose;

  const WindowControlButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    required this.failureMessage,
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
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  bool _busy = false;

  Future<void> _runAction() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (error, stackTrace) {
      debugPrint('Desktop window control failed (${widget.semanticLabel}): $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(widget.failureMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed || _focused;
    final activeIconColor = widget.hoverIconColor ?? widget.iconColor;
    return Semantics(
      button: true,
      enabled: !_busy,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: _busy ? null : () => unawaited(_runAction()),
            onHover: (value) => setState(() => _hovered = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onFocusChange: (value) => setState(() => _focused = value),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: AnimatedContainer(
              width: 46,
              height: 32,
              duration: const Duration(milliseconds: 80),
              decoration: BoxDecoration(
                color: active ? widget.hoverColor : Colors.transparent,
                border: _focused ? Border.all(color: activeIconColor.withValues(alpha: 0.8)) : null,
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 16, color: active ? activeIconColor : widget.iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

mixin DesktopWindowMixin<T extends StatefulWidget> on State<T>
    implements WindowListener, TrayListener, WidgetsBindingObserver {
  final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'Pure Live navigator');
  bool _isDialogOpen = false;
  Timer? _windowGeometryTimer;
  Timer? _shareCommandResumeTimer;
  final _sizeController = SettingsService.to.window;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkShareCommand();
    });
  }

  @override
  void dispose() {
    _windowGeometryTimer?.cancel();
    _shareCommandResumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _shareCommandResumeTimer?.cancel();
      _shareCommandResumeTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _checkShareCommand();
      });
    }
  }

  void _checkShareCommand() {
    if (!mounted) return;

    unawaited(ShareCommandHandler.instance.checkClipboard(_presentShareCommand));
  }

  Future<bool> handleIncomingShareCommand(String fullText) {
    return ShareCommandHandler.instance.acceptCommandText(fullText, _presentShareCommand);
  }

  Future<void> _presentShareCommand(String fullText) async {
    final navigatorContext = await _waitForShareCommandNavigator();
    if (!mounted || !navigatorContext.mounted) {
      throw StateError('Share command route owner is no longer mounted.');
    }
    if (_isDialogOpen) throw StateError('A share command dialog is already active.');

    final roomMap = ShareCommandCodec.decodeShort(fullText);
    if (roomMap == null) throw const FormatException('Share command payload disappeared after validation.');

    final room = LiveRoom.fromJson(roomMap).normalizedIdentityCopy();
    _isDialogOpen = true;
    try {
      final enterRoom = await ShareCommandImportDialog.show(context: navigatorContext, room: room);
      if (enterRoom == true && mounted) {
        AppNavigator.toLiveRoomDetail(liveRoom: room);
      }
    } finally {
      _isDialogOpen = false;
    }
  }

  Future<BuildContext> _waitForShareCommandNavigator() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final navigatorContext = appNavigatorKey.currentContext;
      final currentRoute = Get.isRegistered<RouteObserverController>()
          ? RouteObserverController.to.currentRoute.value
          : '';
      if (navigatorContext != null && currentRoute.isNotEmpty && currentRoute != RoutePath.kSplash) {
        return navigatorContext;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError('Share command navigator did not become ready.');
  }

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
  void onWindowResize() {
    _sizeController.setTracking(true);
    _scheduleWindowSizeUpdate();
  }

  @override
  void onWindowResized() {
    _windowGeometryTimer?.cancel();
    _updateWindowSizeToController();
    _sizeController.setTracking(false);
  }

  @override
  void onWindowMove() {
    _sizeController.setTracking(true);
  }

  @override
  void onWindowMoved() {
    _scheduleWindowSizeUpdate();
    _sizeController.setTracking(false);
  }

  @override
  void onWindowEnterFullScreen() {
    _sizeController.setTracking(false);
  }

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

  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  Future<bool> didPopRoute() async => false;

  @override
  Future<bool> didPushRoute(String route) async => false;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async => false;

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await HivePrefUtil.flush();
    return AppExitResponse.exit;
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {}

  @override
  void didHaveMemoryPressure() {
    // Android/iOS emit this callback before the process reaches a hard memory
    // limit. Windows may also deliver it through the engine. Decoded images
    // are reproducible resources, so release both pending and live entries;
    // visible widgets resolve them again on demand.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  @override
  void handleCancelBackGesture() {}

  @override
  void handleCommitBackGesture() {}

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => false;

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {}

  @override
  void handleStatusBarTap() {}

  void _updateWindowSizeToController() {
    unawaited(
      _captureWindowGeometry().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Desktop window geometry capture failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _captureWindowGeometry() async {
    if (Platform.isWindows) {
      await WindowHelper.instance.captureWindowGeometry(_sizeController.updateSize);
      return;
    }
    _sizeController.updateSize(await windowManager.getSize());
  }

  void _scheduleWindowSizeUpdate() {
    _windowGeometryTimer?.cancel();
    _windowGeometryTimer = Timer(const Duration(milliseconds: 80), _updateWindowSizeToController);
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const PureLiveScrollPhysics();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(BuildContext context) =>
      ScrollViewKeyboardDismissBehavior.onDrag;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,

    // Do not include mouse here.
    // Enabling mouse drag makes left-button dragging participate in the
    // Scrollable's drag gesture system. This conflicts with
    // PureLiveScrollPhysics at the scroll boundaries and prevents the
    // expected overscroll/bounce-back behavior on desktop.
    //
    // Mouse wheel scrolling is not affected by this setting because
    // wheel events are handled separately from dragDevices.
    //
    // PointerDeviceKind.mouse,
  };
}
