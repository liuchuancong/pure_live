import 'dart:typed_data';

/// Seals and opens secrets with a device-bound key (Android Keystore,
/// Windows DPAPI), implemented by the application shell — the key never
/// leaves the platform, so the interface seals and opens instead of
/// handing one out.
abstract interface class SecretCipher {
  /// [plain] encrypted; [ref] is bound to the result so a sealed value
  /// cannot be moved to another name.
  Future<Uint8List> seal(String ref, String plain);

  /// The plain text of [sealed]; throws when it cannot be opened (another
  /// device, a reinstall, a lost key).
  Future<String> open(String ref, Uint8List sealed);
}

/// Names of the stored secrets. A ref doubles as the ciphertext's
/// associated data, so values are pinned to their name.
abstract final class SecretRefs {
  /// The cookie header of platform [site].
  static String cookie(String site) => 'cookie/${site.trim().toLowerCase()}';

  /// Douyu's long-term passport key.
  static const String douyuLtp0 = 'cookie/douyu.ltp0';

  /// Douyu's passport device id.
  static const String douyuDid = 'cookie/douyu.did';

  /// A remembered sign-in [uid] on platform [site].
  static String account(String site, int uid) => 'account/${site.trim().toLowerCase()}/$uid';

  /// The password of the WebDAV server named [name].
  static String webdav(String name) => 'webdav/$name';
}
