// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The anonymous visitor a bigo chat socket logs in as: what the website's
/// `studio/getWebSocketLink` hands every visitor.
final class BigoChatVisitor {
  /// Creates the visitor.
  const BigoChatVisitor({required this.userId, required this.token, required this.deviceId, this.userName = '0'});

  /// `userId`: the visitor's account, digits.
  final String userId;

  /// `uidToken` without the `###VER2` marker the page strips: the login's
  /// `cookie`. Never logged.
  final String token;

  /// `userName` (`0` for a visitor).
  final String userName;

  /// `deviceId`: the device the visitor was issued for (the page's own `web_…`
  /// value, echoed).
  final String deviceId;

  @override
  String toString() => 'BigoChatVisitor($userId)';
}
