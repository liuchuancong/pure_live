/// Where the adapter reads what renewing a douyu login needs beside the
/// cookie, and where a renewed cookie goes. The app implements it over its
/// settings/account store; null means every request goes out as a guest.
abstract interface class DouyuLoginStore {
  /// The login cookie (a pasted browser cookie counts).
  String get cookie;

  /// LTP0 saved apart from the cookie.
  String? get longTermKey;

  /// The login's `dy_did` saved apart from the cookie.
  String? get deviceId;

  /// When the cookie was saved or last renewed.
  DateTime? get savedAt;

  /// Stores [cookie] as the login, renewed at [renewedAt].
  Future<void> saveRenewed(String cookie, DateTime renewedAt);
}
