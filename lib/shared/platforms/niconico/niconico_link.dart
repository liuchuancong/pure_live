import 'niconico_watch.dart';

/// 节目链接的形态（上游 17-2）：`live.nicovideo.jp/watch/lv…`（3.x 的形态），
/// 加上旧移动站 `sp.live.nicovideo.jp/watch/lv…` 与 App 的分享短链 `nico.ms/lv…`，
/// **https 与 http 都收**，可带查询与片段；其它主机、端口、凭据、编码或点段路径、
/// 多余尾段都不是节目链接。主播链接（user/ch）还没有转成房间身份，这里先不认。
class NiconicoLink {
  static final RegExp _programLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/(lv[1-9][0-9]{0,17})(?:\?[^#\s]*)?(?:#[^\s]*)?$',
  );
  static final RegExp _shortLink = RegExp(r'^https?://nico\.ms/(lv[1-9][0-9]{0,17})(?:\?[^#\s]*)?(?:#[^\s]*)?$');

  static String? parse(String raw) {
    final value = raw.trim();
    if (value.length > 2048) return null;
    try {
      // 直接给节目号（3.x 的输入方式）仍然收。
      if (value.startsWith('lv')) return NiconicoWatch.validateProgramId(value);
      final match = _programLink.firstMatch(value) ?? _shortLink.firstMatch(value);
      if (match == null) return null;
      return NiconicoWatch.validateProgramId(match.group(1)!);
    } on NiconicoException {
      return null;
    }
  }

  static String url(String programId) =>
      'https://live.nicovideo.jp/watch/${NiconicoWatch.validateProgramId(programId)}';

  static final RegExp _userPage = RegExp(r'^https?://www\.nicovideo\.jp/user/([1-9][0-9]{0,17})(?:[/?#][^\s]*)?$');
  static final RegExp _broadcasterLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/((?:user/[1-9][0-9]{0,17})|(?:ch[1-9][0-9]{0,17}))(?:[/?#][^\s]*)?$',
  );
  static final RegExp _channelPage = RegExp(
    r'^https?://ch\.nicovideo\.jp/(ch[1-9][0-9]{0,17})(?:/(?:live|video)?)?(?:[/?#][^\s]*)?$',
  );

  /// 主播链接（上游 17-2）：`live.nicovideo.jp/watch/user/<id>` 与 `…/watch/ch<n>`
  /// （`sp.` 同样）、用户页 `www.nicovideo.jp/user/<id>`、频道页 `ch.nicovideo.jp/ch<n>`
  /// （可带一个小写子页，如 `/live`）。返回主播身份（`user/<id>` 或 `ch<n>`），
  /// 需要一次 watch 页请求才能换成当前节目号。自定义频道名（`ch.nicovideo.jp/<name>`）
  /// 不在其中。
  static String? parseBroadcaster(String raw) {
    final value = raw.trim();
    if (value.length > 2048) return null;
    final user = _userPage.firstMatch(value)?.group(1);
    if (user != null) return 'user/$user';
    return _broadcasterLink.firstMatch(value)?.group(1) ?? _channelPage.firstMatch(value)?.group(1);
  }
}
