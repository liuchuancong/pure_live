// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What a [LiveGift] is.
enum LiveGiftKind {
  /// A gift sent to the broadcaster (or a guest).
  gift,

  /// A paid membership bought or renewed: Bilibili's guard (`GUARD_BUY`:
  /// 舰长, 提督, 总督), YouTube or Twitch memberships. [LiveGift.count] is the
  /// number of months.
  membership,

  /// Subscriptions gifted to other viewers (Twitch `subgift`, Kick's gifted
  /// subscriptions). [LiveGift.count] is how many were given.
  subscription,

  /// Money given without a gift item (Twitch Bits, SOOP's balloons, FC2 tips).
  /// [LiveGift.name] names the currency.
  tip,
}

/// How much a [LiveGift] is worth ([giftTierOf]), as a hint for the gift line
/// and effects to come.
enum LiveGiftTier {
  /// Free, cheap, or of a value this app cannot place.
  normal,

  /// Worth a mark of its own.
  valuable,

  /// Worth the strongest mark.
  precious,
}

/// The unit of [LiveGift.unitPrice] and [LiveGift.totalValue]: each platform's
/// own currency, kept as the platform counts it. How many make a yuan is only in
/// [giftUnitsPerYuan].
enum LiveGiftUnit {
  /// Fen, a hundredth of a yuan (Douyu's gift table prices).
  fen,

  /// Whole yuan: the super chats of Bilibili, Douyu and Huya, and a Bilibili
  /// guard's card.
  yuan,

  /// Bilibili gold seeds (金瓜子).
  goldSeed,

  /// Bilibili silver seeds (银瓜子), which free gifts cost.
  silverSeed,

  /// Missevan diamonds (钻石).
  diamond,

  /// KilaKila red beans (红豆).
  redBean,

  /// Points: niconico, 17LIVE, FC2.
  point,

  /// Twitch Bits.
  bits,

  /// Kick's Kicks.
  kicks,

  /// CHZZK cheese (치즈).
  cheese,

  /// SOOP star balloons (별풍선).
  starBalloon,

  /// Douyin coins (抖币).
  douyinCoin,

  /// Six Rooms coins (六币).
  sixCoin,

  /// AcFun's AC coins (AC币), ten to a yuan.
  acCoin,

  /// AcFun's bananas (香蕉), the platform's free currency.
  banana,

  /// Kugou Live's star coins (星币), a hundred to a yuan.
  starCoin,

  /// PandaTV's hearts (하트).
  heart,

  /// LOOK's notes (音符).
  note,

  /// A unit the platform does not document, or no value at all.
  other,
}

/// How many of each unit make about one yuan, for [giftTierOf]. The domestic
/// rates are fixed by the platforms; the overseas ones are rough and only rank
/// gifts, never convert a value shown. A unit missing here is never ranked above
/// [LiveGiftTier.normal].
const Map<LiveGiftUnit, double> giftUnitsPerYuan = {
  LiveGiftUnit.fen: 100,
  LiveGiftUnit.yuan: 1,
  LiveGiftUnit.goldSeed: 1000,
  LiveGiftUnit.diamond: 10,
  LiveGiftUnit.douyinCoin: 10,
  LiveGiftUnit.acCoin: 10,
  LiveGiftUnit.starCoin: 100,
  LiveGiftUnit.bits: 14,
  LiveGiftUnit.kicks: 14,
  LiveGiftUnit.cheese: 190,
  LiveGiftUnit.starBalloon: 1.7,
  LiveGiftUnit.heart: 1.7,
  LiveGiftUnit.point: 21,
};

/// From this many yuan a gift is [LiveGiftTier.valuable].
const int giftValuableYuan = 10;

/// From this many yuan a gift is [LiveGiftTier.precious].
const int giftPreciousYuan = 100;

/// The tier of a gift worth [totalValue] in [unit]: [LiveGiftTier.normal] when
/// [free], without a value or in a unit [giftUnitsPerYuan] does not rate; else by
/// yuan, below [giftValuableYuan] normal, below [giftPreciousYuan] valuable, from
/// it precious.
LiveGiftTier giftTierOf(LiveGiftUnit unit, int? totalValue, {bool free = false}) {
  final rate = giftUnitsPerYuan[unit];
  if (free || rate == null || totalValue == null || totalValue <= 0) return LiveGiftTier.normal;
  final yuan = totalValue / rate;
  if (yuan >= giftPreciousYuan) return LiveGiftTier.precious;
  if (yuan >= giftValuableYuan) return LiveGiftTier.valuable;
  return LiveGiftTier.normal;
}

/// A gift, membership, gifted subscription or tip a viewer sent: the
/// [LiveMessage.data] of every [LiveMessageType.gift] message the platform
/// adapters report, filled the same way on every platform. Each platform's class
/// (`BilibiliGift`, `DouyuGift`…) extends it with the fields only that platform
/// has.
///
/// The sender is the message's: [LiveMessage.userName], [LiveMessage.userId] and
/// the level, fan badge and badges drawn as on a chat line, so blocking and the
/// name style act on gifts and chat alike. The message's text is [plainText].
@immutable
base class LiveGift {
  /// Creates a gift; a [count] below 1 counts as 1.
  const LiveGift({
    required this.name,
    this.id = '',
    int count = 1,
    this.kind = LiveGiftKind.gift,
    this.comboKey = '',
    this.comboTotal,
    this.unitPrice,
    this.totalValue,
    this.unit = LiveGiftUnit.other,
    this.free = false,
    this.iconUrl,
    this.receiverName = '',
  }) : count = count < 1 ? 1 : count;

  /// The platform's id for the gift item; empty when it gives none.
  final String id;

  /// The gift's name as the platform writes it (`小心心`, `舰长`, `Donut`); see
  /// [displayName] for one that is never empty.
  final String name;

  /// How many this message gave, at least 1 (the months of a
  /// [LiveGiftKind.membership]).
  final int count;

  /// What it is.
  final LiveGiftKind kind;

  /// What every message of one combo shares: the platform's combo id (Bilibili
  /// `batch_combo_id`), or for Douyu, which has none, the sender and the gift
  /// while `hits` counts; empty otherwise.
  final String comboKey;

  /// The combo's running count including this message, as the platform counts it
  /// (Douyu `hits`, Huya `iItemGroup`); null when it says nothing.
  final int? comboTotal;

  /// The price of one, in [unit]; null when unknown.
  final int? unitPrice;

  /// What this message's gifts are worth together, in [unit]; null when unknown.
  final int? totalValue;

  /// The unit of [unitPrice] and [totalValue].
  final LiveGiftUnit unit;

  /// The platform marks it free (Bilibili silver gifts, Baidu's 拍拍, KilaKila's
  /// 克拉之星, a niconico gift of no points).
  final bool free;

  /// The gift's picture (https), when the platform gives one.
  final Uri? iconUrl;

  /// Who received it when the platform names them (a guest on the microphone
  /// rather than the broadcaster); empty otherwise.
  final String receiverName;

  /// [name], or [id] when the platform gave no name.
  String get displayName => name.isNotEmpty ? name : id;

  /// [giftTierOf] this gift.
  LiveGiftTier get tier => giftTierOf(unit, totalValue, free: free);

  /// The text of the gift's message on every platform, `小心心 ×3`: the name and
  /// the count, without the sender (the chat line shows the name) and without a
  /// platform's sentence.
  String get plainText => '$displayName ×$count';

  /// Same class and same shared fields; a platform's class adds its own.
  @override
  bool operator ==(Object other) =>
      other is LiveGift &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      other.count == count &&
      other.kind == kind &&
      other.comboKey == comboKey &&
      other.comboTotal == comboTotal &&
      other.unitPrice == unitPrice &&
      other.totalValue == totalValue &&
      other.unit == unit &&
      other.free == free &&
      other.iconUrl == iconUrl &&
      other.receiverName == receiverName;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    count,
    kind,
    comboKey,
    comboTotal,
    unitPrice,
    totalValue,
    unit,
    free,
    iconUrl,
    receiverName,
  );

  @override
  String toString() =>
      'LiveGift(${kind.name} $plainText${totalValue == null ? '' : ', $totalValue ${unit.name}'}'
      '${free ? ', free' : ''})';
}
