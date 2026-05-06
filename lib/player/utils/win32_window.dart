import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WinFullscreen {
  static int? _hwnd;
  static Timer? _escListener;

  // 缓存状态
  static int _originalX = 0;
  static int _originalY = 0;
  static int _originalWidth = 800;
  static int _originalHeight = 600;
  static bool _originalMaximized = false;
  static bool _originalSaved = false;

  /// 获取当前窗口句柄（优化：如果已获取则复用，避免切换应用时抓错）
  static int _getHwnd() {
    if (_hwnd == null || _hwnd == 0) {
      _hwnd = GetForegroundWindow();
    }
    return _hwnd!;
  }

  /// 开启 ESC 监听
  static void startEscListener(Function onEsc) {
    _escListener?.cancel();
    _escListener = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if ((GetAsyncKeyState(VK_ESCAPE) & 0x8000) != 0) {
        timer.cancel();
        onEsc();
      }
    });
  }

  static void stopEscListener() => _escListener?.cancel();

  /// 保存原始状态
  static void _saveState() {
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

  /// 进入全屏 (优化：彻底清理边框和边缘)
  static void enterFullscreen() {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();
    _saveState();

    // 1. 先强制移除所有可能导致边框的样式
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    // 清除所有装饰，只保留 POPUP
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU | WS_DLGFRAME | WS_BORDER);
    style |= WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    // 2. 【核心优化】清除扩展样式中的所有边框相关位
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    // 必须清除这几个：DLGMODALFRAME, CLIENTEDGE, STATICEDGE, WINDOWEDGE
    exStyle &= ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE | WS_EX_WINDOWEDGE);
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 3. 获取屏幕信息
    final monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);
    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();

    if (GetMonitorInfo(monitor, info) != 0) {
      final rc = info.ref.rcMonitor;
      const offset = 8; // 增加偏移量

      // 4. 强制刷新窗口布局
      SetWindowPos(
        hWnd,
        HWND_TOP,
        rc.left - offset, // 向左偏移
        rc.top - offset, // 向上偏移
        (rc.right - rc.left) + (offset * 2), // 宽度补偿
        (rc.bottom - rc.top) + (offset * 2), // 高度补偿
        SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOSENDCHANGING,
      );
    }
    calloc.free(info);
  }

  /// 进入画中画模式
  static void enterPipMode({required double width, required double height, required double x, required double y}) {
    if (!Platform.isWindows) return;
    final hWnd = _getHwnd();
    _saveState();

    // 去掉标题栏
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_SYSMENU);
    style |= WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    // 置顶
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

  /// 退出特殊模式 (全屏/Pip) 并恢复原始状态
  static void exitSpecialMode() {
    if (!Platform.isWindows || !_originalSaved) return;
    final hWnd = _getHwnd();

    // 1. 恢复常规样式
    int style = GetWindowLongPtr(hWnd, GWL_STYLE);
    style |= (WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
    style &= ~WS_POPUP;
    SetWindowLongPtr(hWnd, GWL_STYLE, style);

    // 2. 恢复扩展样式并取消置顶
    int exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
    exStyle |= WS_EX_WINDOWEDGE;
    exStyle &= ~WS_EX_TOPMOST;
    SetWindowLongPtr(hWnd, GWL_EXSTYLE, exStyle);

    // 3. 恢复位置
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
