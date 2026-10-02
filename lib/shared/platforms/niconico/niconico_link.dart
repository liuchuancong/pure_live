import 'niconico_watch.dart';

/// Only verified HTTPS watch links, not user/channel pages or media grants.
class NiconicoLink {
  static String? parse(String raw) {
    final value = raw.trim();
    if (!value.startsWith('https://live.nicovideo.jp/watch/')) return null;
    try {
      return NiconicoWatch.parseInput(value);
    } on NiconicoException {
      return null;
    }
  }

  static String url(String programId) =>
      'https://live.nicovideo.jp/watch/${NiconicoWatch.validateProgramId(programId)}';
}
