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

/// The centre's page on screen: the tasks being managed, or the files they
/// produced. The shell's toolbar search reads it to change its hint and
/// where the word goes — a task search opens the room picker, a file search
/// filters the library in place.
enum RecorderCenterTab { tasks, files }

/// The centre's own page, published for the shell's toolbar.
final recorderCenterTabProvider = NotifierProvider<RecorderCenterTabController, RecorderCenterTab>(
  RecorderCenterTabController.new,
);

final class RecorderCenterTabController extends Notifier<RecorderCenterTab> {
  @override
  RecorderCenterTab build() => RecorderCenterTab.tasks;

  /// Switches the centre's page.
  // ignore: use_setters_to_change_properties
  void set(RecorderCenterTab value) => state = value;
}

/// The word the toolbar's search hands the library: it becomes the file
/// list's own query, filtering the takes in place. Taken once on arrival.
final recorderLibrarySearchHandoffProvider = NotifierProvider<RecorderLibrarySearchHandoffController, String?>(
  RecorderLibrarySearchHandoffController.new,
);

final class RecorderLibrarySearchHandoffController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Hands [word] to the library (taken once on arrival).
  // ignore: use_setters_to_change_properties
  void hand(String word) => state = word;

  /// Takes the word (null when none was handed).
  String? take() {
    final word = state;
    state = null;
    return word;
  }
}

/// The centre's page on screen: the tasks being managed, or the files they
/// produced. The shell's toolbar search reads it to change its hint and
/// where the word goes — a task search opens the room picker, a file search
/// filters the library in place.
