import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';

class WinFullscreen {
  /// -----------------------------
  /// State
  /// -----------------------------

  static bool _isFullscreen = false;
  static bool _isPip = false;

  static bool get isFullscreen => _isFullscreen;

  static bool get isPip => _isPip;

  static int? _cachedHwnd;

  /// -----------------------------
  /// Original window state
  /// -----------------------------

  static bool _saved = false;

  static int _originalStyle = 0;
  static int _originalExStyle = 0;

  static int _originalX = 0;
  static int _originalY = 0;
  static int _originalWidth = 0;
  static int _originalHeight = 0;

  static bool _originalMaximized = false;

  /// -----------------------------
  /// DWM
  /// -----------------------------

  static const int dwmwaWindowCornerPreference = 33;
  static const int dwmwcpRound = 2;
  static const int dwmwcpDoNotRound = 1;

  static const int dwmwaUseImmersiveDarkMode = 20;

  /// ------------------------------------------------------------
  /// HWND
  /// ------------------------------------------------------------

  static int get hwnd {
    if (!Platform.isWindows) return 0;

    if (_cachedHwnd != null && _cachedHwnd != 0 && IsWindow(_cachedHwnd!) != 0) {
      return _cachedHwnd!;
    }

    final className = TEXT('FLUTTER_RUNNER_WIN32_WINDOW');

    try {
      final found = FindWindow(className, nullptr);

      calloc.free(className);

      if (found != 0 && IsWindow(found) != 0) {
        _cachedHwnd = found;
        return found;
      }
    } catch (_) {
      calloc.free(className);
    }

    final foreground = GetForegroundWindow();

    if (foreground != 0 && IsWindow(foreground) != 0) {
      _cachedHwnd = foreground;
      return foreground;
    }

    return 0;
  }

  /// ------------------------------------------------------------
  /// Windows Version
  /// ------------------------------------------------------------

  static bool get isWindows11 {
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

  /// ------------------------------------------------------------
  /// DPI
  /// ------------------------------------------------------------

  static double getWindowScale() {
    final hWnd = hwnd;

    if (hWnd == 0) return 1.0;

    try {
      final dpi = GetDpiForWindow(hWnd);

      if (dpi == 0) return 1.0;

      return dpi / 96.0;
    } catch (_) {
      return 1.0;
    }
  }

  static int logicalToPhysical(double logical) {
    return (logical * getWindowScale()).round();
  }

  /// ------------------------------------------------------------
  /// Save current window state
  /// ------------------------------------------------------------

  static void _saveWindowState() {
    if (_saved) return;

    final hWnd = hwnd;

    if (hWnd == 0) return;

    _originalStyle = GetWindowLongPtr(hWnd, GWL_STYLE);
    _originalExStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    _originalMaximized = IsZoomed(hWnd) != 0;

    final rect = calloc<RECT>();

    try {
      if (GetWindowRect(hWnd, rect) != 0) {
        _originalX = rect.ref.left;
        _originalY = rect.ref.top;

        _originalWidth = rect.ref.right - rect.ref.left;
        _originalHeight = rect.ref.bottom - rect.ref.top;

        _saved = true;
      }
    } finally {
      calloc.free(rect);
    }
  }

  /// ------------------------------------------------------------
  /// DWM Visual Fix
  /// ------------------------------------------------------------

  static void _applyDwmFix(int hWnd) {
    final value = calloc<Int32>();

    try {
      /// Win11 corner
      if (isWindows11) {
        value.value = dwmwcpDoNotRound;

        DwmSetWindowAttribute(hWnd, dwmwaWindowCornerPreference, value, sizeOf<Int32>());
      }

      /// Dark mode
      value.value = 1;

      DwmSetWindowAttribute(hWnd, dwmwaUseImmersiveDarkMode, value, sizeOf<Int32>());
    } finally {
      calloc.free(value);
    }
  }

  static void _restoreDwm(int hWnd) {
    if (!isWindows11) return;

    final value = calloc<Int32>();

    try {
      value.value = dwmwcpRound;

      DwmSetWindowAttribute(hWnd, dwmwaWindowCornerPreference, value, sizeOf<Int32>());
    } finally {
      calloc.free(value);
    }
  }

  /// ------------------------------------------------------------
  /// Remove window frame
  /// ------------------------------------------------------------

  static void _applyBorderless(int hWnd, {required bool topMost}) {
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);

    style &= ~WS_CAPTION;
    style &= ~WS_THICKFRAME;
    style &= ~WS_MINIMIZEBOX;
    style &= ~WS_MAXIMIZEBOX;
    style &= ~WS_SYSMENU;

    style |= WS_POPUP;

    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    if (topMost) {
      exStyle |= WS_EX_TOPMOST;
    } else {
      exStyle &= ~WS_EX_TOPMOST;
    }

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    final margins = calloc<MARGINS>();

    try {
      margins.ref.cxLeftWidth = 0;
      margins.ref.cxRightWidth = 0;
      margins.ref.cyTopHeight = 0;
      margins.ref.cyBottomHeight = 0;

      DwmExtendFrameIntoClientArea(hWnd, margins);
    } finally {
      calloc.free(margins);
    }

    _applyDwmFix(hWnd);
  }

  /// ------------------------------------------------------------
  /// ESC Exit
  /// ------------------------------------------------------------

  static void _initKeyboardHook() {
    HardwareKeyboard.instance.removeHandler(_keyboardHandler);
    HardwareKeyboard.instance.addHandler(_keyboardHandler);
  }

  static bool _keyboardHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreen) {
      exitSpecialMode();

      return true;
    }

    return false;
  }

  /// ------------------------------------------------------------
  /// Fullscreen
  /// ------------------------------------------------------------

  static void enterFullscreen() {
    if (!Platform.isWindows) return;

    final hWnd = hwnd;

    if (hWnd == 0) return;

    /// 已经全屏
    if (_isFullscreen) return;

    /// 保存窗口状态
    _saveWindowState();

    _isFullscreen = true;
    _isPip = false;

    /// ESC 退出
    _initKeyboardHook();

    /// 应用无边框
    _applyBorderless(hWnd, topMost: false);

    /// 获取当前显示器
    final monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);

    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();

    try {
      if (GetMonitorInfo(monitor, info) == 0) {
        return;
      }

      final monitorLeft = info.ref.rcMonitor.left;
      final monitorTop = info.ref.rcMonitor.top;

      final monitorWidth = info.ref.rcMonitor.right - info.ref.rcMonitor.left;

      final monitorHeight = info.ref.rcMonitor.bottom - info.ref.rcMonitor.top;

      SetWindowPos(
        hWnd,
        HWND_TOP,
        monitorLeft,
        monitorTop,
        monitorWidth,
        monitorHeight,
        SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER | SWP_NOZORDER,
      );

      ShowWindow(hWnd, SW_SHOW);

      UpdateWindow(hWnd);

      RedrawWindow(hWnd, nullptr, 0, RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN | RDW_FRAME);

      SetForegroundWindow(hWnd);

      final rect = calloc<RECT>();

      try {
        if (GetWindowRect(hWnd, rect) != 0) {
          final currentWidth = rect.ref.right - rect.ref.left;

          final currentHeight = rect.ref.bottom - rect.ref.top;
          if (currentWidth != monitorWidth || currentHeight != monitorHeight) {
            SetWindowPos(
              hWnd,
              HWND_TOP,
              monitorLeft,
              monitorTop,
              monitorWidth,
              monitorHeight,
              SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER | SWP_NOZORDER,
            );
          }
        }
      } finally {
        calloc.free(rect);
      }
    } finally {
      calloc.free(info);
    }
  }

  /// ------------------------------------------------------------
  /// Picture in Picture
  /// ------------------------------------------------------------

  static void enterPip({required double x, required double y, required double width, required double height}) {
    if (!Platform.isWindows) return;

    final hWnd = hwnd;

    if (hWnd == 0) return;

    _saveWindowState();

    _isFullscreen = false;
    _isPip = true;

    HardwareKeyboard.instance.removeHandler(_keyboardHandler);

    _applyBorderless(hWnd, topMost: true);

    final px = logicalToPhysical(x);
    final py = logicalToPhysical(y);

    final pw = logicalToPhysical(width);
    final ph = logicalToPhysical(height);

    SetWindowPos(
      hWnd,
      HWND_TOPMOST,
      px,
      py,
      pw,
      ph,
      SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOOWNERZORDER,
    );

    ShowWindow(hWnd, SW_SHOW);
  }

  /// ------------------------------------------------------------
  /// Exit fullscreen / pip
  /// ------------------------------------------------------------

  static void exitSpecialMode() {
    if (!Platform.isWindows) return;

    final hWnd = hwnd;

    if (hWnd == 0) return;

    _isFullscreen = false;
    _isPip = false;

    HardwareKeyboard.instance.removeHandler(_keyboardHandler);

    /// Restore styles
    SetWindowLongPtr(hWnd, GWL_STYLE, _originalStyle);

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, _originalExStyle);

    _restoreDwm(hWnd);

    /// Restore maximized
    if (_originalMaximized) {
      ShowWindow(hWnd, SW_RESTORE);

      SetWindowPos(
        hWnd,
        HWND_NOTOPMOST,
        _originalX,
        _originalY,
        _originalWidth,
        _originalHeight,
        SWP_FRAMECHANGED | SWP_NOOWNERZORDER,
      );

      ShowWindow(hWnd, SW_MAXIMIZE);
    } else {
      ShowWindow(hWnd, SW_RESTORE);

      SetWindowPos(
        hWnd,
        HWND_NOTOPMOST,
        _originalX,
        _originalY,
        _originalWidth,
        _originalHeight,
        SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER,
      );
    }

    _saved = false;
  }

  /// ------------------------------------------------------------
  /// Toggle Fullscreen
  /// ------------------------------------------------------------

  static void toggleFullscreen() {
    if (_isFullscreen) {
      exitSpecialMode();
    } else {
      enterFullscreen();
    }
  }

  /// ------------------------------------------------------------
  /// Toggle PiP
  /// ------------------------------------------------------------

  static void togglePip({double width = 420, double height = 240}) {
    if (_isPip) {
      exitSpecialMode();
      return;
    }

    final screenWidth = GetSystemMetrics(SM_CXSCREEN);
    final screenHeight = GetSystemMetrics(SM_CYSCREEN);

    enterPip(width: width, height: height, x: screenWidth - width - 24, y: screenHeight - height - 48);
  }
}
