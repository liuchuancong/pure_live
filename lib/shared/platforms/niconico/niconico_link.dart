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
}
