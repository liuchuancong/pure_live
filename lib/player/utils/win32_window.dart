import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WinFullscreen {
  static int? _hwnd;

  static Timer? _escListener;

  /// 缓存进入全屏前的窗口状态
  static int _originalX = 0;
  static int _originalY = 0;
  static int _originalWidth = 800;
  static int _originalHeight = 600;

  static bool _originalMaximized = false;
  static bool _originalSaved = false;

  static void startEscListener(Function onEsc) {
    _escListener?.cancel();

    _escListener = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final state = GetAsyncKeyState(VK_ESCAPE);

      if ((state & 0x8000) != 0) {
        timer.cancel();
        onEsc();
      }
    });
  }

  static void stopEscListener() {
    _escListener?.cancel();
  }

  static int _getHwnd() {
    _hwnd ??= GetForegroundWindow();
    return _hwnd!;
  }

  /// 保存进入全屏前的窗口状态
  static void saveOriginalWindowRect() {
    if (!Platform.isWindows || _originalSaved) {
      return;
    }

    final hWnd = _getHwnd();

    /// 是否最大化
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

  /// 真正无边框全屏（修复 Win11 白边/毛刺）
  static void enterFullscreen() {
    if (!Platform.isWindows) {
      return;
    }

    final hWnd = _getHwnd();

    saveOriginalWindowRect();

    /// 去除窗口边框
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);

    style &= ~WS_CAPTION;
    style &= ~WS_THICKFRAME;
    style &= ~WS_SYSMENU;
    style &= ~WS_MINIMIZEBOX;
    style &= ~WS_MAXIMIZEBOX;

    style |= WS_POPUP;

    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    /// 去除扩展边框
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    exStyle &= ~WS_EX_WINDOWEDGE;
    exStyle &= ~WS_EX_DLGMODALFRAME;
    exStyle &= ~WS_EX_CLIENTEDGE;
    exStyle &= ~WS_EX_STATICEDGE;

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    final monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);

    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();

    GetMonitorInfo(monitor, info);

    /// 修复 Win11 fullscreen 白边毛刺
    ///
    /// fullscreen 实际缩进去 1px
    /// 避免 DWM / SwapChain 边缘抗锯齿问题

    SetWindowPos(
      hWnd,
      HWND_TOP,
      info.ref.rcMonitor.left,
      info.ref.rcMonitor.top,
      info.ref.rcMonitor.right - info.ref.rcMonitor.left,
      info.ref.rcMonitor.bottom - info.ref.rcMonitor.top,
      SWP_SHOWWINDOW | SWP_FRAMECHANGED,
    );

    ShowWindow(hWnd, SW_SHOW);

    SetForegroundWindow(hWnd);

    SetFocus(hWnd);

    calloc.free(info);
  }

  /// 退出全屏
  static void exitFullscreen() {
    if (!Platform.isWindows) {
      return;
    }

    final hWnd = _getHwnd();

    /// 恢复窗口样式
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);

    style |= WS_CAPTION;
    style |= WS_THICKFRAME;
    style |= WS_SYSMENU;
    style |= WS_MINIMIZEBOX;
    style |= WS_MAXIMIZEBOX;

    style &= ~WS_POPUP;

    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    /// 恢复扩展样式
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    exStyle |= WS_EX_WINDOWEDGE;

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    if (_originalMaximized) {
      ShowWindow(hWnd, SW_MAXIMIZE);
    } else {
      SetWindowPos(
        hWnd,
        HWND_TOP,
        _originalX,
        _originalY,
        _originalWidth,
        _originalHeight,
        SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOZORDER,
      );
    }

    _originalSaved = false;
  }

  /// 进入 PiP 模式
  static void enterPipMode({required double width, required double height, required double x, required double y}) {
    if (!Platform.isWindows) {
      return;
    }

    final hWnd = _getHwnd();

    saveOriginalWindowRect();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE);

    style &= ~WS_CAPTION;
    style &= ~WS_THICKFRAME;
    style &= ~WS_SYSMENU;
    style &= ~WS_MAXIMIZEBOX;
    style &= ~WS_MINIMIZEBOX;

    style |= WS_POPUP;

    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    exStyle |= WS_EX_TOPMOST;

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    SetWindowPos(
      hWnd,
      HWND_TOPMOST,
      x.toInt(),
      y.toInt(),
      width.toInt(),
      height.toInt(),
      SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOACTIVATE,
    );
  }

  /// 退出 PiP / 特殊模式
  static void exitSpecialMode() {
    if (!Platform.isWindows) {
      return;
    }

    final hWnd = _getHwnd();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE);

    style |= WS_CAPTION;
    style |= WS_THICKFRAME;
    style |= WS_SYSMENU;
    style |= WS_MINIMIZEBOX;
    style |= WS_MAXIMIZEBOX;

    style &= ~WS_POPUP;

    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);

    exStyle &= ~WS_EX_TOPMOST;

    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

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
