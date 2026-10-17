import 'dart:io' show HttpDate;

import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

/// The QR login (`passport.bilibili.com`) and account
/// (`x/member/web/account`) answers, parsed.
abstract final class BilibiliAuthParser {
  /// `qrcode/generate`: the key to poll with and the URL to encode. The url
  /// must be an https address (what the QR image shows).
  static ({String key, String url}) qrGenerate(String body, {int status = 200}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, what: 'qrcode/generate', status: status)['data']);
    final key = jsonString(data?['qrcode_key'])?.trim() ?? '';
    final url = jsonString(data?['url'])?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (key.isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'qrcode/generate: no qrcode_key or url');
    }
    return (key: key, url: url);
  }

  /// `qrcode/poll`: the QR's login state (`data.code`: 86101 not scanned,
  /// 86090 scanned, 0 confirmed, 86038 expired).
  static int qrPollState(String body, {int status = 200}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, what: 'qrcode/poll', status: status)['data']);
    final code = jsonInt(data?['code']);
    if (code == null) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'qrcode/poll: no state code');
    }
    return code;
  }

  /// The cookie pairs of the poll's `Set-Cookie` lines (each pair is
  /// everything before the first `;`), and `expiry` the `SESSDATA` line's
  /// `Expires` — the login ticket's end. Duplicated names keep their first
  /// value.
  static ({Map<String, String> cookies, DateTime? expiry}) grantedCookies(Iterable<String> setCookies) {
    final cookies = <String, String>{};
    DateTime? expiry;
    for (final line in setCookies) {
      final pair = line.split(';').first.trim();
      final equals = pair.indexOf('=');
      if (equals <= 0) continue;
      final name = pair.substring(0, equals).trim();
      final value = pair.substring(equals + 1).trim();
      if (name.isEmpty || value.isEmpty || cookies.containsKey(name)) continue;
      cookies[name] = value;
      if (name == 'SESSDATA') expiry = expiresOf(line);
    }
    return (cookies: cookies, expiry: expiry);
  }

  /// `member/web/account`: the signed-in account's uid, name and avatar; the
  /// envelope's `-101` comes back as needs-login.
  static ({int uid, String name, String face}) account(String body, {int status = 200}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, what: 'member/web/account', status: status)['data']);
    final name = jsonString(data?['uname']) ?? '';
    final uid = BilibiliRoomParser.roomIdOf(data?['mid']);
    if (name.isEmpty || uid == null) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'member/web/account: no uname or mid');
    }
    return (uid: int.parse(uid), name: name, face: imageUrl(data?['face']));
  }

  /// The `Expires` attribute of a `Set-Cookie` line, null when absent or
  /// unreadable.
  static DateTime? expiresOf(String line) {
    for (final attribute in line.split(';')) {
      final equals = attribute.indexOf('=');
      if (equals <= 0) continue;
      if (attribute.substring(0, equals).trim().toLowerCase() != 'expires') continue;
      try {
        return HttpDate.parse(attribute.substring(equals + 1).trim());
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}
