import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WinFullscreen {
  static int? _hwnd;
  static Timer? _escListener;

  /// 缓存窗口状态
  static int _originalX = 0;
  static int _originalY = 0;
  static int _originalWidth = 800;
  static int _originalHeight = 600;
  static bool _originalMaximized = false;
  static bool _originalSaved = false;

  // Win32 常量定义
  static const dwmwaWindowCornerPreference = 33;
  static const dwmwcpDoNotRound = 1;
  static const dwmwaUseImmersiveDarkMode = 20;
  static const dwmwaNcRenderingPolicy = 2;
  static const dwmncrpDisabled = 1;

  /// 检测 Windows 11
  static bool get isWindows11 {
    if (!Platform.isWindows) return false;
    final versionInfo = calloc<OSVERSIONINFOEX>()..ref.dwOSVersionInfoSize = sizeOf<OSVERSIONINFOEX>();
    try {
      if (GetVersionEx(versionInfo.cast()) != 0) {
        return versionInfo.ref.dwMajorVersion == 10 && versionInfo.ref.dwBuildNumber >= 22000;
      }
    } finally {
      calloc.free(versionInfo);
    }
    return false;
  }

  static void startEscListener(Function onEsc) {
    _escListener?.cancel();
    _escListener = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      int state = GetAsyncKeyState(0x1B); // VK_ESCAPE
      if ((state & 0x8000) != 0) {
        timer.cancel();
        onEsc();
      }
    });
  }

  static void stopEscListener() => _escListener?.cancel();

  static int _getHwnd() {
    _hwnd ??= GetForegroundWindow();
    return _hwnd!;
  }

  /// 核心修复：强制抹除窗口帧边距（去除灰边的关键）
  static void _removeFrameMargins(int hWnd) {
    final margins = calloc<MARGINS>()
      ..ref.cxLeftWidth = 0
      ..ref.cxRightWidth = 0
      ..ref.cyTopHeight = 0
      ..ref.cyBottomHeight = 0;
    try {
      DwmExtendFrameIntoClientArea(hWnd, margins);
    } finally {
      calloc.free(margins);
    }
  }

  /// 适配 UI 修复：处理圆角、暗色模式和投影
  static void _applyVersionSpecificFix(int hWnd, {bool isFullscreen = true}) {
    final pvAttribute = calloc<Int32>();
    try {
      // 1. 处理 Win11 圆角
      if (isWindows11) {
        pvAttribute.value = isFullscreen ? DWMWCP_DONOTROUND : 0;
        DwmSetWindowAttribute(hWnd, DWMWA_WINDOW_CORNER_PREFERENCE, pvAttribute, sizeOf<Int32>());
      }

      // 2. 禁用非客户区渲染（彻底关掉外围投影/阴影造成的灰边）
      pvAttribute.value = isFullscreen ? dwmwcpDoNotRound : 0;
      DwmSetWindowAttribute(hWnd, DWMWA_NCRENDERING_POLICY, pvAttribute, sizeOf<Int32>());

      // 3. 启用沉浸式深色模式（防止标题栏区域泛白）
      pvAttribute.value = 1;
      DwmSetWindowAttribute(hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, pvAttribute, sizeOf<Int32>());
    } finally {
      calloc.free(pvAttribute);
    }
  }

  static void saveOriginalWindowRect() {
    if (!Platform.isWindows || _originalSaved) return;
    final hWnd = _getHwnd();
    _originalMaximized = IsZoomed(hWnd) != 0;
    final rect = calloc<RECT>();
    if (GetWindowRect(hWnd, rect) != 0) {
      _originalX = rect.ref.left;
      _originalY = rect.ref.top;
      _originalWidth = rect.ref.right - rect.ref.left;
      _originalHeight = rect.ref.bottom - rect.ref.top;
      _originalSaved = true;
    }
    calloc.free(rect);
  }

  static void enterFullscreen() {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();
    saveOriginalWindowRect();

    // 修改样式：额外移除了 WS_BORDER 和 WS_DLGFRAME 以消除灰边
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU | WS_BORDER | WS_DLGFRAME);
    style |= WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle &= ~(WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE | WS_EX_DLGMODALFRAME);
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    _applyVersionSpecificFix(hWnd, isFullscreen: true);
    _removeFrameMargins(hWnd);

    final monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);
    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();
    GetMonitorInfo(monitor, info);

    SetWindowPos(
      hWnd,
      HWND_TOP,
      info.ref.rcMonitor.left,
      info.ref.rcMonitor.top,
      info.ref.rcMonitor.right - info.ref.rcMonitor.left,
      info.ref.rcMonitor.bottom - info.ref.rcMonitor.top,
      SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOSENDCHANGING,
    );

    SetForegroundWindow(hWnd);
    calloc.free(info);
  }

  static void enterPipMode({required double width, required double height, required double x, required double y}) {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();
    saveOriginalWindowRect();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU | WS_BORDER);
    style |= WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle |= WS_EX_TOPMOST;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    _applyVersionSpecificFix(hWnd, isFullscreen: false);
    _removeFrameMargins(hWnd);

    SetWindowPos(
      hWnd,
      HWND_TOPMOST,
      x.toInt(),
      y.toInt(),
      width.toInt(),
      height.toInt(),
      SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOSENDCHANGING,
    );
  }

  static void exitSpecialMode() {
    if (!Platform.isWindows || !_originalSaved) return;
    final hWnd = _getHwnd();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style |= (WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    style &= ~WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle &= ~WS_EX_TOPMOST;
    exStyle |= WS_EX_WINDOWEDGE;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 恢复 Win11 默认渲染策略
    if (isWindows11) {
      final pvAttribute = calloc<Int32>()..value = 0;
      DwmSetWindowAttribute(hWnd, DWMWA_WINDOW_CORNER_PREFERENCE, pvAttribute, sizeOf<Int32>());
      pvAttribute.value = 0; // DWMNCRP_USEWINDOWSTYLE
      DwmSetWindowAttribute(hWnd, DWMWA_NCRENDERING_POLICY, pvAttribute, sizeOf<Int32>());
      calloc.free(pvAttribute);
    }

    if (_originalMaximized) {
      ShowWindow(hWnd, SW_MAXIMIZE);
    } else {
      SetWindowPos(
        hWnd,
        HWND_NOTOPMOST,
        _originalX,
        _originalY,
        _originalWidth,
        _originalHeight,
        SWP_SHOWWINDOW | SWP_FRAMECHANGED,
      );
    }
    _originalSaved = false;
  }
}
