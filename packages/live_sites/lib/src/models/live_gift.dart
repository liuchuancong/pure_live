import 'package:meta/meta.dart';

/// Gift pricing units, normalized from the platforms' coin systems.
enum LiveGiftUnit {
  /// Platform silver coins (free-tier currency).
  silver,

  /// Platform gold coins (paid currency).
  gold,

  /// Direct RMB amounts.
  rmb,
}

/// A gift event payload attached to a `LiveMessage` of the gift kind.
@immutable
final class LiveGift {
  /// A gift event: [count] gifts of [name], combo-merged when the
  /// platform streams combos.
  const new({
    required this.name,
    required this.count,
    this.unit = LiveGiftUnit.gold,
    this.unitPrice = 0,
    this.totalValue,
    this.combo,
  });

  /// Gift display name.
  final String name;

  /// How many of the gift this event represents.
  final int count;

  /// Which currency [unitPrice] is denominated in.
  final LiveGiftUnit unit;

  /// Price of one gift in [unit]s.
  final int unitPrice;

  /// Total value of the event, when the platform reports it directly.
  final int? totalValue;

  /// Combo sequence label, when this event continues a combo.
  final String? combo;

  /// The total value in [unit]s, computed or reported.
  int get value => totalValue ?? unitPrice * count;
}

/// An audience update payload.
@immutable
final class LiveAudienceUpdate {
  /// An update carrying [watching] and/or [onlineViewers].
  const new({this.watching, this.onlineViewers});

  /// Current watcher count.
  final int? watching;

  /// Cumulative viewer count.
  final int? onlineViewers;
}
