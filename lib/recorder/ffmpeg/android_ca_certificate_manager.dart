import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AndroidCaCertificateManager {
  AndroidCaCertificateManager._();

  static const String _assetPath = 'assets/cacert.pem';
  static const String _fileName = 'cacert.pem';

  static Future<String>? _initialization;

  /// Android:
  /// assets/cacert.pem
  ///        ↓
  /// ApplicationSupportDirectory/cacert.pem
  ///
  /// Other platforms:
  /// returns null.
  static Future<String?> ensureReady() {
    if (!Platform.isAndroid) {
      return Future<String?>.value(null);
    }

    return _initialization ??= _prepare();
  }

  static Future<String> _prepare() async {
    final directory = await getApplicationSupportDirectory();

    final target = File('${directory.path}${Platform.pathSeparator}$_fileName');

    // 已经存在有效 CA bundle，直接复用。
    if (await _isValidCertificate(target)) {
      return target.path;
    }

    final data = await rootBundle.load(_assetPath);

    if (data.lengthInBytes < 1024) {
      throw StateError('CA certificate asset is missing or empty: $_assetPath');
    }

    final temp = File('${target.path}.tmp');

    try {
      await temp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );

      if (await target.exists()) {
        await target.delete();
      }

      await temp.rename(target.path);

      if (!await _isValidCertificate(target)) {
        throw StateError('Invalid CA certificate bundle: ${target.path}');
      }

      return target.path;
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  static Future<bool> _isValidCertificate(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      final stat = await file.stat();

      // 防止空文件或者明显残缺的文件。
      if (stat.size < 1024) {
        return false;
      }

      final content = await file.readAsString();

      return content.contains('-----BEGIN CERTIFICATE-----') &&
          content.contains('-----END CERTIFICATE-----');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isReady() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final directory = await getApplicationSupportDirectory();

    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');

    return _isValidCertificate(file);
  }

  /// 删除缓存的 CA bundle。
  ///
  /// 下一次调用 ensureReady() 时会重新从 assets 提取。
  static Future<void> clearCache() async {
    _initialization = null;

    if (!Platform.isAndroid) {
      return;
    }

    final directory = await getApplicationSupportDirectory();

    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');

    if (await file.exists()) {
      await file.delete();
    }
  }
}
