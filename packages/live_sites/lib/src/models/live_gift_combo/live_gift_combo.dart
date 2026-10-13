// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// The combo a gift belongs to: the platform's combo key (what every message of
/// one combo shares) and the running count that message reports.
@immutable
final class LiveGiftCombo {
  /// Creates the combo info.
  const LiveGiftCombo({this.comboKey = '', this.comboTotal});

  /// What every message of one combo shares: the platform's combo id (Bilibili
  /// `batch_combo_id`), or for Douyu, which has none, the sender and the gift
  /// while `hits` counts; empty otherwise.
  final String comboKey;

  /// The combo's running count including this message, as the platform counts it
  /// (Douyu `hits`, Huya `iItemGroup`); null when it says nothing.
  final int? comboTotal;

  @override
  String toString() => 'LiveGiftCombo($comboKey, $comboTotal)';
}
