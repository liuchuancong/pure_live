import 'package:meta/meta.dart';

/// Bilibili platform constants and danmaku connection credentials.
abstract final class BilibiliConstants {
  /// Live API host.
  static const String apiHost = 'api.live.bilibili.com';

  /// Fallback anonymous danmaku gateway.
  static const String danmakuGateway = 'wss://broadcastlv.chat.bilibili.com/sub';

  /// Standard web player headers for live media.
  static const Map<String, String> mediaHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://live.bilibili.com/',
  };
}

/// Credentials for one danmaku connection.
///
/// `token` may be empty for anonymous guest connections against the
/// default gateway; signed flows fill it from `getDanmuInfo`.
@immutable
final class BilibiliDanmakuArgs {
  /// Connection credentials.
  const new({required this.roomId, required this.uid, required this.token, required this.server});

  /// The long numeric room id.
  final int roomId;

  /// The connecting user's id (0 when anonymous).
  final int uid;

  /// The auth token from `getDanmuInfo`; empty for anonymous.
  final String token;

  /// The gateway URL to connect.
  final String server;

  @override
  String toString() =>
      'BilibiliDanmakuArgs(room: $roomId, uid: $uid, '
      'token: ${token.isEmpty ? 'anonymous' : 'signed'}, server: $server)';
}
