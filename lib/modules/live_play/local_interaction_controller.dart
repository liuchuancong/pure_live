import 'package:pure_live/common/index.dart';

class LocalGift {
  const LocalGift({
    required this.id,
    required this.nameKey,
    required this.emoji,
    required this.price,
    required this.color,
  });

  final String id;
  final String nameKey;
  final String emoji;
  final int price;
  final LiveMessageColor color;
}

class LocalInteractionController extends GetxController {
  final RxBool enabled = hiveBool('localInteraction.enabled', true);
  final RxString userName = hiveString('localInteraction.userName', 'Pure Live');
  final RxString selectedTitle = hiveString('localInteraction.title', 'listener');
  final RxBool showAsDanmaku = hiveBool('localInteraction.showAsDanmaku', true);
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

  LiveMessage createChat(String text) {
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: '$titleLabel · ${userName.v}',
      message: text.trim(),
      color: LiveMessageColor.white,
      userLevel: level.toString(),
    );
  }

  LiveMessage? sendGift(LocalGift gift) {
    if (!enabled.v) return null;
    if (coins.v < gift.price) return null;
    coins.v -= gift.price;
    experience.v += gift.price;
    final giftName = i18n(gift.nameKey);
    final message = '${gift.emoji} $titleLabel · ${userName.v} ${i18n('local_sent_gift')} $giftName ×1';
    _addHistory(message);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: userName.v,
      message: message,
      data: {'giftId': gift.id, 'price': gift.price, 'count': 1, 'local': true},
      color: gift.color,
      userLevel: level.toString(),
      fansName: titleLabel,
    );
  }

  void _addHistory(String value) {
    history.insert(0, value);
    if (history.length > 30) history.removeRange(30, history.length);
  }

  void clearHistory() => history.clear();
}
