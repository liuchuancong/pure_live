import 'dart:developer';
import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

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
  return https ?? http;
}

(String, int)? _parseHostPort(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;

  final scheme = text.indexOf('://');
  if (scheme > 0) text = text.substring(scheme + 3);
  final pathStart = text.indexOf(RegExp(r'[/?#]'));
  if (pathStart >= 0) text = text.substring(0, pathStart);

  final colon = text.lastIndexOf(':');
  if (colon <= 0 || colon == text.length - 1) return null;

  var host = text.substring(0, colon);
  final port = int.tryParse(text.substring(colon + 1));
  if (port == null || port < 1 || port > 65535) return null;

  if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
  if (host.isEmpty) return null;
  return (host, port);
}

class WindowsSystemProxy {
  const WindowsSystemProxy._();

  static const String _subKey = r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static String directive() {
    final endpoint = currentEndpoint();
    return endpoint == null ? 'DIRECT' : 'PROXY ${endpoint.$1}:${endpoint.$2}';
  }

  static (String, int)? currentEndpoint() {
    if (!Platform.isWindows) return null;
    try {
      final key = CURRENT_USER.open(_subKey);
      try {
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
