/// The local experience catalogue: the gifts a viewer can send into their
/// own room, and the level the experience accumulates into.
///
/// The reference keeps a platform-aware catalogue with packs, tiers and
/// growth; this build keeps one small, honest set — the gifts exist to make
/// the viewer's own line and banner appear, not to model a platform's shop —
/// and the same 500-experience step the reference uses.
library;

/// One gift the composer offers.
final class LocalGift {
  /// A gift.
  const new({required this.id, required this.name, required this.emoji, required this.exp});

  /// Stable id (the picker's key and the sent message's identity).
  final String id;

  /// The name shown on the line and in the picker.
  final String name;

  /// The glyph the picker shows instead of artwork.
  final String emoji;

  /// The experience one send grants.
  final int exp;
}

/// The catalogue and the level arithmetic.
abstract final class LocalCatalog {
  /// The gifts, cheapest first.
  static const List<LocalGift> gifts = [
    LocalGift(id: 'heart', name: '小心心', emoji: '💗', exp: 5),
    LocalGift(id: 'lollipop', name: '棒棒糖', emoji: '🍭', exp: 10),
    LocalGift(id: 'pillow', name: '抱枕', emoji: '🛋️', exp: 20),
    LocalGift(id: 'rocket', name: '小火箭', emoji: '🚀', exp: 50),
    LocalGift(id: 'crown', name: '皇冠', emoji: '👑', exp: 100),
    LocalGift(id: 'castle', name: '城堡', emoji: '🏰', exp: 200),
  ];

  /// The experience one chat line grants.
  static const int chatExp = 2;

  /// The experience step of one level (the reference's `levelStep`).
  static const int expPerLevel = 500;

  /// The gift [id] names; unknown ids fall back to the first gift, so a
  /// stored pick from an older build still sends something.
  static LocalGift giftOf(String id) => gifts.firstWhere((gift) => gift.id == id, orElse: () => gifts.first);

  /// The level [experience] reaches; level 1 starts at zero and every level
  /// is [expPerLevel] wide.
  static int levelFor(int experience) => (experience < 0 ? 0 : experience) ~/ expPerLevel + 1;

  /// How much of the current level is filled.
  static int intoLevel(int experience) => (experience < 0 ? 0 : experience) % expPerLevel;

  /// How much experience the next level still needs.
  static int missingToNext(int experience) => expPerLevel - intoLevel(experience);
}
