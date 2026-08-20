import 'package:pure_live/common/index.dart';

class LocalGift {
  const LocalGift({
    required this.id,
    required this.nameKey,
    required this.emoji,
    required this.price,
    required this.color,
    this.effect = 'ticker',
  });

  final String id;
  final String nameKey;
  final String emoji;
  final int price;
  final LiveMessageColor color;
  final String effect;
}

class LocalPlatformPack {
  const LocalPlatformPack({
    required this.id,
    required this.name,
    required this.currencyKey,
    required this.levelKey,
    required this.accentColor,
    required this.badge,
  });

  final String id;
  final String name;
  final String currencyKey;
  final String levelKey;
  final Color accentColor;
  final String badge;
}

class LocalInteractionController extends GetxController {
  final RxBool enabled = hiveBool('localInteraction.enabled', true);
  final RxString userName = hiveString('localInteraction.userName', 'Pure Live');
  final RxString selectedTitle = hiveString('localInteraction.title', 'listener');
  final RxBool showAsDanmaku = hiveBool('localInteraction.showAsDanmaku', true);
  final RxBool showPlatformBadge = hiveBool('localInteraction.showPlatformBadge', true);
  final RxBool showLevelBadge = hiveBool('localInteraction.showLevelBadge', true);
  final RxBool enableGiftEffects = hiveBool('localInteraction.enableGiftEffects', true);
  final RxString previewPlatform = hiveString('localInteraction.previewPlatform', Sites.bilibiliSite);
  final RxInt coins = hiveInt('localInteraction.coins', 1000);
  final RxInt experience = hiveInt('localInteraction.experience', 0);
  final RxList<String> history = hiveStringList('localInteraction.history', const []);

  static const gifts = <LocalGift>[
    LocalGift(id: 'heart', nameKey: 'local_gift_heart', emoji: '💗', price: 10, color: LiveMessageColor(255, 105, 180)),
    LocalGift(
      id: 'flower',
      nameKey: 'local_gift_flower',
      emoji: '🌸',
      price: 50,
      color: LiveMessageColor(255, 128, 171),
    ),
    LocalGift(
      id: 'rocket',
      nameKey: 'local_gift_rocket',
      emoji: '🚀',
      price: 500,
      color: LiveMessageColor(255, 165, 0),
    ),
    LocalGift(
      id: 'castle',
      nameKey: 'local_gift_castle',
      emoji: '🏰',
      price: 2000,
      color: LiveMessageColor(138, 43, 226),
    ),
  ];

  static const platformPacks = <LocalPlatformPack>[
    LocalPlatformPack(
      id: Sites.bilibiliSite,
      name: '哔哩哔哩',
      currencyKey: 'local_currency_bili',
      levelKey: 'local_level_bili',
      accentColor: Color(0xFF00AEEC),
      badge: '📺',
    ),
    LocalPlatformPack(
      id: Sites.douyuSite,
      name: '斗鱼',
      currencyKey: 'local_currency_douyu',
      levelKey: 'local_level_douyu',
      accentColor: Color(0xFFFF6A00),
      badge: '🐟',
    ),
    LocalPlatformPack(
      id: Sites.huyaSite,
      name: '虎牙',
      currencyKey: 'local_currency_huya',
      levelKey: 'local_level_huya',
      accentColor: Color(0xFFFF9800),
      badge: '🐯',
    ),
    LocalPlatformPack(
      id: Sites.douyinSite,
      name: '抖音',
      currencyKey: 'local_currency_douyin',
      levelKey: 'local_level_douyin',
      accentColor: Color(0xFFFE2C55),
      badge: '🎵',
    ),
    LocalPlatformPack(
      id: Sites.kuaishouSite,
      name: '快手',
      currencyKey: 'local_currency_kuaishou',
      levelKey: 'local_level_kuaishou',
      accentColor: Color(0xFFFF4906),
      badge: '🎬',
    ),
    LocalPlatformPack(
      id: Sites.ccSite,
      name: '网易 CC',
      currencyKey: 'local_currency_cc',
      levelKey: 'local_level_cc',
      accentColor: Color(0xFFFF4D7D),
      badge: '🎮',
    ),
    LocalPlatformPack(
      id: Sites.twitchSite,
      name: 'Twitch',
      currencyKey: 'local_currency_twitch',
      levelKey: 'local_level_twitch',
      accentColor: Color(0xFF9146FF),
      badge: '💜',
    ),
    LocalPlatformPack(
      id: Sites.soopSite,
      name: 'SOOP',
      currencyKey: 'local_currency_soop',
      levelKey: 'local_level_soop',
      accentColor: Color(0xFF0675E8),
      badge: '🎈',
    ),
  ];

  static const _platformGifts = <String, List<LocalGift>>{
    Sites.bilibiliSite: [
      LocalGift(
        id: 'bili_snack',
        nameKey: 'local_gift_bili_snack',
        emoji: '🌶️',
        price: 10,
        color: LiveMessageColor(255, 102, 102),
      ),
      LocalGift(
        id: 'bili_tv',
        nameKey: 'local_gift_bili_tv',
        emoji: '📺',
        price: 100,
        color: LiveMessageColor(84, 197, 248),
      ),
      LocalGift(
        id: 'bili_voyage',
        nameKey: 'local_gift_bili_voyage',
        emoji: '⚓',
        price: 1980,
        color: LiveMessageColor(255, 99, 146),
        effect: 'full',
      ),
    ],
    Sites.douyuSite: [
      LocalGift(
        id: 'douyu_ball',
        nameKey: 'local_gift_douyu_ball',
        emoji: '🐟',
        price: 10,
        color: LiveMessageColor(255, 144, 0),
      ),
      LocalGift(
        id: 'douyu_rocket',
        nameKey: 'local_gift_douyu_rocket',
        emoji: '🚀',
        price: 500,
        color: LiveMessageColor(255, 123, 0),
      ),
      LocalGift(
        id: 'douyu_super_rocket',
        nameKey: 'local_gift_douyu_super_rocket',
        emoji: '🛰️',
        price: 2000,
        color: LiveMessageColor(255, 76, 0),
        effect: 'full',
      ),
    ],
    Sites.huyaSite: [
      LocalGift(
        id: 'huya_stick',
        nameKey: 'local_gift_huya_stick',
        emoji: '✨',
        price: 10,
        color: LiveMessageColor(255, 202, 40),
      ),
      LocalGift(
        id: 'huya_sword',
        nameKey: 'local_gift_huya_sword',
        emoji: '⚔️',
        price: 300,
        color: LiveMessageColor(255, 174, 0),
      ),
      LocalGift(
        id: 'huya_one',
        nameKey: 'local_gift_huya_one',
        emoji: '🐯',
        price: 1000,
        color: LiveMessageColor(255, 128, 0),
        effect: 'full',
      ),
    ],
    Sites.douyinSite: [
      LocalGift(
        id: 'douyin_heart',
        nameKey: 'local_gift_douyin_heart',
        emoji: '💖',
        price: 10,
        color: LiveMessageColor(254, 44, 85),
      ),
      LocalGift(
        id: 'douyin_badge',
        nameKey: 'local_gift_douyin_badge',
        emoji: '🎖️',
        price: 200,
        color: LiveMessageColor(255, 86, 124),
      ),
      LocalGift(
        id: 'douyin_carnival',
        nameKey: 'local_gift_douyin_carnival',
        emoji: '🎡',
        price: 3000,
        color: LiveMessageColor(254, 44, 85),
        effect: 'full',
      ),
    ],
    Sites.kuaishouSite: [
      LocalGift(
        id: 'ks_beer',
        nameKey: 'local_gift_ks_beer',
        emoji: '🍺',
        price: 10,
        color: LiveMessageColor(255, 98, 0),
      ),
      LocalGift(
        id: 'ks_arrow',
        nameKey: 'local_gift_ks_arrow',
        emoji: '🏹',
        price: 500,
        color: LiveMessageColor(255, 74, 0),
      ),
      LocalGift(
        id: 'ks_guard',
        nameKey: 'local_gift_ks_guard',
        emoji: '🛡️',
        price: 1500,
        color: LiveMessageColor(255, 58, 48),
        effect: 'full',
      ),
    ],
    Sites.ccSite: [
      LocalGift(
        id: 'cc_flower',
        nameKey: 'local_gift_cc_flower',
        emoji: '🌺',
        price: 10,
        color: LiveMessageColor(255, 92, 155),
      ),
      LocalGift(
        id: 'cc_car',
        nameKey: 'local_gift_cc_car',
        emoji: '🏎️',
        price: 500,
        color: LiveMessageColor(255, 66, 80),
      ),
      LocalGift(
        id: 'cc_guard',
        nameKey: 'local_gift_cc_guard',
        emoji: '👑',
        price: 1800,
        color: LiveMessageColor(163, 89, 255),
        effect: 'full',
      ),
    ],
    Sites.twitchSite: [
      LocalGift(
        id: 'twitch_cheer',
        nameKey: 'local_gift_twitch_cheer',
        emoji: '💎',
        price: 10,
        color: LiveMessageColor(145, 70, 255),
      ),
      LocalGift(
        id: 'twitch_sub',
        nameKey: 'local_gift_twitch_sub',
        emoji: '⭐',
        price: 500,
        color: LiveMessageColor(169, 112, 255),
      ),
      LocalGift(
        id: 'twitch_hype_train',
        nameKey: 'local_gift_twitch_hype_train',
        emoji: '🚂',
        price: 2000,
        color: LiveMessageColor(112, 44, 190),
        effect: 'full',
      ),
    ],
    Sites.soopSite: [
      LocalGift(
        id: 'soop_star_balloon',
        nameKey: 'local_gift_soop_star_balloon',
        emoji: '⭐',
        price: 10,
        color: LiveMessageColor(6, 117, 232),
      ),
      LocalGift(
        id: 'soop_sticker',
        nameKey: 'local_gift_soop_sticker',
        emoji: '🎟️',
        price: 300,
        color: LiveMessageColor(52, 147, 245),
      ),
      LocalGift(
        id: 'soop_signature_balloon',
        nameKey: 'local_gift_soop_signature_balloon',
        emoji: '🎈',
        price: 2000,
        color: LiveMessageColor(0, 88, 190),
        effect: 'full',
      ),
    ],
  };

  static const titles = <String>['listener', 'night_owl', 'supporter', 'guardian'];

  int get level => levelForExperience(experience.v);

  String get titleLabel => i18n('local_title_${selectedTitle.v}');

  static int levelForExperience(int value) => (value < 0 ? 0 : value) ~/ 500 + 1;

  static String normalizeUserName(String value) {
    final name = value.trim();
    if (name.isEmpty) return '';
    return name.substring(0, name.length.clamp(0, 20).toInt());
  }

  void updateName(String value) {
    final name = normalizeUserName(value);
    if (name.isNotEmpty) userName.v = name;
  }

  void recharge(int amount) {
    if (amount <= 0) return;
    coins.v += amount;
    _addHistory('${i18n('local_recharge_record')} +$amount');
  }

  static List<LocalGift> giftsForPlatform(String platform) => _platformGifts[platform] ?? gifts;

  static LocalPlatformPack packForPlatform(String platform) =>
      platformPacks.firstWhere((pack) => pack.id == platform, orElse: () => platformPacks.first);

  static String platformBadgeKey(String platform) => switch (platform) {
    Sites.bilibiliSite => 'local_badge_bilibili',
    Sites.douyuSite => 'local_badge_douyu',
    Sites.huyaSite => 'local_badge_huya',
    Sites.douyinSite => 'local_badge_douyin',
    Sites.kuaishouSite => 'local_badge_kuaishou',
    Sites.ccSite => 'local_badge_cc',
    Sites.twitchSite => 'local_badge_twitch',
    Sites.soopSite => 'local_badge_soop',
    _ => 'local_badge_generic',
  };

  String profileLabel(String platform) {
    final parts = <String>[];
    if (showPlatformBadge.v) parts.add('${packForPlatform(platform).badge} ${i18n(platformBadgeKey(platform))}');
    parts.add(titleLabel);
    return parts.join(' · ');
  }

  LiveMessage createChat(String text, {String platform = ''}) {
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: '${profileLabel(platform)} · ${userName.v}',
      message: text.trim(),
      color: LiveMessageColor.white,
      userLevel: showLevelBadge.v ? level.toString() : '',
      isLocal: true,
    );
  }

  LiveMessage? sendGift(LocalGift gift, {String platform = ''}) {
    if (!enabled.v) return null;
    if (coins.v < gift.price) return null;
    coins.v -= gift.price;
    experience.v += gift.price;
    final giftName = i18n(gift.nameKey);
    final badge = profileLabel(platform);
    final message = '${gift.emoji} $badge · ${userName.v} ${i18n('local_sent_gift')} $giftName ×1';
    _addHistory(message);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: userName.v,
      message: message,
      data: {
        'giftId': gift.id,
        'price': gift.price,
        'count': 1,
        'local': true,
        'platform': platform,
        'effect': enableGiftEffects.v ? gift.effect : 'none',
      },
      color: gift.color,
      userLevel: showLevelBadge.v ? level.toString() : '',
      fansName: titleLabel,
      isLocal: true,
    );
  }

  void _addHistory(String value) {
    history.insert(0, value);
    if (history.length > 30) history.removeRange(30, history.length);
  }

  void clearHistory() => history.clear();
}
