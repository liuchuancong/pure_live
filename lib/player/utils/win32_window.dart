import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WinFullscreen {
  static Timer? _escListener;

  /// 缓存进入全屏前的窗口状态
  static int _originalX = 0;
  static int _originalY = 0;
  static int _originalWidth = 800;
  static int _originalHeight = 600;
  static bool _originalMaximized = false;
  static bool _originalSaved = false;

  // 修复：将类型更改为 HWND? 而不是 int?
  static HWND? _hwnd;

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

  static void stopEscListener() {
    _escListener?.cancel();
  }

  // 修复：返回类型更改为 HWND
  static HWND _getHwnd() {
    _hwnd ??= GetForegroundWindow();
    return _hwnd!;
  }

  /// 保存进入全屏前的窗口状态
  static void saveOriginalWindowRect() {
    if (!Platform.isWindows || _originalSaved) return;

    final hWnd = _getHwnd();

    _originalMaximized = IsZoomed(hWnd);

    final rect = calloc<RECT>();
    if (GetWindowRect(hWnd, rect).value) {
      _originalX = rect.ref.left;
      _originalY = rect.ref.top;
      _originalWidth = rect.ref.right - rect.ref.left;
      _originalHeight = rect.ref.bottom - rect.ref.top;
      _originalSaved = true;
    }
    calloc.free(rect);
  }

  /// 进入全屏
  static void enterFullscreen() {
    if (!Platform.isWindows) return;

    final hWnd = _getHwnd();
    saveOriginalWindowRect();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE).value;
    style &= ~WS_CAPTION & ~WS_THICKFRAME & ~WS_SYSMENU & ~WS_MINIMIZEBOX & ~WS_MAXIMIZEBOX;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE).value;
    exStyle &= ~WS_EX_WINDOWEDGE;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    final monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);
    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();

    if (GetMonitorInfo(monitor, info)) {
      SetWindowPos(
        hWnd,
        HWND_TOP,
        info.ref.rcMonitor.left,
        info.ref.rcMonitor.top,
        info.ref.rcMonitor.right - info.ref.rcMonitor.left,
        info.ref.rcMonitor.bottom - info.ref.rcMonitor.top,
        SWP_SHOWWINDOW | SWP_FRAMECHANGED,
      );
    }

    SetForegroundWindow(hWnd);
    SetFocus(hWnd);
    calloc.free(info);
  }

  /// 退出全屏
  static void exitFullscreen() {
    exitSpecialMode(); // 统一使用逻辑更全的退出方法
  }

  static void enterPipMode({required double width, required double height, required double x, required double y}) {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();

    saveOriginalWindowRect();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE).value;
    style &= ~WS_CAPTION & ~WS_THICKFRAME & ~WS_SYSMENU & ~WS_MAXIMIZEBOX & ~WS_MINIMIZEBOX;
    style |= WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE).value;
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

  /// 退出画中画/全屏
  static void exitSpecialMode() {
    if (!Platform.isWindows || !_originalSaved) return;
    final hWnd = _getHwnd();

    SetWindowLongPtr(hWnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE).value;
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
    stopEscListener();
  }
}
