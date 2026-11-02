import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The word the toolbar's search hands the multiview page: the page opens
/// the room search picker on it and puts the picked room in the current
/// cell. Taken once on arrival; null is nothing waiting.
final class MultiviewSearchHandoffController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Hands [word] to the multiview page (taken once on arrival).
  // ignore: use_setters_to_change_properties
  void hand(String word) => state = word;

  /// Takes the word (null when none was handed).
  String? take() {
    final word = state;
    state = null;
    return word;
  }
}

/// The multiview page's handed search word.
final multiviewSearchHandoffProvider = NotifierProvider<MultiviewSearchHandoffController, String?>(
  MultiviewSearchHandoffController.new,
);
