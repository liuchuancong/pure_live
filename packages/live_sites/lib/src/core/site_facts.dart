import 'package:live_sites/src/models/enums/live_gift_unit.dart';

/// Cross-site knowledge that is not any one site's business: platform facts
/// the whole package and the app ask about by site id (the counterpart of
/// the per-site `LiveSiteManifest`, which holds what each site says about
/// itself).
abstract final class SiteFacts {
  /// Voice platforms: the stream's video track is a placeholder (Missevan's
  /// 16 × 16 picture) or a plain background (Kilakila's colour or picture),
  /// so a room shows its cover instead of the video.
  static const Set<String> voiceLive = {'missevan', 'kilakila'};

  /// Platforms whose room id is a user name or alias the platform itself
  /// matches without regard to case, so room identity folds case there. The
  /// room id keeps the spelling it was stored with; only comparisons fold.
  ///
  /// - Twitch: the login name; logins are lower case.
  /// - SOOP: the streamer id (BJ id), answered in lower case.
  /// - Picarto: the channel name; any case finds it, the platform answers
  ///   its own spelling.
  /// - TwitCasting: the screen id, requested in its lower-case form.
  /// - Douyu: a rid or 靓号 (digits) or an alias; the room page redirects an
  ///   alias in any case to the same rid.
  /// - Kuaishou: the user id; the room page finds a streamer in any case.
  /// - Bigo: the user id; answered in its own spelling.
  /// - Kick: the slug, matched without regard to case.
  static const Set<String> caseInsensitiveRoomIds = {
    'twitch',
    'soop',
    'picarto',
    'twitcasting',
    'douyu',
    'kuaishou',
    'bigo',
    'kick',
  };

  /// Platforms retired before this lineage (hard to maintain, niche or
  /// unusable). Stored follows, history and links for them stay readable and
  /// are shown as retired instead of failing as unknown.
  static const Set<String> retired = {
    'huajiao',
    'openrec',
    'ttinglive',
    'popkontv',
    'shopeelive',
    'vkvideolive',
    'nimotv',
    'dailymotion',
    'rumble',
    'goodgame',
    'taobaolive',
  };

  /// Web hosts of the retired platforms, so a shared link is answered with
  /// "retired" instead of being ignored as unrecognised text.
  static const Set<String> retiredHosts = {
    'huajiao.com',
    'openrec.tv',
    'flextv.co.kr',
    'ttinglive.com',
    'popkontv.com',
    'goodgame.ru',
    'vkvideo.ru',
    'vkplay.live',
    'dailymotion.com',
    'dai.ly',
    'rumble.com',
    'nimo.tv',
    'shopee.co.id',
    'taobao.com',
    'm.tb.cn',
  };

  /// The platforms whose danmaku reports super chats or paid messages like
  /// them, and the unit of their `LiveSuperChatMessage.price`:
  ///
  /// - Bilibili `SUPER_CHAT_MESSAGE` (and its polled list) and Douyu
  ///   `comm_chatmsg`/`voice_trlt` in yuan; Huya's head-line board in yuan;
  /// - Missevan's paid questions in diamonds, KilaKila's in red beans;
  ///   Picarto's Kudos tips, YouTube's Super Chats in the buyer's currency
  ///   (only the display text says either); CHZZK's donations in cheese;
  ///   17LIVE's paid barrage in points; Kick's Kicks with a message; Six
  ///   Rooms' fly-screens in six coins.
  static const Map<String, LiveGiftUnit> superChatUnits = {
    'bilibili': LiveGiftUnit.yuan,
    'douyu': LiveGiftUnit.yuan,
    'huya': LiveGiftUnit.yuan,
    'missevan': LiveGiftUnit.diamond,
    'kilakila': LiveGiftUnit.redBean,
    'picarto': LiveGiftUnit.other,
    'chzzk': LiveGiftUnit.cheese,
    'youtube': LiveGiftUnit.other,
    '17live': LiveGiftUnit.point,
    'kick': LiveGiftUnit.kicks,
    'sixroom': LiveGiftUnit.sixCoin,
  };

  /// The platforms with super chats: the keys of [superChatUnits].
  static final Set<String> superChatPlatforms = Set.unmodifiable(superChatUnits.keys);

  /// Whether rooms of [platform] are identified without regard to the room
  /// id's case (see [caseInsensitiveRoomIds]).
  static bool ignoresRoomIdCase(String platform) => caseInsensitiveRoomIds.contains(platform.trim().toLowerCase());

  /// Whether [platform] is a supported voice platform (see [voiceLive]).
  static bool isVoiceLive(String platform) => voiceLive.contains(platform.trim().toLowerCase());

  /// Whether a platform reports super chats (see [superChatPlatforms]); an
  /// empty list from such a platform says the room has none, not "they will
  /// show up here".
  static bool hasSuperChats(String platform) => superChatPlatforms.contains(platform.trim().toLowerCase());

  /// The unit the platform's super chat prices are counted in, when it has
  /// super chats at all.
  static LiveGiftUnit? superChatUnitOf(String platform) =>
      superChatUnits[platform.trim().toLowerCase()];

  /// Whether [platform] is a retired platform (see [retired]).
  static bool isRetired(String platform) => retired.contains(platform.trim().toLowerCase());

  /// Whether [text] contains a link to a retired platform (see
  /// [retiredHosts]).
  static bool isRetiredLink(String text) {
    for (final match in RegExp(r'https?://[^\s]+', caseSensitive: false).allMatches(text)) {
      final host = Uri.tryParse(match.group(0)!)?.host.toLowerCase() ?? '';
      if (retiredHosts.any((root) => host == root || host.endsWith('.$root'))) return true;
    }
    return false;
  }
}
