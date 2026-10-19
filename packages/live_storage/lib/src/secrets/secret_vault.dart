/// The device's secret vault — flutter_secure_storage on the app side,
/// backed by the Android Keystore, the iOS Keychain or Windows DPAPI.
///
/// The interface lives here so storage code never imports the plugin; the
/// app shell provides the implementation.
abstract interface class SecretVault {
  /// Every stored ref and its plain text.
  Future<Map<String, String>> readAll();

  /// Stores [plain] under [ref], replacing any previous value.
  Future<void> write(String ref, String plain);

  /// Removes [ref]; a no-op when absent.
  Future<void> delete(String ref);
}

/// Names of the stored secrets, kept in one place so no two features
/// collide on a ref.
abstract final class SecretRefs {
  /// The cookie header of platform [site].
  static String cookie(String site) => 'cookie/${site.trim().toLowerCase()}';

  /// Douyu's long-term passport key.
  static const String douyuLtp0 = 'cookie/douyu.ltp0';

  /// Douyu's passport device id.
  static const String douyuDid = 'cookie/douyu.did';

  /// When Douyu's login cookie was saved or last renewed.
  static const String douyuSavedAt = 'cookie/douyu.savedAt';

  /// A remembered sign-in [uid] on platform [site].
  static String account(String site, int uid) => 'account/${site.trim().toLowerCase()}/$uid';

  /// The password of the WebDAV server named [name].
  static String webdav(String name) => 'webdav/$name';
}
