import 'dart:ui';

import 'package:live_playback/src/config/window_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [WindowPreferenceStore] on top of `shared_preferences`.
///
/// Each rect is four doubles under one key,
/// `live_playback.window.<sessionId>.<slot>`. Numbers rather than an encoded
/// string so a human reading the preferences file can tell what the entry is,
/// and so a partially written entry (an interrupted app) degrades to "no
/// preference" instead of a parse error.
final class SharedPreferencesWindowPreferenceStore implements WindowPreferenceStore {
  /// Creates the store over an already-loaded [preferences].
  ///
  /// The caller loads them once at startup (`SharedPreferences.getInstance()`)
  /// so no window has to wait on disk during a transition.
  const new(this.preferences);

  /// The underlying preferences.
  final SharedPreferences preferences;

  static const String _prefix = 'live_playback.window.';

  @override
  Future<Rect?> readRect({required String sessionId, required String slot}) async {
    final values = preferences.getStringList(_key(sessionId, slot));
    if (values == null || values.length != 4) {
      return null;
    }

    final doubles = values.map(double.tryParse).toList(growable: false);
    if (doubles.any((value) => value == null)) {
      return null;
    }

    return Rect.fromLTWH(doubles[0]!, doubles[1]!, doubles[2]!, doubles[3]!);
  }

  @override
  Future<void> writeRect({required String sessionId, required String slot, required Rect rect}) async {
    await preferences.setStringList(_key(sessionId, slot), <String>[
      rect.left.toString(),
      rect.top.toString(),
      rect.width.toString(),
      rect.height.toString(),
    ]);
  }

  @override
  Future<void> clearSession(String sessionId) async {
    final prefix = '$_prefix$sessionId.';
    final keys = preferences.getKeys().where((key) => key.startsWith(prefix)).toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  @override
  Future<void> clearAll() async {
    final keys = preferences.getKeys().where((key) => key.startsWith(_prefix)).toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  String _key(String sessionId, String slot) => '$_prefix$sessionId.$slot';
}
