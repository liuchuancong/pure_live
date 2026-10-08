import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/platform/app_path_manager.dart';

/// Provides a deterministic CA database to FFmpeg builds that use OpenSSL.
///
/// FFmpeg 9 verifies TLS peers by default. Android and Linux do not expose a
/// portable OpenSSL CA file to an embedded native library, while the builder's
/// compile-time OPENSSLDIR is not present on an end-user device. Keep peer
/// verification enabled and pass a reviewed Mozilla CA bundle explicitly.
class FFmpegTlsTrustStore {
  const FFmpegTlsTrustStore._();

  static const String assetPath = 'assets/certificates/mozilla-ca-bundle.pem';
  static const String bundleDate = '2026-08-13';
  static const String bundleSha256 = 'f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9';

  static String? _readyPath;
  static Future<String?>? _preparing;

  /// Windows uses Schannel and Apple platforms use Secure Transport. The
  /// bundled OpenSSL trust store is only needed by the Android/Linux binaries.
  static bool get needsBundledCaFile => !kIsWeb && (Platform.isAndroid || Platform.isLinux);

  static Future<String?> ensureReady() {
    if (!needsBundledCaFile) return Future<String?>.value();
    final ready = _readyPath;
    if (ready != null) return Future<String?>.value(ready);
    final inFlight = _preparing;
    if (inFlight != null) return inFlight;

    final future = _prepare();
    _preparing = future;
    return future.whenComplete(() {
      if (identical(_preparing, future)) _preparing = null;
    });
  }

  static Future<String> _prepare() async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    _verify(bytes, source: assetPath);

    final directory = await AppPathManager().getDir('CERTIFICATES');
    final target = File(p.join(directory.path, 'mozilla-ca-$bundleDate-$bundleSha256.pem'));
    if (await target.exists()) {
      final existing = await target.readAsBytes();
      try {
        _verify(existing, source: target.path);
        _readyPath = target.path;
        return target.path;
      } on StateError {
        await target.delete();
      }
    }

    final temporary = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      // A concurrent initializer may have completed the same immutable file.
      if (!await target.exists()) rethrow;
      if (await temporary.exists()) await temporary.delete();
    }
    _verify(await target.readAsBytes(), source: target.path);
    _readyPath = target.path;
    return target.path;
  }

  static void _verify(Uint8List bytes, {required String source}) {
    final actual = sha256.convert(bytes).toString();
    if (actual != bundleSha256) {
      throw StateError('FFmpeg CA bundle integrity check failed: $source');
    }
  }

  /// Inserts the CA input option immediately before each HTTPS input.
  ///
  /// This transformation runs after the complete command has been assembled,
  /// so every recorder and audio-only relay receives the same TLS policy. The
  /// HTTPS HLS child resources are handled by `FFmpegHlsInputRelay`, because
  /// FFmpeg 9.0.1 does not propagate this option from a manifest to its child
  /// requests. This transformation is idempotent and leaves HTTP, RTMP, RTSP
  /// and local-file inputs untouched.
  static List<String> injectCaFile(Iterable<String> arguments, {String? caFile}) {
    final source = List<String>.of(arguments);
    final trustedFile = caFile?.trim() ?? '';
    if (trustedFile.isEmpty || source.contains('-ca_file')) return List<String>.unmodifiable(source);

    final result = <String>[];
    for (var index = 0; index < source.length; index++) {
      final argument = source[index];
      if (argument == '-i' && index + 1 < source.length) {
        final scheme = Uri.tryParse(source[index + 1].trim())?.scheme.toLowerCase();
        if (scheme == 'https') result.addAll(<String>['-ca_file', trustedFile]);
      }
      result.add(argument);
    }
    return List<String>.unmodifiable(result);
  }

  @visibleForTesting
  static void resetForTest() {
    _readyPath = null;
    _preparing = null;
  }
}
