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
      // 0x1B 是 VK_ESCAPE
      int state = GetAsyncKeyState(0x1B);
      // 如果最高位为1，表示按键正被按下
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
    if (!Platform.isWindows || _originalSaved) return;

    final hWnd = _getHwnd();

    // 检查是否最大化
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

  /// 进入全屏
  static void enterFullscreen() {
    if (!Platform.isWindows) return;

    final hWnd = _getHwnd();

    // 保存原始窗口
    saveOriginalWindowRect();

    // 去掉边框
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style &= ~WS_CAPTION & ~WS_THICKFRAME & ~WS_SYSMENU & ~WS_MINIMIZEBOX & ~WS_MAXIMIZEBOX;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle &= ~WS_EX_WINDOWEDGE;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 铺满显示器
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
      SWP_SHOWWINDOW | SWP_FRAMECHANGED,
    );
    SetForegroundWindow(hWnd); // Bring window to front
    SetFocus(hWnd); // Direct keyboard input to this window
    calloc.free(info);
  }

  /// 退出全屏，恢复原始窗口状态
  static void exitFullscreen() {
    if (!Platform.isWindows) return;

    final hWnd = _getHwnd();

    // 恢复窗口样式
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style |= WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle |= WS_EX_WINDOWEDGE;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    if (_originalMaximized) {
      // 如果原本是最大化，恢复最大化
      ShowWindow(hWnd, SW_MAXIMIZE);
    } else {
      // 否则恢复原始位置和大小
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

    // 退出后重置缓存，下次全屏再保存
    _originalSaved = false;
  }

  static void enterPipMode({required double width, required double height, required double x, required double y}) {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();

    // 1. 保存当前状态以便退出恢复
    saveOriginalWindowRect();

    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style &= ~WS_CAPTION & ~WS_THICKFRAME & ~WS_SYSMENU & ~WS_MAXIMIZEBOX & ~WS_MINIMIZEBOX;
    style |= WS_POPUP; // 设置为无边框弹出式窗口
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    // 3. 修改扩展样式：确保没有窗口边缘阴影（可选）
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle |= WS_EX_TOPMOST; // 扩展样式置顶
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 4. 设置窗口位置和大小，并强制置顶 (HWND_TOPMOST)
    SetWindowPos(
      hWnd,
      HWND_TOPMOST, // 置顶关键
      x.toInt(),
      y.toInt(),
      width.toInt(),
      height.toInt(),
      SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOACTIVATE, // NOACTIVATE 防止抢焦点
    );
  }

  /// 退出画中画/全屏
  static void exitSpecialMode() {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();

    // 1. 恢复标准窗口样式
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style |= WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
    style &= ~WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    // 2. 取消置顶样式
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle &= ~WS_EX_TOPMOST;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 3. 恢复原始位置并取消置顶 (HWND_NOTOPMOST)
    if (_originalMaximized) {
      ShowWindow(hWnd, SW_MAXIMIZE);
    } else {
      SetWindowPos(
        hWnd,
        HWND_NOTOPMOST, // 取消置顶
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
