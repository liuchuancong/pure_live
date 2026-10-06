import 'niconico_api.dart';
import 'niconico_watch.dart';

class NiconicoLink {
  static final RegExp _programLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/(lv[1-9][0-9]{0,17})(?:\?[^#\s]*)?(?:#[^\s]*)?$',
  );
  static final RegExp _shortLink = RegExp(r'^https?://nico\.ms/(lv[1-9][0-9]{0,17})(?:\?[^#\s]*)?(?:#[^\s]*)?$');

  static String? parse(String raw) {
    final value = raw.trim();
    if (value.length > 2048) return null;
    try {
      if (value.startsWith('lv')) return NiconicoWatch.validateProgramId(value);
      final match = _programLink.firstMatch(value) ?? _shortLink.firstMatch(value);
      if (match == null) return null;
      return NiconicoWatch.validateProgramId(match.group(1)!);
    } on NiconicoException {
      return null;
    }
  }

  static String url(String roomId) {
    if (NiconicoApi.isBroadcasterRoomId(roomId)) return '${NiconicoApi.origin}/watch/$roomId';
    return '${NiconicoApi.origin}/watch/${NiconicoWatch.validateProgramId(roomId)}';
  }

  static final RegExp _userPage = RegExp(r'^https?://www\.nicovideo\.jp/user/([1-9][0-9]{0,17})(?:[/?#][^\s]*)?$');
  static final RegExp _broadcasterLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/((?:user/[1-9][0-9]{0,17})|(?:ch[1-9][0-9]{0,17}))(?:[/?#][^\s]*)?$',
  );
  static final RegExp _channelPage = RegExp(
    r'^https?://ch\.nicovideo\.jp/(ch[1-9][0-9]{0,17})(?:/(?:live|video)?)?(?:[/?#][^\s]*)?$',
  );

  static String? parseBroadcaster(String raw) {
    final value = raw.trim();
    if (value.length > 2048) return null;
    final user = _userPage.firstMatch(value)?.group(1);
    if (user != null) return 'user/$user';
    return _broadcasterLink.firstMatch(value)?.group(1) ?? _channelPage.firstMatch(value)?.group(1);
  }
}
