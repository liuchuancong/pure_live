import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The word the toolbar's search hands the recorder page: the page opens
/// the room search picker on it and adds the picked room as a task. Taken
/// once on arrival; null is nothing waiting.
final class RecorderSearchHandoffController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Hands [word] to the recorder page (taken once on arrival).
  // ignore: use_setters_to_change_properties
  void hand(String word) => state = word;

  /// Takes the word (null when none was handed).
  String? take() {
    final word = state;
    state = null;
    return word;
  }
}

/// The recorder page's handed search word.
final recorderSearchHandoffProvider = NotifierProvider<RecorderSearchHandoffController, String?>(
  RecorderSearchHandoffController.new,
);
