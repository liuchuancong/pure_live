import 'dart:developer';
import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 解析 WinINET 的 `ProxyServer` 值。
///
/// 它有两种写法：两个协议共用的 `host:port`，或分协议的 `http=host:port;https=host:port`。
/// 只有 http/https 用得上（ftp/socks 播放器和 dio 都不认），一边缺了就借另一边。
/// `scheme://` 前缀和 `[IPv6]:port` 的方括号都要容错——这串东西用户是从系统设置里抄来的。
(String, int)? parseWindowsProxyServer(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  if (!value.contains('=')) return _parseHostPort(value);

  (String, int)? http;
  (String, int)? https;
  for (final entry in value.split(';')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) continue;
    final scheme = entry.substring(0, separator).trim().toLowerCase();
    final endpoint = _parseHostPort(entry.substring(separator + 1));
    if (endpoint == null) continue;
    if (scheme == 'http') http = endpoint;
    if (scheme == 'https') https = endpoint;
  }
  // 播放器和 dio 都只认一个端点：直播源几乎都是 https，一边缺了就借另一边。
  return https ?? http;
}

(String, int)? _parseHostPort(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;

  final scheme = text.indexOf('://');
  if (scheme > 0) text = text.substring(scheme + 3);
  // 路径/查询不属于代理端点，带着会让端口解析失败。
  final pathStart = text.indexOf(RegExp(r'[/?#]'));
  if (pathStart >= 0) text = text.substring(0, pathStart);

  // IPv6 字面量自己也含冒号，端口在最后一个冒号之后。
  final colon = text.lastIndexOf(':');
  if (colon <= 0 || colon == text.length - 1) return null;

  var host = text.substring(0, colon);
  final port = int.tryParse(text.substring(colon + 1));
  if (port == null || port < 1 || port > 65535) return null;

  if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
  if (host.isEmpty) return null;
  return (host, port);
}

/// Windows 系统代理（WinINET）的只读视图。
///
/// 需要时才读注册表，不缓存也不起监视：读取点只有引擎装配与建立中继两处，都不是
/// 热路径，缓存换来的只是一份会过期的状态。Clash 这类工具打开的是系统代理，用户
/// 不会想到还要在应用里再配一遍——上游能列出房间却播不动，症状和"平台挂了"一模一样。
class WindowsSystemProxy {
  const WindowsSystemProxy._();

  static const String _subKey = r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// 当前生效的系统代理指令（`PROXY host:port`），没有则 `DIRECT`。
  ///
  /// 只配了 PAC 脚本（`AutoConfigURL`）时也是 `DIRECT`：PAC 是一段按 URL 求值的
  /// 脚本，压不成播放器的一个端点。
  static String directive() {
    final endpoint = currentEndpoint();
    return endpoint == null ? 'DIRECT' : 'PROXY ${endpoint.$1}:${endpoint.$2}';
  }

  /// 系统代理端点；未启用、读不到或非 Windows 时为 null。
  static (String, int)? currentEndpoint() {
    if (!Platform.isWindows) return null;
    try {
      final key = CURRENT_USER.open(_subKey);
      try {
        // ProxyEnable=0 时残留的 ProxyServer 不算数，与系统自己的判定一致。
        final enabled = switch (key.getValue('ProxyEnable')) {
          DwordValue(:final value) => value != 0,
          _ => false,
        };
        if (!enabled) return null;
        final server = switch (key.getValue('ProxyServer')) {
          StringValue(:final value) => value,
          UnexpandedStringValue(:final value) => value,
          _ => '',
        };
        return parseWindowsProxyServer(server);
      } finally {
        key.close();
      }
    } catch (error) {
      log('Failed to read the Windows system proxy: $error', name: 'SystemProxy');
      return null;
    }
  }
}
