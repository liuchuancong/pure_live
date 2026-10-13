// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/live_gift_kind/live_gift_kind.dart';
import 'package:live_sites/src/models/live_gift_tier/live_gift_tier.dart';
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';
import 'package:live_sites/src/models/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// A gift, membership, gifted subscription or tip a viewer sent: the
/// [LiveMessage.data] of every `LiveMessageType.gift` message the platform
/// adapters report, filled the same way on every platform. Each platform's class
/// (`BilibiliGift`, `DouyuGift`…) extends it with the fields only that platform
/// has.
///
/// The gift's identity (id, name, count, kind, receiver) lives here; its worth is
/// a [LiveGiftValue] and its combo is a [LiveGiftCombo], reached through the
/// delegating getters below.
@immutable
base class LiveGift {
  /// Creates a gift; a [count] below 1 counts as 1.
  LiveGift({
    required this.name,
    this.id = '',
    int count = 1,
    this.kind = LiveGiftKind.gift,
    String comboKey = '',
    int? comboTotal,
    int? unitPrice,
    int? totalValue,
    LiveGiftUnit unit = LiveGiftUnit.other,
    bool free = false,
    this.iconUrl,
    this.receiverName = '',
  }) : count = count < 1 ? 1 : count,
       combo = LiveGiftCombo(comboKey: comboKey, comboTotal: comboTotal),
       value = LiveGiftValue(unit: unit, unitPrice: unitPrice, totalValue: totalValue, free: free);

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

  /// The gift's picture (https), when the platform gives one.
  final Uri? iconUrl;

  /// Who received it when the platform names them (a guest on the microphone
  /// rather than the broadcaster); empty otherwise.
  final String receiverName;

  /// What the gift is worth (unit, prices, free).
  final LiveGiftValue value;

  /// The combo this gift belongs to (key, running total).
  final LiveGiftCombo combo;

  /// [name], or [id] when the platform gave no name.
  String get displayName => name.isNotEmpty ? name : id;

  /// The tier of this gift (delegates to [value]).
  LiveGiftTier get tier => value.tier;

  /// The unit of the prices (delegates to [value]).
  LiveGiftUnit get unit => value.unit;

  /// The price of one (delegates to [value]).
  int? get unitPrice => value.unitPrice;

  /// The value of this message's gifts together (delegates to [value]).
  int? get totalValue => value.totalValue;

  /// Whether the platform marks it free (delegates to [value]).
  bool get free => value.free;

  /// The combo key (delegates to [combo]).
  String get comboKey => combo.comboKey;

  /// The combo's running count (delegates to [combo]).
  int? get comboTotal => combo.comboTotal;

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
