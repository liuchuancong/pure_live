// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/gift/gift_value.dart';
import 'package:live_sites/src/models/live_gift_kind/live_gift_kind.dart';
import 'package:live_sites/src/models/live_gift_tier/live_gift_tier.dart';
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// A gift, membership, gifted subscription or tip a viewer sent: the
/// [LiveMessage.data] of every `LiveMessageType.gift` message the platform
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
